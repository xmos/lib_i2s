// Copyright 2015-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <xclib.h>
#include "i2s.h"
#include <print.h>
#include "limits.h"
#include "xassert.h"
#include <stdlib.h>
#include <stdio.h>

unsigned i2s_frame_slave_4b_setup(
            int32_t out_samps[],
            int32_t in_samps[],
            out buffered port:32 ?p_dout,
            in buffered port:32 ?p_din,
            in buffered port:32 p_lrclk
            );

unsigned i2s_frame_slave_4b_loop_part_1(
            int32_t out_samps[],
            int32_t in_samps[],
            out buffered port:32 ?p_dout,
            in buffered port:32 ?p_din,
            in buffered port:32 p_lrclk
            );

unsigned i2s_frame_slave_4b_loop_part_2(
            int32_t out_samps[],
            int32_t in_samps[],
            out buffered port:32 ?p_dout,
            in buffered port:32 ?p_din,
            in buffered port:32 p_lrclk
            );

static void i2s_frame_slave_init_ports_4b(
        out buffered port:32 ?p_dout,
        size_t num_out,
        in buffered port:32 ?p_din,
        size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk){
    set_clock_on(bclk);
    configure_clock_src(bclk, p_bclk);
    configure_in_port(p_lrclk, bclk);
    
    if (!isnull(p_din))
    {
        configure_in_port(p_din, bclk);
    }
    if (!isnull(p_dout))
    {
        configure_out_port(p_dout, bclk, 0);
    }

    start_clock(bclk);
}

#define i2s_frame_slave_4b i2s_frame_slave_4b0

#pragma unsafe arrays
static void i2s_frame_slave_4b0(client i2s_frame_callback_if i2s_i,
        out buffered port:32 ?p_dout,
        static const size_t num_out,
        in buffered port:32 ?p_din,
        static const size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk){

    unsigned port_time;
    int32_t in_samps[16] = {0};  //Workaround: should be (num_in << 1) but compiler thinks that isn't const,
    int32_t out_samps[16] = {0}; //so setting to 16 which should be big enough for most cases

    // Since #pragma unsafe arrays is used need to ensure array won't overflow.
    assert((num_in << 1) <= 16);
    
    i2s_frame_slave_init_ports_4b(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

    while(1)
    {
        i2s_config_t config;
        i2s_restart_t restart = I2S_NO_RESTART;
        i2s_i.init(config, null);

        unsigned mode = config.mode;

        if (config.slave_bclk_polarity == I2S_SLAVE_SAMPLE_ON_BCLK_FALLING)
            set_port_inv(p_bclk);
        else
            set_port_no_inv(p_bclk);

        const unsigned expected_low  = (mode == I2S_MODE_I2S ? 0x80000000 : 0x00000000);
        const unsigned expected_high = (mode == I2S_MODE_I2S ? 0x7fffffff : 0xffffffff);

        unsigned syncerror = 0;
        unsigned lrval;
        if (!isnull(p_dout))
        {
            clearbuf(p_dout);
        }
        if (!isnull(p_din))
        {
            clearbuf(p_din);
        }
        clearbuf(p_lrclk);

        unsigned offset = (mode == I2S_MODE_I2S ? 1 : 0);

        // Wait for LRCLK edge (in I2S LRCLK = 0 is left, TDM rising edge is start of frame) 
        p_lrclk when pinseq(1) :> void;
        p_lrclk when pinseq(0) :> void @ port_time;

        unsigned initial_lr_port_time  = port_time + offset + ((I2S_CHANS_PER_FRAME*32)+32) - 1;
        unsigned initial_out_port_time = port_time + offset + (I2S_CHANS_PER_FRAME*32);
        unsigned initial_in_port_time  = port_time + offset + ((I2S_CHANS_PER_FRAME*32)+8) - 1;
        // XC doesn't have syntax for setting a timed input without waiting for the input 
        asm volatile("setpt res[%0], %1"
                   :
                   :"r"(p_lrclk),"r"(initial_lr_port_time));
        if (!isnull(p_din))
        {
            asm volatile("setpt res[%0], %1"
                       :
                       :"r"(p_din),"r"(initial_in_port_time));
        }
        if (!isnull(p_dout))
        {
            asm volatile("setpt res[%0], %1"
                        :
                        :"r"(p_dout),"r"(initial_out_port_time));
        }
        
        //Get initial send data if output enabled
        if (num_out) 
        {
            i2s_i.send(num_out << 1, out_samps);
        }

        lrval = i2s_frame_slave_4b_setup(out_samps, in_samps, p_dout, p_din, p_lrclk);
        syncerror += (lrval != expected_low);

        //Main loop
        while (!syncerror && (restart == I2S_NO_RESTART)) 
        {
            restart = i2s_i.restart_check();

            if (num_out)
            {
                i2s_i.send(num_out << 1, out_samps);
            }

            lrval = i2s_frame_slave_4b_loop_part_1(out_samps, in_samps, p_dout, p_din, p_lrclk);
            syncerror += (lrval != expected_high);

            if (num_in)
            {
                i2s_i.receive(num_in << 1, in_samps);
            }

            if (restart == I2S_NO_RESTART)
            {
                lrval = i2s_frame_slave_4b_loop_part_2(out_samps, in_samps, p_dout, p_din, p_lrclk);
                syncerror += (lrval != expected_low);
            }        
        }// main loop, runs until user restart or synch error
    }// while(1)
}

// This function is just to avoid unused static function warnings for
// i2s_frame_slave0,it should never be called.
inline void i2s_frame_slave_4b1(client i2s_frame_callback_if i2s_i,
        out buffered port:32 ?p_dout,
        static const size_t num_out,
        in buffered port:32 ?p_din,
        static const size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk){
    
if (isnull(p_dout) && isnull(p_din)) {
    fail("Must provide non-null p_dout or p_din");
}

  i2s_frame_slave_4b0(i2s_i, p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);
}
