// Copyright 2015-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <xclib.h>
#include "i2s.h"
#include "xassert.h"

#define FRAME_WORDS (2)

static const unsigned i2s_clk_mask_lookup[5] = {
        0xaaaaaaaa, //div 2
        0xcccccccc, //div 4
        0xf0f0f0f0, //div 8
        0xff00ff00, //div 16
        0xffff0000, //div 32
};

static void i2s_init_ports(
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        out buffered port:32 p_bclk,
        out buffered port:32 p_lrclk,
        clock bclk,
        const clock mclk){
    set_clock_on(bclk);
    configure_clock_src(bclk, p_bclk);
    configure_out_port(p_bclk, mclk, 1);
    configure_out_port(p_lrclk, bclk, 1);
    for (size_t i = 0; i < num_out; i++)
        configure_out_port(p_dout[i], bclk, 0);
    for (size_t i = 0; i < num_in; i++)
        configure_in_port(p_din[i], bclk);
    start_clock(bclk);
}

static void inline i2s_output_clock_pair(out buffered port:32 p_bclk,unsigned clk_mask){
    p_bclk <: clk_mask;
    p_bclk <: clk_mask;
}

#pragma unsafe arrays
static void output_word(
        out buffered port:32 p_lrclk,
        unsigned &lr_mask,
        unsigned total_clk_pairs,
        client i2s_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        out buffered port:32 p_bclk,
        unsigned clk_mask,
        unsigned calls_per_pair,
        unsigned offset){
    //This is non-blocking
    lr_mask = ~lr_mask;
    p_lrclk <: lr_mask;

    unsigned if_call_num = 0;
    for(unsigned clk_pair=0; clk_pair < total_clk_pairs;clk_pair++){
        for(unsigned i=0;i<calls_per_pair;i++){
            if(if_call_num < num_in){
                unsigned data;
                asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[if_call_num]):"memory");
                i2s_i.receive(if_call_num*FRAME_WORDS + offset, bitrev(data));
            } else if(if_call_num < num_in + num_out){
                unsigned index = if_call_num - num_in;
                p_dout[index] <: bitrev(i2s_i.send(index*FRAME_WORDS + offset));
            }
            if_call_num++;
        }
        //This is blocking
        i2s_output_clock_pair(p_bclk,  clk_mask);
    }
}
#pragma unsafe arrays
static i2s_restart_t i2s_ratio_n(client i2s_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        out buffered port:32 p_bclk,
        out buffered port:32 p_lrclk,
        unsigned ratio,
        i2s_mode_t mode){
    unsigned clk_mask = i2s_clk_mask_lookup[ratio-1];
    unsigned lr_mask = 0;
    int32_t data;

    unsigned total_clk_pairs = (1<<(ratio-1));
    unsigned calls_per_pair = ((num_in + num_out) + (1<<(ratio-1))-1)>>(ratio-1);

    for(size_t i=0;i<num_out;i++)
        clearbuf(p_dout[i]);
    for(size_t i=0;i<num_in;i++)
        clearbuf(p_din[i]);
    clearbuf(p_lrclk);
    clearbuf(p_bclk);

    //Preload word 0
    if(mode == I2S_MODE_I2S){
        for(size_t i=0;i<num_out;i++)
            p_dout[i] @ 2 <: bitrev(i2s_i.send(i*FRAME_WORDS));
        partout(p_lrclk, 1, 0);
        for(size_t i=0;i<num_in;i++)
            asm("setpt res[%0], %1"::"r"(p_din[i]), "r"(32+1));
        lr_mask = 0x80000000;
        partout(p_bclk, 1<<ratio, clk_mask);
     } else {
       for(size_t i=0;i<num_out;i++)
           p_dout[i] <: bitrev(i2s_i.send(i*FRAME_WORDS));
     }
     p_lrclk <: lr_mask;
     i2s_output_clock_pair(p_bclk,  clk_mask);

     //This is non-blocking
     lr_mask = ~lr_mask;
     p_lrclk <: lr_mask;

     //Now preload word 1
     unsigned if_call_num = 0;
     for(unsigned clk_pair=0; clk_pair < total_clk_pairs;clk_pair++){
         for(unsigned i=0;i<calls_per_pair;i++){
             if(if_call_num < num_out)
                 p_dout[if_call_num] <: bitrev(i2s_i.send(if_call_num*FRAME_WORDS+1));

             if_call_num++;
         }
         //This is blocking
         i2s_output_clock_pair(p_bclk,  clk_mask);
     }

     for(unsigned frm_word_no=1;frm_word_no < FRAME_WORDS - 1; frm_word_no++){
         output_word(p_lrclk, lr_mask, total_clk_pairs, i2s_i, p_dout, num_out,
                 p_din, num_in, p_bclk, clk_mask, calls_per_pair, (1 + frm_word_no)%FRAME_WORDS);
     }

    //body
    while(1){
        // Do the first (FRAME_WORDS-1) words of the frame
        i2s_restart_t restart = i2s_i.restart_check();

        // The final word of each frame is special as it might terminate the transfer
        if (restart != I2S_NO_RESTART) {
            if_call_num = 0;
            for(unsigned clk_pair=0; clk_pair < total_clk_pairs;clk_pair++){
                for(unsigned i=0;i<calls_per_pair;i++){
                    if(if_call_num < num_in){
                        asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[if_call_num]):"memory");
                        i2s_i.receive(if_call_num*FRAME_WORDS + FRAME_WORDS - 2, bitrev(data));
                    }
                    if_call_num++;
                }
                if(clk_pair < total_clk_pairs-1)
                    i2s_output_clock_pair(p_bclk,  clk_mask);
            }
            sync(p_bclk);
            for(size_t i=0;i<num_in;i++){
                asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
                i2s_i.receive(i*FRAME_WORDS + FRAME_WORDS - 1, bitrev(data));
            }
            return restart;
        } else {
            output_word(p_lrclk, lr_mask, total_clk_pairs, i2s_i, p_dout, num_out,
                    p_din, num_in, p_bclk, clk_mask, calls_per_pair, 0);
        }

        for(unsigned frm_word_no=0;frm_word_no < FRAME_WORDS-1; frm_word_no++){
            output_word(p_lrclk, lr_mask, total_clk_pairs, i2s_i, p_dout, num_out,
                    p_din, num_in, p_bclk, clk_mask, calls_per_pair, (1 + frm_word_no)%FRAME_WORDS);
        }
    }
    return I2S_RESTART;
}

#define i2s_master i2s_master0

static void i2s_master0(client i2s_callback_if i2s_i,
                out buffered port:32 (&?p_dout)[num_out],
                static const size_t num_out,
                in buffered port:32 (&?p_din)[num_in],
                static const size_t num_in,
                out buffered port:32 p_bclk,
                out buffered port:32 p_lrclk,
                clock bclk,
                const clock mclk){

    while(1){
        i2s_config_t config;
        unsigned mclk_bclk_ratio_log2;
        i2s_i.init(config, null);

        if (isnull(p_dout) && isnull(p_din)) {
            fail("Must provide non-null p_dout or p_din");
        }

        mclk_bclk_ratio_log2 = clz(bitrev(config.mclk_bclk_ratio));

        //This ensures that the port time on all the ports is at 0
        i2s_init_ports(p_dout, num_out, p_din, num_in,
           p_bclk, p_lrclk, bclk, mclk);

        i2s_restart_t restart =
          i2s_ratio_n(i2s_i, p_dout, num_out, p_din,
                      num_in, p_bclk, p_lrclk,
                      mclk_bclk_ratio_log2, config.mode);
        if (restart == I2S_SHUTDOWN)
          return;
    }
}

// This function is just to avoid unused static function warnings for i2s_master0,
// it should never be called.
inline void i2s_master1(client interface i2s_callback_if i,
        out buffered port:32 i2s_dout[num_i2s_out],
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din[num_i2s_in],
        static const size_t num_i2s_in,
        out buffered port:32 i2s_bclk,
        out buffered port:32 i2s_lrclk,
        clock clk_bclk,
        const clock clk_mclk) {
    i2s_master0(i, i2s_dout, num_i2s_out, i2s_din, num_i2s_in,
                i2s_bclk, i2s_lrclk,
                clk_bclk, clk_mclk);
}

