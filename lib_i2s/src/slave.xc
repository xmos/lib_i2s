#include <xs1.h>
#include <xclib.h>
#include "i2s.h"

static void init_ports(
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
        size_t num_in,
        in port p_bclk,
        in port p_lrclk,
        clock bclk){

    set_clock_on(bclk);
    configure_clock_src(bclk, p_bclk);
    configure_out_port(p_lrclk, bclk, 1);
    for (size_t i = 0; i < num_out; i++)
        configure_out_port(p_dout[i], bclk, 0);
    for (size_t i = 0; i < num_in; i++)
        configure_in_port(p_din[i], bclk);
}


#include <stdio.h>

void i2s_slave(client i2s_slave_callback_if i2s_i,
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
        size_t num_in,
        in port p_bclk,
        in port p_lrclk,
        clock bclk){

    unsigned data;
    unsigned time;
    timer t;
    init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);
    while(1){
        i2s_mode m;
        i2s_i.init(m);
        //wait for lrckl to be high and bclk to be high

        start_clock(bclk);
        t:> time;
        unsigned restart = 0;
        i2s_i.frame_start(time, restart);

        for(size_t i=0;i<num_in;i++){
           clearbuf(p_din[i]);
        }

        for(size_t i=0;i<num_out;i++)
            p_dout[i] <: bitrev(i2s_i.send(i*2));

        for(size_t i=0;i<num_out;i++)
            p_dout[i] <: bitrev(i2s_i.send(i*2+1));



        while(restart == 0){


            t:> time;
            i2s_i.frame_start(time, restart);

            for(size_t i=0;i<num_in;i++){
                p_din[i] :> data;
                i2s_i.receive(i*2, bitrev(data));
            }

            for(size_t i=0;i<num_out;i++)
                p_dout[i] <: bitrev(i2s_i.send(i*2));

            for(size_t i=0;i<num_in;i++){
                p_din[i] :> data;
                i2s_i.receive(i*2+1, bitrev(data));
            }

            for(size_t i=0;i<num_out;i++)
                p_dout[i] <: bitrev(i2s_i.send(i*2+1));
        }


        for(size_t i=0;i<num_in;i++){
            p_din[i] :> data;
            i2s_i.receive(i*2, bitrev(data));
        }

        for(size_t i=0;i<num_in;i++){
            p_din[i] :> data;
            i2s_i.receive(i*2+1, bitrev(data));
        }
}
}
