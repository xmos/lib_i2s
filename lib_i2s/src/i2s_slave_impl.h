// Copyright (c) 2015, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <xclib.h>
#include "i2s.h"

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
    configure_out_port(p_lrclk, bclk, 1);
    for (size_t i = 0; i < num_out; i++)
        configure_out_port(p_dout[i], bclk, 0);
    for (size_t i = 0; i < num_in; i++)
        configure_in_port(p_din[i], bclk);
    start_clock(bclk);
}

static void i2s_slave_send(client i2s_callback_if i2s_i,
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out, unsigned frame_word){
    for(size_t i=0;i<num_out;i++)
        p_dout[i] <: bitrev(i2s_i.send(i*2+frame_word));
}

static void i2s_slave_receive(client i2s_callback_if i2s_i,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in, unsigned frame_word){
    unsigned data;
    for(size_t i=0;i<num_in;i++){
              p_din[i] :> data;
      //asm("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
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

    unsigned port_time;
    i2s_slave_init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

    while(1){
        i2s_mode_t m;
        i2s_config_t config;
        i2s_restart_t restart = I2S_NO_RESTART;
        i2s_i.init(config, null);
        m = config.mode;

        clearbuf(p_lrclk);

        p_lrclk when pinseq(0x80000000) :> int @ port_time;
        port_time += (m == I2S_MODE_I2S);

  
        for(size_t i=0;i<num_out;i++)
            p_dout[i] @ port_time + 32+32  <: bitrev(i2s_i.send(i*2));



        i2s_slave_send(i2s_i, p_dout, num_out, 1);

        for(size_t i=0;i<num_in;i++)
            asm volatile("setpt res[%0], %1"::"r"(p_din[i]), "r"(port_time + 64+32-1):"memory");

        restart = i2s_i.restart_check();

        while(restart == I2S_NO_RESTART){
  
            i2s_slave_receive(i2s_i, p_din, num_in, 0);

            i2s_slave_send(i2s_i, p_dout, num_out, 0);


            i2s_slave_receive(i2s_i, p_din, num_in, 1);

            i2s_slave_send(i2s_i, p_dout, num_out, 1);

            restart = i2s_i.restart_check();

        }

        i2s_slave_receive(i2s_i, p_din, num_in, 0);
        i2s_slave_receive(i2s_i, p_din, num_in, 1);
        if (restart == I2S_SHUTDOWN)
          return;
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
