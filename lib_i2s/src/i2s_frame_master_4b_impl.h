// Copyright 2016-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#if defined(__XS2A__) || defined(__XS3A__)

#include "limits.h"
#include <xs1.h>
#include <xclib.h>
#include "i2s.h"
#include "xassert.h"

void i2s_frame_master_4b_setup(
    int32_t out_samps[],
    int32_t in_samps[],
    out buffered port:32 ?p_dout,
    in buffered port:32 ?p_din,
    clock bclk,
    out buffered port:32 p_lrclk
    );

void i2s_frame_master_4b_loop_part_1(
    int32_t out_samps[],
    int32_t in_samps[],
    out buffered port:32 ?p_dout,
    in buffered port:32 ?p_din,
    out buffered port:32 p_lrclk
    );

void i2s_frame_master_4b_loop_part_2(
    int32_t out_samps[],
    int32_t in_samps[],
    out buffered port:32 ?p_dout,
    in buffered port:32 ?p_din,
    out buffered port:32 p_lrclk
    );

static void i2s_setup_bclk_4b(
        clock bclk,
        in port p_mclk,
        unsigned mclk_bclk_ratio
        ){
    set_clock_on(bclk);
    configure_clock_src_divide(bclk, p_mclk, mclk_bclk_ratio >> 1);
}

static void i2s_frame_init_ports_4b(
        out buffered port:32 ?p_dout,
        static const size_t num_out,
        in buffered port:32 ?p_din,
        static const size_t num_in,
        out port p_bclk,
        out buffered port:32 p_lrclk,
        clock bclk
        ){

    if (!isnull(p_dout))
    {
        configure_out_port(p_dout, bclk, 0);
        clearbuf(p_dout);
    }
    
    if (!isnull(p_din))
    {
        configure_in_port(p_din, bclk);
        clearbuf(p_din);
    }

    configure_out_port(p_lrclk, bclk, 1);
    clearbuf(p_lrclk);

    configure_port_clock_output(p_bclk, bclk);
}

#pragma unsafe arrays
static i2s_restart_t i2s_frame_ratio_n_4b(
        client i2s_frame_callback_if i2s_i,
        out buffered port:32 ?p_dout,
        static const size_t num_out,
        in buffered port:32 ?p_din,
        static const size_t num_in,
        out port p_bclk,
        clock bclk,
        out buffered port:32 p_lrclk,
        i2s_mode_t mode){
    
    const int offset = (mode == I2S_MODE_I2S) ? 1 : 0;
    int32_t in_samps[16] = {0};  // Workaround: should be (num_in << 1) but compiler thinks that isn't const,
    int32_t out_samps[16] = {0}; // so setting to 16 which should be big enough for most cases

    // Since #pragma unsafe arrays is used need to ensure array won't overflow.
    assert((num_in << 1) <= 16);

    if (num_out) 
    {
        i2s_i.send(num_out << 1, out_samps);
    }

    p_lrclk @ 1 <: 0;

    if (!isnull(p_din))
    {
        asm volatile("setpt res[%0], %1"
                    :
                    :"r"(p_din), "r"(8 + offset));
    }

    if (!isnull(p_dout))
    {
        asm volatile("setpt res[%0], %1"
                        :
                        :"r"(p_dout), "r"(1 + offset));
    }

    i2s_frame_master_4b_setup(out_samps, in_samps, p_dout, p_din, bclk, p_lrclk);

    while (1) 
    {
        // Check for restart
        i2s_restart_t restart = i2s_i.restart_check();

        if (num_out)
        {
            i2s_i.send(num_out << 1, out_samps);
        }
        i2s_frame_master_4b_loop_part_1(out_samps, in_samps, p_dout, p_din, p_lrclk);

        if (num_in)
        {
            i2s_i.receive(num_in << 1, in_samps);
        }

        if (restart == I2S_NO_RESTART)
        {
            i2s_frame_master_4b_loop_part_2(out_samps, in_samps, p_dout, p_din, p_lrclk);
        }
        else
        {
            if (!num_in) 
            {
                // Prevent the clock from being stopped before the last word
                // has been sent if there are no RX ports.
                sync(p_dout);
            }
            stop_clock(bclk);
            return restart;
        }
    }
    return I2S_RESTART;
}

#define i2s_frame_master_4b i2s_frame_master0_4b

static void i2s_frame_master0_4b(
                client i2s_frame_callback_if i2s_i,
                out buffered port:32 ?p_dout,
                static const size_t num_out,
                in buffered port:32 ?p_din,
                static const size_t num_in,
                out port p_bclk,
                out buffered port:32 p_lrclk,
                in port p_mclk,
                clock bclk){
    while(1){
        i2s_config_t config;
        i2s_i.init(config, null);

        if (isnull(p_dout) && isnull(p_din)) {
            fail("Must provide non-null p_dout or p_din");
        }
        unsafe 
        {
            if ((!isnull(p_din) && (XS1_RES_ID_PORTWIDTH((int)p_din) != 4)) || 
                    (!isnull(p_dout) && (XS1_RES_ID_PORTWIDTH((int)p_dout) != 4)))
            {
                fail("This function is designed only for use with 4b ports");
            }
        }
        
        i2s_setup_bclk_4b(bclk, p_mclk, config.mclk_bclk_ratio);
        //This ensures that the port time on all the ports is at 0
        i2s_frame_init_ports_4b(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

        i2s_restart_t restart =
          i2s_frame_ratio_n_4b(i2s_i, p_dout, num_out, p_din,
                      num_in, p_bclk, bclk, p_lrclk,
                      config.mode);

        if (restart == I2S_SHUTDOWN)
          return;
    }
}

#define i2s_frame_master_external_clock_4b i2s_frame_master0_external_clock_4b

static void i2s_frame_master0_external_clock_4b(
                client i2s_frame_callback_if i2s_i,
                out buffered port:32 ?p_dout,
                static const size_t num_out,
                in buffered port:32 ?p_din,
                static const size_t num_in,
                out port p_bclk,
                out buffered port:32 p_lrclk,
                clock bclk){
    while(1){
        i2s_config_t config;
        i2s_i.init(config, null);

        if (isnull(p_dout) && isnull(p_din)) {
            fail("Must provide non-null p_dout or p_din");
        }
        unsafe 
        {
            if ((!isnull(p_din) && (XS1_RES_ID_PORTWIDTH((int)p_din) != 4)) || 
                    (!isnull(p_dout) && (XS1_RES_ID_PORTWIDTH((int)p_dout) != 4)))
            {
                fail("This function is designed only for use with 4b ports");
            }
        }

        //This ensures that the port time on all the ports is at 0
        i2s_frame_init_ports_4b(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

        i2s_restart_t restart =
          i2s_frame_ratio_n_4b(i2s_i, p_dout, num_out, p_din,
                      num_in, p_bclk, bclk, p_lrclk,
                      config.mode);

        if (restart == I2S_SHUTDOWN)
          return;
    }
}

// These functions are just to avoid unused static function warnings for i2s_frame_master0
// and i2s_frame_master0_external_clock. They should never be called.
inline void i2s_frame_master1_4b(client interface i2s_frame_callback_if i,
        out buffered port:32 i2s_dout,
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din,
        static const size_t num_i2s_in,
        out port i2s_bclk,
        out buffered port:32 i2s_lrclk,
        in port p_mclk,
        clock clk_bclk) {
    i2s_frame_master0_4b(i, i2s_dout, num_i2s_out, i2s_din, num_i2s_in,
                i2s_bclk, i2s_lrclk, p_mclk, clk_bclk);
}

inline void i2s_frame_master1_external_clock_4b(client interface i2s_frame_callback_if i,
        out buffered port:32 i2s_dout,
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din,
        static const size_t num_i2s_in,
        out port i2s_bclk,
        out buffered port:32 i2s_lrclk,
        clock clk_bclk) {
    i2s_frame_master0_external_clock_4b(i, i2s_dout, num_i2s_out, i2s_din, num_i2s_in,
                i2s_bclk, i2s_lrclk, clk_bclk);
}

#endif // __XS2A__ || __XS3A__
