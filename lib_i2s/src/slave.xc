#include <xs1.h>
#include <xclib.h>
#include "i2s.h"

static void init_ports(
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
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

static void send(client i2s_slave_callback_if i2s_i,
        out buffered port:32 p_dout[num_out],
        size_t num_out, unsigned frame_word){
    for(size_t i=0;i<num_out;i++)
        p_dout[i] <: bitrev(i2s_i.send(i*2+frame_word));
}

static void recieve(client i2s_slave_callback_if i2s_i,
        in buffered port:32 p_din[num_in],
        size_t num_in, unsigned frame_word){
    unsigned data;
    for(size_t i=0;i<num_in;i++){
        p_din[i] :> data;
        i2s_i.receive(i*2 + frame_word, bitrev(data));
    }
}

void i2s_slave(client i2s_slave_callback_if i2s_i,
        out buffered port:32 p_dout[num_out],
        static const size_t num_out,
        in buffered port:32 p_din[num_in],
        static const size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk){

    unsigned time, port_time;
    timer t;
    init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

    while(1){
        i2s_mode m;
        i2s_i.init(m);
        unsigned restart = 0;

        clearbuf(p_lrclk);

        p_lrclk when pinseq(0x80000000) :> int @ port_time;
        port_time += (m == I2S_MODE_I2S);

  
        for(size_t i=0;i<num_out;i++)
            p_dout[i] @ port_time + 32+32  <: bitrev(i2s_i.send(i*2));



        send(i2s_i, p_dout, num_out, 1);

        for(size_t i=0;i<num_in;i++)
            asm volatile("setpt res[%0], %1"::"r"(p_din[i]), "r"(port_time + 64+32-1):"memory");
      t:> time;
        i2s_i.frame_start(time, restart);


        while(restart == 0){

  
            recieve(i2s_i, p_din, num_in, 0);

            send(i2s_i, p_dout, num_out, 0);


            recieve(i2s_i, p_din, num_in, 1);

            send(i2s_i, p_dout, num_out, 1);
          t:> time;
            i2s_i.frame_start(time, restart);


        }

        recieve(i2s_i, p_din, num_in, 0);
        recieve(i2s_i, p_din, num_in, 1);
    }
}
