// Copyright 2015-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <xclib.h>
#include "i2s.h"
#include <print.h>
#include "limits.h"
#include "xassert.h"
#include <stdlib.h>
#include <stdio.h>

static void i2s_frame_slave_init_ports(
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk)
{
    set_clock_on(bclk);
    configure_clock_src(bclk, p_bclk);
    configure_in_port(p_lrclk, bclk);
    for (size_t i = 0; i < num_out; i++)
        configure_out_port(p_dout[i], bclk, 0);
    for (size_t i = 0; i < num_in; i++)
        configure_in_port(p_din[i], bclk);
    start_clock(bclk);
}

#define i2s_frame_slave i2s_frame_slave0

#pragma unsafe arrays
static void i2s_frame_slave0(client i2s_frame_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        static const size_t num_data_bits,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk)
{
    unsigned port_time;
    int32_t in_samps[16]; //Workaround: should be (num_in << 1) but compiler thinks that isn't const,
    int32_t out_samps[16];//so setting to 16 which should be big enough for most cases

    // Since #pragma unsafe arrays is used need to ensure array won't overflow.
    assert((num_in << 1) <= 16);

    i2s_config_t config;
    config.slave_frame_synch_error = 0;

    if (num_data_bits == 32)
    {
        while(1){
            i2s_frame_slave_init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

            i2s_restart_t restart = I2S_NO_RESTART;
            i2s_i.init(config, null);
            config.slave_frame_synch_error = 0;

            //Get initial send data if output enabled
            if (num_out) i2s_i.send(num_out << 1, out_samps);

            unsigned mode = config.mode;

            if (config.slave_bclk_polarity == I2S_SLAVE_SAMPLE_ON_BCLK_FALLING)
                set_port_inv(p_bclk);
            else
                set_port_no_inv(p_bclk);

            const unsigned expected_low  = (mode == I2S_MODE_I2S ? 0x80000000 : 0x00000000);
            const unsigned expected_high = (mode == I2S_MODE_I2S ? 0x7fffffff : 0xffffffff);

            unsigned syncerror = 0;
            unsigned lrval;

            for (size_t i=0;i<num_out;i++)
                clearbuf(p_dout[i]);
            for (size_t i=0;i<num_in;i++)
                clearbuf(p_din[i]);
            clearbuf(p_lrclk);

            unsigned offset = 0;
            if (mode==I2S_MODE_I2S) {
                offset = 1;
            }

            // Wait for LRCLK edge (in I2S LRCLK = 0 is left, TDM rising edge is start of frame)
            p_lrclk when pinseq(1) :> void;
            p_lrclk when pinseq(0) :> void @ port_time;

            unsigned initial_out_port_time = port_time + offset + (I2S_CHANS_PER_FRAME*32);
            unsigned initial_in_port_time  = port_time + offset + ((I2S_CHANS_PER_FRAME*32)+32) - 1;

            //Start outputting evens (0,2,4..) data at correct point relative to the clock
            for (size_t i=0, idx=0; i<num_out; i++, idx+=2){
                p_dout[i] @ initial_out_port_time <: bitrev(out_samps[idx]);
            }

            // XC doesn't have syntax for setting a timed input without waiting for the input
            asm("setpt res[%0], %1"::"r"(p_lrclk),"r"(initial_in_port_time));
            for (size_t i=0;i<num_in;i++) {
                asm("setpt res[%0], %1"::"r"(p_din[i]),"r"(initial_in_port_time));
            }

            //And pre-load the odds (1,3,5..) to follow immediately afterwards
            for (size_t i=0, idx=1; i<num_out; i++, idx+=2){
                p_dout[i] <: bitrev(out_samps[idx]);
            }

            //Main loop
            while (!syncerror && (restart == I2S_NO_RESTART)) {

                restart = i2s_i.restart_check();

                if (num_out && (restart == I2S_NO_RESTART)){
                    i2s_i.send(num_out << 1, out_samps);

                    //Output i2s evens (0,2,4..)
    #pragma loop unroll
                    for (size_t i=0, idx=0; i<num_out; i++, idx+=2){
                        p_dout[i] <: bitrev(out_samps[idx]);
                    }
                }

                //Read lrclk value
                p_lrclk :> lrval;

                //Input i2s evens (0,2,4..)
    #pragma loop unroll
                for (size_t i=0, idx=0; i<num_in; i++, idx+=2){
                    int32_t data;
                    asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
                    in_samps[idx] = bitrev(data);
                }

                syncerror += (lrval != expected_low);

                //Read lrclk value
                p_lrclk :> lrval;

                //Output i2s odds (1,3,5..)
    #pragma loop unroll
                if (num_out && (restart == I2S_NO_RESTART)){
                    for (size_t i=0, idx=1; i<num_out; i++, idx+=2){
                        p_dout[i] <: bitrev(out_samps[idx]);
                    }
                }

            //Input i2s odds (1,3,5..)
    #pragma loop unroll
                for (size_t i=0, idx=1; i<num_in; i++, idx+=2){
                    int32_t data;
                    asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
                    in_samps[idx] = bitrev(data);
                }

                syncerror += (lrval != expected_high);

                if (num_in && (restart == I2S_NO_RESTART))
                {
                    i2s_i.receive(num_in << 1, in_samps);

                }//main loop, runs until user restart or synch error
            }

            if(restart == I2S_SHUTDOWN)
            {
                return;
            }

            if(syncerror)
            {
                config.slave_frame_synch_error = 1;
            }

        }// while(1)
    }
    else // else if num_data_bits != 32
    {
        const unsigned data_bit_offset = 32 - num_data_bits;
        const unsigned data_bit_mask = UINT_MAX >> data_bit_offset; // e.g. 00011111 for 5b data

        while (1)
        {
            i2s_frame_slave_init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);
            i2s_config_t config;
            i2s_restart_t restart = I2S_NO_RESTART;
            i2s_i.init(config, null);
            config.slave_frame_synch_error = 0;

            // Get initial send data if output enabled
            if (num_out)
            {
                i2s_i.send(num_out << 1, out_samps);
            }

            unsigned mode = config.mode;

            if (config.slave_bclk_polarity == I2S_SLAVE_SAMPLE_ON_BCLK_FALLING)
                set_port_inv(p_bclk);
            else
                set_port_no_inv(p_bclk);

            const unsigned expected_low = (mode == I2S_MODE_I2S ? 0x80000000 : 0x00000000) & !data_bit_mask;
            const unsigned expected_high = (mode == I2S_MODE_I2S ? 0x7fffffff : 0xffffffff) & !data_bit_mask;

            unsigned syncerror = 0;
            unsigned lrval;

            for (size_t i = 0; i < num_out; i++)
                clearbuf(p_dout[i]);
            for (size_t i = 0; i < num_in; i++)
                clearbuf(p_din[i]);
            clearbuf(p_lrclk);

            unsigned offset = 0;
            if (mode == I2S_MODE_I2S)
            {
                offset = 1;
            }

            // Wait for LRCLK edge (in I2S LRCLK = 0 is left, TDM rising edge is start of frame)
            p_lrclk when pinseq(1) :> void;
            p_lrclk when pinseq(0) :> void @ port_time;

            unsigned initial_out_port_time = port_time + offset + (I2S_CHANS_PER_FRAME * num_data_bits);
            unsigned initial_in_port_time = port_time + offset + ((I2S_CHANS_PER_FRAME * num_data_bits) + num_data_bits) - 1;

            // Start outputting evens (0,2,4..) data at correct point relative to the clock
            for (size_t i = 0, idx = 0; i < num_out; i++, idx += 2)
            {
                partout_timed(p_dout[i], num_data_bits, bitrev(out_samps[idx] << data_bit_offset), initial_out_port_time);
            }

            // XC doesn't have syntax for setting a timed input without waiting for the input
            asm volatile("setpt res[%0], %1"
                            :
                            : "r"(p_lrclk), "r"(initial_in_port_time));
            set_port_shift_count(p_lrclk, num_data_bits);

            for (size_t i = 0; i < num_in; i++)
            {
                asm volatile("setpt res[%0], %1"
                                :
                                : "r"(p_din[i]), "r"(initial_in_port_time));
                set_port_shift_count(p_din[i], num_data_bits);
            }

            // And pre-load the odds (1,3,5..) to follow immediately afterwards
            for (size_t i = 0, idx = 1; i < num_out; i++, idx += 2)
            {
                partout(p_dout[i], num_data_bits, bitrev(out_samps[idx] << data_bit_offset));
            }

            // Main loop
            while (!syncerror && (restart == I2S_NO_RESTART))
            {
                restart = i2s_i.restart_check();

                if (num_out && (restart == I2S_NO_RESTART))
                {
                    i2s_i.send(num_out << 1, out_samps);

                    // Output i2s evens (0,2,4..)
                    for (size_t i = 0, idx = 0; i < num_out; i++, idx += 2)
                    {
                        partout(p_dout[i], num_data_bits, bitrev(out_samps[idx] << data_bit_offset));
                    }
                }

                // Read lrclk value
                asm volatile("in %0, res[%1]"
                                : "=r"(lrval)
                                : "r"(p_lrclk));
                set_port_shift_count(p_lrclk, num_data_bits);

                // Input i2s evens (0,2,4..)
                for (size_t i = 0, idx = 0; i < num_in; i++, idx += 2)
                {
                    int32_t data;
                    asm volatile("in %0, res[%1]"
                                    : "=r"(data)
                                    : "r"(p_din[i]));
                    set_port_shift_count(p_din[i], num_data_bits);
                    in_samps[idx] = bitrev(data) & data_bit_mask;
                }

                syncerror += ((lrval & !data_bit_mask) != expected_low);

                // Read lrclk value
                asm volatile("in %0, res[%1]"
                                : "=r"(lrval)
                                : "r"(p_lrclk));
                set_port_shift_count(p_lrclk, num_data_bits);

                // Output i2s odds (1,3,5..)
#pragma loop unroll
                if (num_out && (restart == I2S_NO_RESTART))
                {
                    for (size_t i = 0, idx = 1; i < num_out; i++, idx += 2)
                    {
                        partout(p_dout[i], num_data_bits, bitrev(out_samps[idx] << data_bit_offset));
                    }
                }

                // Input i2s odds (1,3,5..)
#pragma loop unroll
                for (size_t i = 0, idx = 1; i < num_in; i++, idx += 2)
                {
                    int32_t data;
                    asm volatile("in %0, res[%1]"
                                    : "=r"(data)
                                    : "r"(p_din[i]));
                    set_port_shift_count(p_din[i], num_data_bits);
                    in_samps[idx] = bitrev(data) & data_bit_mask;
                }

                syncerror += ((lrval & !data_bit_mask) != expected_high);

                if (num_in && (restart == I2S_NO_RESTART))
                {
                    i2s_i.receive(num_in << 1, in_samps);
                }
            } // main loop, runs until user restart or synch error

            if(restart == I2S_SHUTDOWN)
            {
                return;
            }

            if(syncerror)
            {
                config.slave_frame_synch_error = 1;
            }
        }// while(1)
    } // if num_data_bits == 32
}

// This function is just to avoid unused static function warnings for
// i2s_frame_slave0,it should never be called.
inline void i2s_frame_slave1(client i2s_frame_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        static const size_t num_data_bits,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk)
{

    if (isnull(p_dout) && isnull(p_din))
    {
        fail("Must provide non-null p_dout or p_din");
    }

    i2s_frame_slave0(i2s_i, p_dout, num_out, p_din, num_in, num_data_bits, p_bclk, p_lrclk, bclk);
}
