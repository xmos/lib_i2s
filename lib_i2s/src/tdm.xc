#include <i2s.h>
#include <xs1.h>
#include <xclib.h>
#include <print.h>
#include "tdm_common.h"

[[distributable]]
#pragma unsafe arrays
void tdm_master(server interface tdm_if tdm_i,
        out buffered port:32 p_fsync,
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
        size_t num_in,
        size_t samples_per_frame,
        int offset,
        unsigned sclk_edge_count) {
    unsigned rx_counter  = 0;
    unsigned tx_counter  = 0;
    unsigned fsync_index = 0;

    unsigned fsync_mask[16] = {0};

    unsigned tdm_slots_per_frame  = samples_per_frame / num_out;

    make_fsync_mask(fsync_mask, offset, sclk_edge_count, samples_per_frame);

    while (1) {
        select {

        case tdm_i.configure(clock clk):
            set_clock_on(clk);
            stop_clock(clk);
            configure_out_port_no_ready(p_fsync, clk, 0);

            for (size_t i = 0; i < num_out; i++){
                configure_out_port_no_ready(p_dout[i], clk, 0);
                clearbuf(p_dout[i]);
            }
            for (size_t i = 0; i < num_in; i++)
                configure_in_port_no_ready(p_din[i], clk);

            clearbuf(p_fsync);

            if(offset < 0){
                partout(p_fsync, -offset, bitrev(fsync_mask[tdm_slots_per_frame-1]));
                for(size_t i=0;i<num_in;i++)
                    asm("setpt res[%0], %1"::"r"(p_din[i]), "r"(32-1 - offset));
                for(size_t i=0;i<num_out;i++)
                    p_dout[i] @ - offset <: 0;
                p_fsync @ - offset <: 0;

            } else {
                for(size_t i=0;i<num_in;i++)
                    asm("setpt res[%0], %1"::"r"(p_din[i]), "r"(32-1));

                //asm("setpt res[%0], %1"::"r"(p_dout[0]), "r"(8));
                //asm("setpt res[%0], %1"::"r"(p_fsync), "r"(8));
                for(size_t i=0;i<num_out;i++)
                    p_dout[i]<: 0;
                p_fsync<: 0;
            }

            break;
        case tdm_i.start():{
            break;
        }
        case tdm_i.receive()-> int32_t r:{
            if (num_in == 1) {
                p_din[0] :> r;
            } else {
                p_din[rx_counter]:> r;
                rx_counter++;
                if(rx_counter >= num_in)
                    rx_counter = 0;
            }
            break;
        }
        case tdm_i.send(int32_t sample):{
            if (num_out == 1) {
                p_fsync <: fsync_mask[fsync_index];
                p_dout[0] <: sample;
                fsync_index++;
                if(fsync_index >= tdm_slots_per_frame)
                    fsync_index = 0;
            } else{
                p_dout[tx_counter] <: sample;
                if(tx_counter == 0){
                    p_fsync <: fsync_mask[fsync_index];
                    fsync_index++;
                    if(fsync_index >= tdm_slots_per_frame)
                        fsync_index = 0;
                }
                tx_counter++;
                if(tx_counter >= num_out)
                    tx_counter = 0;
            }

            break;
        }
    }
    }
}
