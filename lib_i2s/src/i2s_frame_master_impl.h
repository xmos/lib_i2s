// Copyright (c) 2016, XMOS Ltd, All rights reserved
#if defined(__XS2A__)

#include <xs1.h>
#include <xclib.h>
#include "i2s.h"
#include "xassert.h"

static void i2s_frame_init_ports(
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        out port p_bclk,
        out buffered port:32 p_lrclk,
        clock bclk,
        in port p_mclk,
        unsigned mclk_bclk_ratio){

    set_clock_on(bclk);
    configure_clock_src_divide(bclk, p_mclk, mclk_bclk_ratio >> 1);
    configure_port_clock_output(p_bclk, bclk);
    configure_out_port(p_lrclk, bclk, 1);
    for (size_t i = 0; i < num_out; i++)
        configure_out_port(p_dout[i], bclk, 0);
    for (size_t i = 0; i < num_in; i++)
        configure_in_port(p_din[i], bclk);
}

#pragma unsafe arrays
static i2s_restart_t i2s_frame_ratio_n(client i2s_frame_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        out port p_bclk,
        clock bclk,
        out buffered port:32 p_lrclk,
        unsigned ratio,
        i2s_mode_t mode){

    int32_t in_samps[16]; //Workaround: should be (num_in << 1) but compiler thinks that isn't const,
    int32_t out_samps[16];//so setting to 16 which should be big enough for most cases

    // Since #pragma unsafe arrays is used need to ensure array won't overflow.
    assert((num_in << 1) <= 16);

    unsigned lr_mask = 0;

    for (size_t i=0;i<num_out;i++)
        clearbuf(p_dout[i]);
    for (size_t i=0;i<num_in;i++)
        clearbuf(p_din[i]);
    clearbuf(p_lrclk);

    if (num_out) i2s_i.send(num_out << 1, out_samps);

    //Start outputting evens (0,2,4..) data at correct point relative to the clock
    int offset = 0;
    if (mode==I2S_MODE_I2S) {
        offset = 1;
    }

#pragma loop unroll
    for (size_t i=0, idx=0; i<num_out; i++, idx+=2){
        p_dout[i] @ (1 + offset) <: bitrev(out_samps[idx]);
    }

    p_lrclk @ 1 <: lr_mask;

    start_clock(bclk);

    //And pre-load the odds (1,3,5..)
#pragma loop unroll
    for (size_t i=0, idx=1; i<num_out; i++, idx+=2){
        p_dout[i] <: bitrev(out_samps[idx]);
    }

    lr_mask = ~lr_mask;
    p_lrclk <: lr_mask;

    for (size_t i=0;i<num_in;i++) {
        asm("setpt res[%0], %1"::"r"(p_din[i]), "r"(32 + offset));
    }

    while(1) {
        // Check for restart
        i2s_restart_t restart = i2s_i.restart_check();

        if (restart == I2S_NO_RESTART) {
            if (num_out) i2s_i.send(num_out << 1, out_samps);

            //Output i2s evens (0,2,4..)
#pragma loop unroll
            for (size_t i=0, idx=0; i<num_out; i++, idx+=2){
                p_dout[i] <: bitrev(out_samps[idx]);
            }
        }

        //Input i2s evens (0,2,4..)
#pragma loop unroll
        for (size_t i=0, idx=0; i<num_in; i++, idx+=2){
            int32_t data;
            asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
            in_samps[idx] = bitrev(data);
        }

        lr_mask = ~lr_mask;
        p_lrclk <: lr_mask;

        if (restart == I2S_NO_RESTART) {
            //Output i2s odds (1,3,5..)
#pragma loop unroll
            for (size_t i=0, idx=1; i<num_out; i++, idx+=2){
                p_dout[i] <: bitrev(out_samps[idx]);
            }

            lr_mask = ~lr_mask;
            p_lrclk <: lr_mask;
        }

        //Input i2s odds (1,3,5..)
#pragma loop unroll
        for (size_t i=0, idx=1; i<num_in; i++, idx+=2){
            int32_t data;
            asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
            in_samps[idx] = bitrev(data);
        }

        if (num_in) i2s_i.receive(num_in << 1, in_samps);

        if (restart != I2S_NO_RESTART) {
            if (!num_in) {
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
                out port p_bclk,
                out buffered port:32 p_lrclk,
                in port p_mclk,
                clock bclk){
    while(1){
        i2s_config_t config;
        unsigned mclk_bclk_ratio_log2;
        i2s_i.init(config, null);

        if (isnull(p_dout) && isnull(p_din)) {
            fail("Must provide non-null p_dout or p_din");
        }

        mclk_bclk_ratio_log2 = clz(bitrev(config.mclk_bclk_ratio));

        //This ensures that the port time on all the ports is at 0
        i2s_frame_init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk,
            p_mclk, config.mclk_bclk_ratio);

        i2s_restart_t restart =
          i2s_frame_ratio_n(i2s_i, p_dout, num_out, p_din,
                      num_in, p_bclk, bclk, p_lrclk,
                      mclk_bclk_ratio_log2, config.mode);

        if (restart == I2S_SHUTDOWN)
          return;
    }
}

// This function is just to avoid unused static function warnings for i2s_tdm_master0,
// it should never be called.
inline void i2s_frame_master1(client interface i2s_frame_callback_if i,
        out buffered port:32 i2s_dout[num_i2s_out],
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din[num_i2s_in],
        static const size_t num_i2s_in,
        out port i2s_bclk,
        out buffered port:32 i2s_lrclk,
        in port p_mclk,
        clock clk_bclk) {
    i2s_frame_master0(i, i2s_dout, num_i2s_out, i2s_din, num_i2s_in,
                i2s_bclk, i2s_lrclk, p_mclk, clk_bclk);
}

#endif // __XS2A__
