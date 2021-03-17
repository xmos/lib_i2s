// Copyright 2015-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <i2s.h>
#include <xs1.h>
#include <xclib.h>
#include "tdm_common.h"

static void tdm_init_ports(
        out buffered port:32 (&?p_dout)[num_out],
        const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        const size_t num_in,
        out buffered port:32 p_fsync,
        clock clk){
    stop_clock(clk);
    configure_out_port(p_fsync, clk, 0);
    for (size_t i = 0; i < num_out; i++)
        configure_out_port(p_dout[i], clk, 0);
    for (size_t i = 0; i < num_in; i++)
        configure_in_port(p_din[i], clk);
    start_clock(clk);
}

[[always_inline]]
static void tdm_send(client i2s_callback_if tdm_i,
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out,
        unsigned channels_per_data_line,
        unsigned word){
    for(size_t i=0;i<num_out;i++)
        p_dout[i] <: bitrev(tdm_i.send(i*channels_per_data_line + word));
}


[[always_inline]]
static void tdm_receive(client i2s_callback_if tdm_i,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        unsigned channels_per_data_line,
        unsigned word){
    for(size_t i=0;i<num_in;i++){
        uint32_t data;
        asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
        tdm_i.receive(i*channels_per_data_line + word, bitrev(data));
    }
}

[[always_inline]]
static i2s_restart_t do_tdm(client i2s_callback_if tdm_i,
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        out buffered port:32 p_fsync,
        int offset,
        unsigned sclk_edge_count,
        unsigned channels_per_data_line){
    i2s_restart_t restart = I2S_NO_RESTART;
    unsigned fsync_mask[TDM_MAX_CHANNELS_PER_DATA_LINE] ={0};

    p_fsync <: 0;
    make_fsync_mask(fsync_mask, offset, sclk_edge_count, channels_per_data_line);

    for(size_t i=0;i<num_out;i++){
        clearbuf(p_dout[i]);
        p_dout[i] <: 0;
    }
    for(size_t i=0;i<num_in;i++)
        clearbuf(p_din[i]);

    unsigned port_time;
    p_fsync <: 0 @ port_time;

    port_time += 80;//lots!

    if(offset < 0)
        partout_timed(p_fsync, -offset, bitrev(fsync_mask[channels_per_data_line-1]), port_time + offset);

    for(size_t i=0;i<num_in;i++)
        asm("setpt res[%0], %1"::"r"(p_din[i]), "r"(port_time+32-1));

    for(size_t i=0;i<num_out;i++)
        p_dout[i] @ port_time <: bitrev(tdm_i.send(i*channels_per_data_line + 0));

    p_fsync @ port_time <: fsync_mask[0];

    restart = tdm_i.restart_check();
    p_fsync <: fsync_mask[1];

    tdm_send(tdm_i, p_dout, num_out, channels_per_data_line, 1);

    for(unsigned frm_word_no = 2;frm_word_no < channels_per_data_line; frm_word_no++){
        tdm_receive(tdm_i, p_din, num_in, channels_per_data_line, frm_word_no-2);
        p_fsync <: fsync_mask[frm_word_no];
        tdm_send(tdm_i, p_dout, num_out, channels_per_data_line, frm_word_no);
    }

    while(1){
        if (restart != I2S_NO_RESTART){
            tdm_receive(tdm_i, p_din, num_in, channels_per_data_line, channels_per_data_line-2);
            tdm_receive(tdm_i, p_din, num_in, channels_per_data_line, channels_per_data_line-1);
            sync(p_din[0]);
            p_fsync <: 0;
            return restart;
        }

        tdm_receive(tdm_i, p_din, num_in, channels_per_data_line, channels_per_data_line-2);
        p_fsync <: fsync_mask[0];
        tdm_send(tdm_i, p_dout, num_out, channels_per_data_line, 0);

        restart = tdm_i.restart_check();

        for(unsigned frm_word_no=1;frm_word_no < channels_per_data_line; frm_word_no++){
            tdm_receive(tdm_i, p_din, num_in, channels_per_data_line,
                    (frm_word_no-2)&(channels_per_data_line-1));
            p_fsync <: fsync_mask[frm_word_no];
            tdm_send(tdm_i, p_dout, num_out, channels_per_data_line, frm_word_no);
        }
    }
    return I2S_RESTART;
}

#define tdm_master tdm_master0

static void tdm_master0(client interface i2s_callback_if tdm_i,
        out buffered port:32 p_fsync,
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        clock clk){

    if (isnull(p_dout) && isnull(p_din)) {
        fail("Must provide non-null p_dout or p_din");
    }

    tdm_init_ports(p_dout, num_out, p_din, num_in, p_fsync, clk);

    while(1){
        int offset;
        unsigned sclk_edge_count;
        unsigned channels_per_data_line;
        tdm_config_t config;

        tdm_i.init(null, config);
        i2s_restart_t restart =
          do_tdm(tdm_i,
                 p_dout,num_out,
                 p_din, num_in,
                 p_fsync,
                 config.offset, config.sync_len, config.channels_per_frame);
        if (restart == I2S_SHUTDOWN)
          return;
    }
}

// This function is just to avoid unused static function warnings for
// tdm_master0,it should never be called.
inline void tdm_master1(client interface i2s_callback_if tdm_i,
        out buffered port:32 p_fsync,
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        clock clk){
  tdm_master0(tdm_i, p_fsync, p_dout, num_out, p_din, num_in, clk);
}
