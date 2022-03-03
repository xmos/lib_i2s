// Copyright 2016-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#if defined(__XS2A__) || defined(__XS3A__)

#include "limits.h"
#include <xs1.h>
#include <xclib.h>
#include "i2s.h"
#include "xassert.h"

static void i2s_setup_bclk(
        clock bclk,
        in port p_mclk,
        unsigned mclk_bclk_ratio
        ){
    set_clock_on(bclk);
    configure_clock_src_divide(bclk, p_mclk, mclk_bclk_ratio >> 1);
}

static void i2s_frame_init_ports(
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        out port p_bclk,
        out buffered port:32 p_lrclk,
        clock bclk
        ){

    for (size_t i = 0; i < num_out; i++)
    {
        configure_out_port(p_dout[i], bclk, 0);
        clearbuf(p_dout[i]);
    }
    for (size_t i = 0; i < num_in; i++)
    {
        configure_in_port(p_din[i], bclk);
        clearbuf(p_din[i]);
    }

    configure_port_clock_output(p_bclk, bclk);
    configure_out_port(p_lrclk, bclk, 1);
    clearbuf(p_lrclk);
}

#pragma unsafe arrays
static i2s_restart_t i2s_frame_ratio_n(client i2s_frame_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        static const size_t num_data_bits,
        out port p_bclk,
        clock bclk,
        out buffered port:32 p_lrclk,
        i2s_mode_t mode){
    
    const int offset = (mode == I2S_MODE_I2S) ? 1 : 0;
    int32_t in_samps[16];  // Workaround: should be (num_in << 1) but compiler thinks that isn't const,
    int32_t out_samps[16]; // so setting to 16 which should be big enough for most cases

    // Since #pragma unsafe arrays is used need to ensure array won't overflow.
    assert((num_in << 1) <= 16);

    unsigned lr_mask = 0;
    const unsigned data_bit_offset = 32 - num_data_bits;
    const unsigned data_bit_mask = UINT_MAX >> data_bit_offset; // e.g. 00011111 for 5b data

    if (num_out) 
    {
        i2s_i.send(num_out << 1, out_samps);
    }

    // Start outputting evens (0,2,4..) data at correct point relative to the clock
    if (num_data_bits == 32)
    {
#pragma loop unroll
        for (size_t i = 0, idx = 0; i < num_out; i++, idx += 2)
        {
            p_dout[i] @ (1 + offset) <: bitrev(out_samps[idx]);
        }
        p_lrclk @ 1 <: lr_mask;
    }
    else
    {
#pragma loop unroll
        for (size_t i = 0, idx = 0; i < num_out; i++, idx += 2)
        {
            partout_timed(p_dout[i], num_data_bits, bitrev(out_samps[idx] << data_bit_offset), (1 + offset));
        }
        partout_timed(p_lrclk, num_data_bits, lr_mask, 1);
    }

    start_clock(bclk);

    // Pre-load the odds (1,3,5..) and setup timing on the input ports
    if (num_data_bits == 32)
    {
#pragma loop unroll
        for (size_t i = 0, idx = 1; i < num_out; i++, idx += 2)
        {
            p_dout[i] <: bitrev(out_samps[idx]);
        }

        lr_mask = ~lr_mask;
        p_lrclk <: lr_mask;

        for (size_t i = 0; i < num_in; i++) 
        {
            asm volatile("setpt res[%0], %1"
                        :
                        :"r"(p_din[i]), "r"(32 + offset));
        }
    }
    else
    {
#pragma loop unroll
        for (size_t i = 0, idx = 1; i < num_out; i++, idx += 2)
        {
            partout(p_dout[i], num_data_bits, bitrev(out_samps[idx] << data_bit_offset));
        }

        lr_mask = ~lr_mask;
        partout(p_lrclk, num_data_bits, lr_mask);

        for (size_t i = 0; i < num_in; i++) 
        {
            asm volatile("setpt res[%0], %1"
                        :
                        :"r"(p_din[i]), "r"(num_data_bits + offset));
            set_port_shift_count(p_din[i], num_data_bits);
        }
    }

    while (1) 
    {
        // Check for restart
        i2s_restart_t restart = i2s_i.restart_check();

        if (restart == I2S_NO_RESTART) 
        {
            if (num_out) 
            {
                i2s_i.send(num_out << 1, out_samps);
            }
            // Output i2s evens (0,2,4..)
            if (num_data_bits == 32)
            {
#pragma loop unroll
                for (size_t i = 0, idx = 0; i < num_out; i++, idx += 2)
                {
                    p_dout[i] <: bitrev(out_samps[idx]);
                }
            }
            else
            {
#pragma loop unroll
                for (size_t i = 0, idx = 0; i < num_out; i++, idx += 2)
                {
                    partout(p_dout[i], num_data_bits, bitrev(out_samps[idx] << data_bit_offset));
                }
            }
        }

        // Input i2s evens (0,2,4..)
        if (num_data_bits == 32)
        {
#pragma loop unroll
            for (size_t i = 0, idx = 0; i < num_in; i++, idx += 2)
            {
                int32_t data;
                asm volatile("in %0, res[%1]"
                            :"=r"(data)
                            :"r"(p_din[i]));
                in_samps[idx] = bitrev(data);
            }

            lr_mask = ~lr_mask;
            p_lrclk <: lr_mask;
        }
        else
        {
#pragma loop unroll
            for (size_t i = 0, idx = 0; i < num_in; i++, idx += 2)
            {
                int32_t data;
                asm volatile("in %0, res[%1]"
                            :"=r"(data)
                            :"r"(p_din[i]));
                set_port_shift_count(p_din[i], num_data_bits);
                in_samps[idx] = bitrev(data) & data_bit_mask;
            }

            lr_mask = ~lr_mask;
            partout(p_lrclk, num_data_bits, lr_mask);
        }

        if (restart == I2S_NO_RESTART) 
        {
            // Output i2s odds (1,3,5..)
            if (num_data_bits == 32)
            {
#pragma loop unroll
                for (size_t i = 0, idx = 1; i < num_out; i++, idx += 2)
                {
                    p_dout[i] <: bitrev(out_samps[idx]);
                }

                lr_mask = ~lr_mask;
                p_lrclk <: lr_mask;
            }
            else
            {
#pragma loop unroll
                for (size_t i = 0, idx = 1; i < num_out; i++, idx += 2)
                {
                    partout(p_dout[i], num_data_bits, bitrev(out_samps[idx] << data_bit_offset));
                }

                lr_mask = ~lr_mask;
                partout(p_lrclk, num_data_bits, lr_mask);
            }
        }

        // Input i2s odds (1,3,5..)
        if (num_data_bits == 32)
        {
#pragma loop unroll
            for (size_t i = 0, idx = 1; i < num_in; i++, idx += 2)
            {
                int32_t data;
                asm volatile("in %0, res[%1]"
                            :"=r"(data)
                            :"r"(p_din[i]));
                in_samps[idx] = bitrev(data);
            }
        }
        else
        {
#pragma loop unroll
            for (size_t i = 0, idx = 1; i < num_in; i++, idx += 2)
            {
                int32_t data;
                asm volatile("in %0, res[%1]"
                            :"=r"(data)
                            :"r"(p_din[i])
                            :"memory");
                set_port_shift_count(p_din[i], num_data_bits);
                in_samps[idx] = bitrev(data) & data_bit_mask;
            }
        }


        if (num_in) 
        {
            i2s_i.receive(num_in << 1, in_samps);
        }

        if (restart != I2S_NO_RESTART) 
        {
            if (!num_in) 
            {
                // Prevent the clock from being stopped before the last word
                // has been sent if there are no RX ports.
                sync(p_dout[0]);
            }
            stop_clock(bclk);
            return restart;
        }
    }
    return I2S_RESTART;
}

#define i2s_frame_master i2s_frame_master0

static void i2s_frame_master0(client i2s_frame_callback_if i2s_i,
                out buffered port:32 (&?p_dout)[num_out],
                static const size_t num_out,
                in buffered port:32 (&?p_din)[num_in],
                static const size_t num_in,
                static const size_t num_data_bits,
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
        
        i2s_setup_bclk(bclk, p_mclk, config.mclk_bclk_ratio);
        //This ensures that the port time on all the ports is at 0
        i2s_frame_init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

        i2s_restart_t restart =
          i2s_frame_ratio_n(i2s_i, p_dout, num_out, p_din,
                      num_in, num_data_bits, p_bclk, bclk, p_lrclk,
                      config.mode);

        if (restart == I2S_SHUTDOWN)
          return;
    }
}

#define i2s_frame_master_external_clock i2s_frame_master0_external_clock

static void i2s_frame_master0_external_clock(client i2s_frame_callback_if i2s_i,
                out buffered port:32 (&?p_dout)[num_out],
                static const size_t num_out,
                in buffered port:32 (&?p_din)[num_in],
                static const size_t num_in,
                static const size_t num_data_bits,
                out port p_bclk,
                out buffered port:32 p_lrclk,
                clock bclk){
    while(1){
        i2s_config_t config;
        i2s_i.init(config, null);

        if (isnull(p_dout) && isnull(p_din)) {
            fail("Must provide non-null p_dout or p_din");
        }


        //This ensures that the port time on all the ports is at 0
        i2s_frame_init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

        i2s_restart_t restart =
          i2s_frame_ratio_n(i2s_i, p_dout, num_out, p_din,
                      num_in, num_data_bits, p_bclk, bclk, p_lrclk,
                      config.mode);

        if (restart == I2S_SHUTDOWN)
          return;
    }
}

// These functions is just to avoid unused static function warnings for i2s_frame_master0
// and i2s_frame_master0_external_clock. They should never be called.
inline void i2s_frame_master1(client interface i2s_frame_callback_if i,
        out buffered port:32 i2s_dout[num_i2s_out],
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din[num_i2s_in],
        static const size_t num_i2s_in,
        static const size_t num_data_bits,
        out port i2s_bclk,
        out buffered port:32 i2s_lrclk,
        in port p_mclk,
        clock clk_bclk) {
    i2s_frame_master0(i, i2s_dout, num_i2s_out, i2s_din, num_i2s_in, num_data_bits,
                i2s_bclk, i2s_lrclk, p_mclk, clk_bclk);
}

inline void i2s_frame_master1_external_clock(client interface i2s_frame_callback_if i,
        out buffered port:32 i2s_dout[num_i2s_out],
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din[num_i2s_in],
        static const size_t num_i2s_in,
        static const size_t num_data_bits,
        out port i2s_bclk,
        out buffered port:32 i2s_lrclk,
        clock clk_bclk) {
    i2s_frame_master0_external_clock(i, i2s_dout, num_i2s_out, i2s_din, num_i2s_in, num_data_bits,
                i2s_bclk, i2s_lrclk, clk_bclk);
}

#endif // __XS2A__ || __XS3A__
