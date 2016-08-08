// Copyright (c) 2015-2016, XMOS Ltd, All rights reserved
#include <i2s.h>
#include "tdm_common.h"
#include <xs1.h>
#include <xclib.h>
#include <print.h>

static const unsigned i2s_tdm_clk_mask_lookup[5] = {
        0xaaaaaaaa, //div 2
        0xcccccccc, //div 4
        0xf0f0f0f0, //div 8
        0xff00ff00, //div 16
        0xffff0000, //div 32
};

static void i2s_tdm_init_i2s_ports(
        out buffered port:32 p_dout[num_out],
        static const size_t num_out,
        in buffered port:32 p_din[num_in],
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

static void i2s_tdm_init_tdm_ports(
        out buffered port:32 p_dout[num_out],
        const size_t num_out,
        in buffered port:32 p_din[num_in],
        const size_t num_in,
        out buffered port:32 p_fsync,
        clock clk){
    stop_clock(clk);
    configure_out_port(p_fsync, clk, 0);
    for (size_t i = 0; i < num_out; i++)
        configure_out_port(p_dout[i], clk, 0);
    for (size_t i = 0; i < num_in; i++)
        configure_in_port(p_din[i], clk);
   // start_clock(clk);
}

#pragma unsafe arrays
[[always_inline]]
static void i2s_tdm_do_tdm(
                           client i2s_callback_if i2s_i,
                           out buffered port:32 p_fsync,
                           size_t &fsync_index,
                           unsigned fsync_mask[TDM_MAX_CHANNELS_PER_DATA_LINE],
                           unsigned channels_per_data_line,
                           out buffered port:32 tdm_dout[],
                           size_t num_tdm_out,
                           in buffered port:32 tdm_din[],
                           size_t num_tdm_in,
                           size_t tdm_chan_offset_out,
                           size_t tdm_chan_offset_in,
                           out buffered port:32 p_bclk,
                           unsigned clk_mask,
                           int do_tdm_send,
                           int do_tdm_receive,
                           int do_bclk)
{
  if (do_tdm_receive) {
    for(size_t i=0;i<num_tdm_in;i++){
      uint32_t data;
      size_t prev_fsync_index =
        (fsync_index - 2) & (channels_per_data_line - 1);
      size_t chan_num =
        tdm_chan_offset_in + i*channels_per_data_line + prev_fsync_index;
      asm volatile("in %0, res[%1]":"=r"(data):"r"(tdm_din[i]):"memory");
      i2s_i.receive(chan_num, bitrev(data));
    }
  }
  p_fsync <: fsync_mask[fsync_index];
  if (do_tdm_send) {
    for (unsigned i=0;i<num_tdm_out;i++) {
      size_t chan_num =
        tdm_chan_offset_out + i*channels_per_data_line + fsync_index;
      tdm_dout[i] <: bitrev(i2s_i.send(chan_num));
    }
  }
  if (do_bclk)
    p_bclk <: clk_mask;
  if (do_tdm_receive) {
    for(size_t i=0;i<num_tdm_in;i++){
      uint32_t data;
      size_t prev_fsync_index =
        (fsync_index - 1) & (channels_per_data_line - 1);
      size_t chan_num =
        tdm_chan_offset_in + i*channels_per_data_line + prev_fsync_index;
      asm volatile("in %0, res[%1]":"=r"(data):"r"(tdm_din[i]):"memory");
      i2s_i.receive(chan_num, bitrev(data));
    }
  }
  p_fsync <: fsync_mask[fsync_index+1];
  if (do_tdm_send) {
    for (unsigned i=0;i<num_tdm_out;i++) {
      size_t chan_num =
        tdm_chan_offset_out + i*channels_per_data_line + fsync_index + 1;
      tdm_dout[i] <: bitrev(i2s_i.send(chan_num));
    }
  }
  if (do_bclk)
    p_bclk <: clk_mask;
  fsync_index += 2;
  fsync_index = fsync_index & (channels_per_data_line - 1);
}

#pragma unsafe arrays
[[always_inline]]
static void i2s_tdm_output_word(
        out buffered port:32 p_lrclk,
        unsigned &lr_mask,
        unsigned total_clk_pairs,
        client i2s_callback_if i2s_i,
        out buffered port:32 p_dout[num_out],
        static const size_t num_out,
        in buffered port:32 p_din[num_in],
        static const size_t num_in,
        out buffered port:32 p_bclk,
        unsigned clk_mask,
        unsigned calls_per_pair,
        unsigned offset,
        out buffered port:32 p_fsync,
        size_t &fsync_index,
        unsigned fsync_mask[TDM_MAX_CHANNELS_PER_DATA_LINE],
        unsigned channels_per_data_line,
        out buffered port:32 tdm_dout[],
        size_t num_tdm_out,
        in buffered port:32 tdm_din[],
        size_t num_tdm_in,
        size_t tdm_chan_offset_out,
        size_t tdm_chan_offset_in,
        int in_tail_section,
        int do_tdm_receive ) {
    //This is non-blocking
    lr_mask = ~lr_mask;
    p_lrclk <: lr_mask;

    unsigned if_call_num = 0;
    for(unsigned clk_pair=0; clk_pair < total_clk_pairs;clk_pair++){
        for(unsigned i=0;i<calls_per_pair;i++){
            if(if_call_num < num_in){
                unsigned data;
                unsigned index = if_call_num;
                asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[if_call_num]):"memory");
                i2s_i.receive(index*2 + offset, bitrev(data));
            } else if(if_call_num < num_in + num_out){
              if (!in_tail_section) {
                unsigned index = if_call_num - num_in;
                p_dout[index] <: bitrev(i2s_i.send(index*2 + offset));
              }
            }
            if_call_num++;
        }
        //This is blocking
        int do_tdm_send =
          !in_tail_section || (offset == 0 && clk_pair < total_clk_pairs - 1);
        int do_bclk =
          !in_tail_section || offset == 0 || clk_pair < total_clk_pairs - 1;
        i2s_tdm_do_tdm(i2s_i, p_fsync, fsync_index, fsync_mask, channels_per_data_line,
                       tdm_dout, num_tdm_out, tdm_din, num_tdm_in,
                       tdm_chan_offset_out, tdm_chan_offset_in,
                       p_bclk, clk_mask, do_tdm_send, do_tdm_receive, do_bclk);
    }
}

#pragma unsafe arrays
[[always_inline]]
static void i2s_tdm_do_tdm_out(client i2s_callback_if i2s_i,
                              out buffered port:32 tdm_dout[num_tdm_out],
                              size_t num_tdm_out,
                              unsigned tdm_chan_offset_out,
                              unsigned channels_per_data_line,
                              int index)
{
  for (unsigned i=0;i<num_tdm_out;i++) {
    size_t chan_num = tdm_chan_offset_out + i*channels_per_data_line + index;
    tdm_dout[i] <: bitrev(i2s_i.send(chan_num));
  }
}

#pragma unsafe arrays
[[always_inline]]
static void i2s_tdm_do_tdm_in(client i2s_callback_if i2s_i,
                              in buffered port:32 tdm_din[num_tdm_in],
                              size_t num_tdm_in,
                              unsigned tdm_chan_offset_in,
                              unsigned channels_per_data_line,
                              int index)
{
    for(size_t i=0;i<num_tdm_in;i++){
      uint32_t data;
      size_t prev_fsync_index =
        (index - 2) & (channels_per_data_line - 1);
      size_t chan_num =
        tdm_chan_offset_in + i*channels_per_data_line + prev_fsync_index;
      asm volatile("in %0, res[%1]":"=r"(data):"r"(tdm_din[i]):"memory");
      i2s_i.receive(chan_num, bitrev(data));
    }
}

#pragma unsafe arrays
static i2s_restart_t i2s_tdm_ratio_n(client i2s_callback_if i2s_i,
        out buffered port:32 p_dout[num_out],
        static const size_t num_out,
        in buffered port:32 p_din[num_in],
        static const size_t num_in,
        out buffered port:32 p_bclk,
        out buffered port:32 p_lrclk,
        unsigned ratio,
        i2s_mode_t mode,
        out buffered port:32 tdm_dout[],
        size_t num_tdm_out,
        in buffered port:32 tdm_din[],
        size_t num_tdm_in,
        out buffered port:32 p_fsync,
        int tdm_offset,
        unsigned sclk_edge_count,
        unsigned channels_per_data_line,
        clock mclk){
    unsigned clk_mask = i2s_tdm_clk_mask_lookup[ratio-1];
    unsigned lr_mask = 0;
    i2s_restart_t restart = I2S_NO_RESTART;
    unsigned fsync_mask[TDM_MAX_CHANNELS_PER_DATA_LINE] ={0};
    size_t tdm_chan_offset_in = num_in * 2;
    size_t tdm_chan_offset_out = num_out * 2;

    unsigned total_clk_pairs = (1<<(ratio-1));
    unsigned calls_per_pair = ((num_in + num_out) + (1<<(ratio-1))-1)>>(ratio-1);

    make_fsync_mask(fsync_mask, tdm_offset, sclk_edge_count,
                    channels_per_data_line);

    for(size_t i=0;i<num_out;i++)
        clearbuf(p_dout[i]);
    for(size_t i=0;i<num_in;i++)
        clearbuf(p_din[i]);
    clearbuf(p_lrclk);
    clearbuf(p_bclk);
    clearbuf(p_fsync);
    for (size_t i=0;i<num_tdm_out;i++)
        clearbuf(tdm_dout[i]);
    for (size_t i=0;i<num_tdm_in;i++)
        clearbuf(tdm_din[i]);
    //Preload word 0
    if(mode == I2S_MODE_I2S){
        for(size_t i=0;i<num_out;i++)
            p_dout[i] @ 2 <: bitrev(i2s_i.send(i*2));
        partout(p_lrclk, 1, 0);
        for(size_t i=0;i<num_in;i++)
            asm("setpt res[%0], %1"::"r"(p_din[i]), "r"(32+1));
        lr_mask = 0x80000000;
        partout(p_bclk, 1<<ratio, clk_mask);
     } else {
       for(size_t i=0;i<num_out;i++)
           p_dout[i] <: bitrev(i2s_i.send(i*2));
     }
     size_t fsync_index = 0;

      p_fsync <: fsync_mask[fsync_index];
      for (unsigned i=0;i<num_tdm_out;i++) {
        size_t chan_num =
          tdm_chan_offset_out + i*channels_per_data_line + fsync_index;
        tdm_dout[i] <: bitrev(i2s_i.send(chan_num));
      }
      start_clock(mclk);
      p_lrclk <: lr_mask;
      p_bclk <: clk_mask;
      p_fsync <: fsync_mask[fsync_index+1];
      for (unsigned i=0;i<num_tdm_out;i++) {
          size_t chan_num =
            tdm_chan_offset_out + i*channels_per_data_line + fsync_index + 1;
          tdm_dout[i] <: bitrev(i2s_i.send(chan_num));
      }
      fsync_index += 2;
      fsync_index = fsync_index & (channels_per_data_line - 1);
      p_bclk <: clk_mask;

     //This is non-blocking
     lr_mask = ~lr_mask;
     p_lrclk <: lr_mask;

     //Now preload word 1
     unsigned if_call_num = 0;
     for(unsigned clk_pair=0; clk_pair < total_clk_pairs;clk_pair++){
         for(unsigned i=0;i<calls_per_pair;i++){
             if(if_call_num < num_out)
                 p_dout[if_call_num] <: bitrev(i2s_i.send(if_call_num*2+1));

             if_call_num++;
         }
         //This is blocking
         i2s_tdm_do_tdm(i2s_i, p_fsync, fsync_index, fsync_mask,
                        channels_per_data_line,
                        tdm_dout, num_tdm_out, tdm_din, num_tdm_in,
                        tdm_chan_offset_out, tdm_chan_offset_in, p_bclk,
                        clk_mask, 1, 1, 1);
     }

    //body
    while(1){
      restart = i2s_i.restart_check();
      if (restart != I2S_NO_RESTART) {
        for (int i = 0; i < num_in ; i++) {
          int32_t data;
          asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
          i2s_i.receive(i*2, bitrev(data));
        }
        i2s_tdm_do_tdm_in(i2s_i,
                          tdm_din, num_tdm_in, tdm_chan_offset_in,
                          channels_per_data_line,
                          fsync_index);
        p_bclk <: clk_mask;
        i2s_tdm_do_tdm_out(i2s_i,
                          tdm_dout, num_tdm_out, tdm_chan_offset_out,
                          channels_per_data_line,
                           fsync_index);
        i2s_tdm_do_tdm_in(i2s_i,
                          tdm_din, num_tdm_in, tdm_chan_offset_in,
                          channels_per_data_line,
                          fsync_index + 1);
        p_bclk <: clk_mask;
        i2s_tdm_do_tdm_out(i2s_i,
                          tdm_dout, num_tdm_out, tdm_chan_offset_out,
                          channels_per_data_line,
                          fsync_index + 1);
        i2s_tdm_do_tdm_in(i2s_i,
                          tdm_din, num_tdm_in, tdm_chan_offset_in,
                          channels_per_data_line,
                          fsync_index + 2);
        i2s_tdm_do_tdm_in(i2s_i,
                          tdm_din, num_tdm_in, tdm_chan_offset_in,
                          channels_per_data_line,
                          fsync_index + 3);
        for (int i = 0; i < num_in ; i++) {
          int32_t data;
          asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
          i2s_i.receive(i*2+1, bitrev(data));
        }
        sync(p_bclk);
        return restart;
      } else {
        i2s_tdm_output_word(p_lrclk, lr_mask, total_clk_pairs, i2s_i,
                            p_dout, num_out,
                            p_din, num_in, p_bclk, clk_mask, calls_per_pair, 0,
                            p_fsync, fsync_index, fsync_mask,
                            channels_per_data_line,
                            tdm_dout, num_tdm_out, tdm_din, num_tdm_in,
                            tdm_chan_offset_out, tdm_chan_offset_in, 0, 1);
      }

      i2s_tdm_output_word(p_lrclk, lr_mask, total_clk_pairs, i2s_i,
                          p_dout, num_out,
                          p_din, num_in, p_bclk, clk_mask, calls_per_pair,
                          1,
                          p_fsync, fsync_index, fsync_mask,
                          channels_per_data_line,
                          tdm_dout, num_tdm_out, tdm_din, num_tdm_in,
                          tdm_chan_offset_out, tdm_chan_offset_in, 0, 1);

    }
    return I2S_RESTART;
}

#define i2s_tdm_master i2s_tdm_master0

static void i2s_tdm_master0(client interface i2s_callback_if i,
        out buffered port:32 i2s_dout[num_i2s_out],
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din[num_i2s_in],
        static const size_t num_i2s_in,
        out buffered port:32 i2s_bclk,
        out buffered port:32 i2s_lrclk,
        out buffered port:32 tdm_fsync,
        out buffered port:32 tdm_dout[num_tdm_out],
        size_t num_tdm_out,
        in buffered port:32 tdm_din[num_tdm_in],
        size_t num_tdm_in,
        clock clk_bclk,
        clock clk_mclk) {
    while(1){
        //This ensures that the port time on all the ports is at 0
        i2s_tdm_init_i2s_ports(i2s_dout, num_i2s_out, i2s_din, num_i2s_in,
                       i2s_bclk, i2s_lrclk, clk_bclk, clk_mclk);

        i2s_tdm_init_tdm_ports(tdm_dout, num_tdm_out, tdm_din, num_tdm_in,
                       tdm_fsync, clk_mclk);

        i2s_config_t i2s_config;
        tdm_config_t tdm_config;
        unsigned mclk_bclk_ratio_log2;
        i.init(i2s_config, tdm_config);

        mclk_bclk_ratio_log2 = clz(bitrev(i2s_config.mclk_bclk_ratio));

        i2s_restart_t restart =
          i2s_tdm_ratio_n(i, i2s_dout, num_i2s_out, i2s_din,
                num_i2s_in, i2s_bclk, i2s_lrclk,
                mclk_bclk_ratio_log2,
                i2s_config.mode,
                tdm_dout, num_tdm_out,
                tdm_din, num_tdm_in,
                tdm_fsync,
                tdm_config.offset, tdm_config.sync_len,
                tdm_config.channels_per_frame,
                clk_mclk);

        if (restart == I2S_SHUTDOWN)
          return;
    }
}

// This function is just to avoid unused static function warnings for i2s_tdm_master0,
// it should never be called.
inline void i2s_tdm_master1(client interface i2s_callback_if i,
        out buffered port:32 i2s_dout[num_i2s_out],
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din[num_i2s_in],
        static const size_t num_i2s_in,
        out buffered port:32 i2s_bclk,
        out buffered port:32 i2s_lrclk,
        out buffered port:32 tdm_fsync,
        out buffered port:32 tdm_dout[num_tdm_out],
        size_t num_tdm_out,
        in buffered port:32 tdm_din[num_tdm_in],
        size_t num_tdm_in,
        clock clk_bclk,
        clock clk_mclk) {
    i2s_tdm_master0(i, i2s_dout, num_i2s_out, i2s_din, num_i2s_in, i2s_bclk, i2s_lrclk,
            tdm_fsync, tdm_dout, num_tdm_out, tdm_din, num_tdm_in, clk_bclk, clk_mclk);
}

