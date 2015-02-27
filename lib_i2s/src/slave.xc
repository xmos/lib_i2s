#include <xs1.h>
#include <xclib.h>
#include "i2s.h"
/*
static void init_ports(
        out buffered port:1 p_dout[num_out],
        size_t num_out,
        in buffered port:1 p_din[num_in],
        size_t num_in,
        in port p_bclk,
        in buffered port:1 p_lrclk,
        clock bclk){

    stop_clock(bclk);
    configure_clock_src(bclk, p_bclk);
    configure_out_port(p_lrclk, bclk, 1);
    for (size_t i = 0; i < num_out; i++)
        configure_out_port(p_dout[i], bclk, 0);
    for (size_t i = 0; i < num_in; i++)
        configure_in_port(p_din[i], bclk);
    start_clock(bclk);
}
*/



void i2s_slave(client i2s_slave_callback_if i,
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
        size_t num_in,
        in port p_bclk,
        in port p_lrclk,
        clock bclk){
/*
    unsigned prev_lr;
    p_lrclk :> prev_lr;

    unsigned rx[2][num_in];
    for(unsigned i=0;i<2;i++){
        for(size_t j =0;j<num_in;j++)
            rx[i][j] = 0;
    }
	while(1){
	    unsigned lr;
		p_lrclk :> lr;
        for(size_t i=0;i<num_in;i++)
            p_din[i] :>>> rx[lr][i];

		if(lr!=prev_lr){
		    //output rx[prev_lr] over the interface
		    //request tx[prev_lr] over the interface too
		}
        for(size_t i=0;i<num_out;i++)
            p_dout[i] <:>> tx[lr][i];
	}
    //init_ports(p_dout, num_out, p_din, num_in, p_bclk, p_lrclk, bclk);

    for(size_t i=0;i<num_out;i++)
        clearbuf(p_dout[i]);
    for(size_t i=0;i<num_in;i++)
        clearbuf(p_din[i]);

    clearbuf(p_lrclk);
    clearbuf(p_bclk);

    //we will assume 32 bit lr clock
    p_lrclk when pinseq(0):> int;
    unsigned time;
    timer t;
    t:> time;
    i2s_i.frame_start(time);
    while(1){
        //left
        for(size_t i=0;i<num_in;i++){
            p_din[i] :> data;
            i2s_i.receive(i, data);
        }

        for(size_t i=0;i<num_out;i++){
            p_dout[i] <: i2s_i.send(i);
        }
        //right
        for(size_t i=0;i<num_in;i++){
            p_din[i] :> data;
            i2s_i.receive(i, data);
        }

        t:> time;
        i2s_i.frame_start(time);

        for(size_t i=0;i<num_out;i++){
            p_dout[i] <: i2s_i.send(i);
        }
    }
*/

}
