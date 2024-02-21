// Copyright 2015-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <xclib.h>
#include "i2s.h"

#define I2S_CHANS_PER_FRAME (2)

static void i2s_slave_init_ports(
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk){
    set_clock_on(bclk);
    configure_clock_src(bclk, p_bclk);
    configure_in_port(p_lrclk, bclk);
    for (size_t i = 0; i < num_out; i++) {
        configure_out_port(p_dout[i], bclk, 0);
    }
    for (size_t i = 0; i < num_in; i++) {
        configure_in_port(p_din[i], bclk);
    }
    start_clock(bclk);
}

static void i2s_slave_send(client i2s_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out, unsigned frame_word){
    for(size_t i=0;i<num_out;i++) {
        p_dout[i] <: bitrev(i2s_i.send(i*2+frame_word));
    }
}

static void i2s_slave_receive(client i2s_callback_if i2s_i,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in, unsigned frame_word){
    for (size_t i=0;i<num_in;i++) {
        unsigned data;
        p_din[i] :> data;
        i2s_i.receive(i*2 + frame_word, bitrev(data));
    }
}

#define i2s_slave i2s_slave0

static void i2s_slave0(client i2s_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk){

    unsigned syncerror;
    unsigned lrval;
    unsigned port_time;
    i2s_slave_init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

    i2s_config_t config;
    config.slave_frame_synch_error = 0;

    while(1) {
        i2s_mode_t m;
        i2s_restart_t restart = I2S_NO_RESTART;
        config.slave_bclk_polarity = I2S_SLAVE_SAMPLE_ON_BCLK_RISING;
        i2s_i.init(config, null);
        config.slave_frame_synch_error = 0;

        m = config.mode;

        if (config.slave_bclk_polarity == I2S_SLAVE_SAMPLE_ON_BCLK_FALLING)
            set_port_inv(p_bclk);
        else
            set_port_no_inv(p_bclk);

        unsigned expected_low  = (m==I2S_MODE_I2S) ? 0 : 0x80000000;
        unsigned expected_high = (m==I2S_MODE_I2S) ? 0xffffffff : 0x7fffffff;

        syncerror = 0;

        clearbuf(p_lrclk);

        /* Wait for LRCLK edge (in I2S LRCLK = 0 is left, TDM rising edge is start of frame) */
        p_lrclk when pinseq(1) :> void;
        p_lrclk when pinseq(0) :> void @ port_time;

        for (size_t i=0;i<num_out;i++) {
            p_dout[i] @ (port_time+32+32+(m==I2S_MODE_I2S)) <: bitrev(i2s_i.send(i*2));
        }

        /* Setup input for next frame. Account for the buffering in port */
        port_time += ((I2S_CHANS_PER_FRAME*32)+32);

        /* XC doesn't have syntax for setting a timed input without waiting for the input */
        /* -1 on LRClock makes checking a lot easier since data is offset with LRclock by 1 clk */
        asm("setpt res[%0], %1"::"r"(p_lrclk),"r"(port_time-(m==I2S_MODE_I2S)));
        for (size_t i=0;i<num_in;i++) {
            asm("setpt res[%0], %1"::"r"(p_din[i]),"r"(port_time-(m!=I2S_MODE_I2S)));
        }

        while (!syncerror && (restart == I2S_NO_RESTART)) {
            i2s_slave_send(i2s_i, p_dout, num_out, 1);

            i2s_slave_receive(i2s_i, p_din, num_in, 0);
            p_lrclk :> lrval;
            syncerror += (lrval != expected_low);

            restart = i2s_i.restart_check();
            if (restart == I2S_NO_RESTART) {
                i2s_slave_send(i2s_i, p_dout, num_out, 0);
            }

            i2s_slave_receive(i2s_i, p_din, num_in, 1);
            p_lrclk :> lrval;
            syncerror += (lrval != expected_high);
        }

        if (restart == I2S_SHUTDOWN) {
            return;
        }

        if(syncerror){
            config.slave_frame_synch_error = 1;
        }
    }
}

// This function is just to avoid unused static function warnings for
// i2s_slave0,it should never be called.
inline void i2s_slave1(client i2s_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk){

    if (isnull(p_dout) && isnull(p_din)) {
        fail("Must provide non-null p_dout or p_din");
    }

    i2s_slave0(i2s_i, p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);
}
