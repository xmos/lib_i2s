#include <xs1.h>
#include <xclib.h>
#include "i2s.h"

static const unsigned clk_mask_lookup[5] = {
        0xaaaaaaaa, //div 2
        0xcccccccc, //div 4
        0xf0f0f0f0, //div 8
        0xff00ff00, //div 16
        0xffff0000, //div 32
};

static void init_ports(
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

#pragma unsafe arrays
static void ratio_2(client i2s_callback_if i2s_i,
        out buffered port:32 p_dout[num_out],
        static const size_t num_out,
        in buffered port:32 p_din[num_in],
        static const size_t num_in,
        out buffered port:32 p_bclk,
        out buffered port:32 p_lrclk,
        i2s_mode mode){
    const unsigned clk_mask = clk_mask_lookup[0];
    unsigned lr_mask = 0;
    unsigned restart = 0;
    unsigned time;
    timer t;
    int32_t data;

    for(size_t i=0;i<num_out;i++)
        clearbuf(p_dout[i]);
    for(size_t i=0;i<num_in;i++)
        clearbuf(p_din[i]);
    clearbuf(p_lrclk);
    clearbuf(p_bclk);

    if(mode == I2S_MODE_I2S){
        for(size_t i=0;i<num_out;i++)
            p_dout[i] @ 2 <: bitrev(i2s_i.send(i*2));
        partout(p_lrclk, 1, 0);
        for(size_t i=0;i<num_in;i++)
          asm volatile("setpt res[%0], %1"::"r"(p_din[i]), "r"(32+1):"memory");
        lr_mask = 0x80000000;
        partout(p_bclk, 2, 0x2);
     } else {
       for(size_t i=0;i<num_out;i++)
           p_dout[i] <: bitrev(i2s_i.send(i*2));
     }
    p_lrclk <: lr_mask;
    p_bclk <: clk_mask;
    p_bclk <: clk_mask;
    t:> time;
    lr_mask = ~lr_mask;
    p_lrclk <: lr_mask;
    for(size_t i=0;i<num_out;i++)
        p_dout[i] <: bitrev(i2s_i.send(i*2+1));
    p_bclk <: clk_mask;
    p_bclk <: clk_mask;

    while (!restart) {
        t:> time;
        i2s_i.frame_start(time, restart);
        lr_mask = ~lr_mask;
        p_lrclk <: lr_mask;
        for(size_t i=0;i<num_in;i++){
            asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
            i2s_i.receive(i*2, bitrev(data));
        }
        for(size_t i=0;i<num_out;i++)
            p_dout[i] <: bitrev(i2s_i.send(i*2));
        p_bclk <: clk_mask;
        p_bclk <: clk_mask;
        t:> time;
        lr_mask = ~lr_mask;
        p_lrclk <: lr_mask;
        for(size_t i=0;i<num_in;i++){
            asm volatile("in %0, res[%1]":"=r"(data):"r"(p_din[i]):"memory");
            i2s_i.receive(i*2+1, bitrev(data));
        }
        for(size_t i=0;i<num_out;i++)
            p_dout[i] <: bitrev(i2s_i.send(i*2+1));
        p_bclk <: clk_mask;
        p_bclk <: clk_mask;
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

#pragma unsafe arrays
static void ratio_n(client i2s_callback_if i2s_i,
        out buffered port:32 p_dout[num_out],
        static const size_t num_out,
        in buffered port:32 p_din[num_in],
        static const size_t num_in,
        out buffered port:32 p_bclk,
        out buffered port:32 p_lrclk,
        unsigned ratio,
        i2s_mode mode){
    unsigned clk_mask = clk_mask_lookup[ratio-1];
    unsigned lr_mask = 0;
    unsigned restart = 0;
    unsigned time;
    timer t;
    int32_t data;

    for(size_t i=0;i<num_out;i++)
        clearbuf(p_dout[i]);
    for(size_t i=0;i<num_in;i++)
        clearbuf(p_din[i]);
    clearbuf(p_lrclk);
    clearbuf(p_bclk);

    unsigned total_clk_pairs = (1<<(ratio-1));
    unsigned calls_per_pair = ((num_in + num_out) + (1<<(ratio-1))-1)>>(ratio-1);

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

    p_lrclk <: lr_mask;
    p_bclk <: clk_mask;
    p_bclk <: clk_mask;
    t:> time;
    lr_mask = ~lr_mask;
    {
        p_lrclk <: lr_mask;
        unsigned if_call_num = 0;
        for(unsigned clk_pair=0; clk_pair < total_clk_pairs;clk_pair++){
            for(unsigned i=0;i<calls_per_pair;i++){
                if(if_call_num < num_out)
                    p_dout[if_call_num] <: bitrev(i2s_i.send(if_call_num*2+1));
                if_call_num++;
            }
            p_bclk <: clk_mask;
            p_bclk <: clk_mask;
        }
    }

    while(!(restart && (lr_mask&0xf))){
        t:> time;
        int lr = (lr_mask&0xf) ? 0 : 1;
        if(!lr)
           i2s_i.frame_start(time, restart);
        lr_mask = ~lr_mask;
        p_lrclk <: lr_mask;
        unsigned if_call_num = 0;
        for(unsigned clk_pair=0; clk_pair < total_clk_pairs;clk_pair++){
            for(unsigned i=0;i<calls_per_pair;i++){
                if(if_call_num < num_in){
                    p_din[if_call_num] :> data;
                    i2s_i.receive(if_call_num*2+lr, bitrev(data));
                } else if(if_call_num < num_in + num_out){
                    unsigned index = if_call_num - num_in;
                    p_dout[index] <: bitrev(i2s_i.send(index*2+lr));
                }
                if_call_num++;
            }
            p_bclk <: clk_mask;
            p_bclk <: clk_mask;
        }
    }
    //tail
    {
        unsigned if_call_num = 0;

        for(unsigned clk_pair=0; clk_pair < total_clk_pairs;clk_pair++){
            for(unsigned i=0;i<calls_per_pair;i++){
                if(if_call_num < num_in){
                    p_din[if_call_num] :> data;
                    i2s_i.receive(if_call_num*2, bitrev(data));
                }
                if_call_num++;
            }
            if(clk_pair < total_clk_pairs-1){
                p_bclk <: clk_mask;
                p_bclk <: clk_mask;
            }
        }
        for(size_t i=0;i<num_in;i++){
            p_din[i] :> data;
            i2s_i.receive(i*2+1, bitrev(data));
        }
    }
}

unsigned log2(unsigned x){
  return clz(bitrev(x));
}

void i2s_master(client i2s_callback_if i2s_i,
                out buffered port:32 p_dout[num_out],
                static const size_t num_out,
                in buffered port:32 p_din[num_in],
                static const size_t num_in,
                out buffered port:32 p_bclk,
                out buffered port:32 p_lrclk,
                clock bclk,
                const clock mclk){

    while(1){

        //This ensures that the port time on all the ports is at 0
        init_ports(p_dout, num_out, p_din, num_in,
           p_bclk, p_lrclk, bclk, mclk);

        unsigned mclk_bclk_ratio, mclk_bclk_ratio_log2;
        i2s_mode mode;
        i2s_i.init(mclk_bclk_ratio, mode);

        mclk_bclk_ratio_log2 = log2(mclk_bclk_ratio);

        if(mclk_bclk_ratio_log2 == 1){
            ratio_2(i2s_i, p_dout, num_out, p_din,
                num_in, p_bclk, p_lrclk, mode);
        } else {
            ratio_n(i2s_i, p_dout, num_out, p_din,
                num_in, p_bclk, p_lrclk, mclk_bclk_ratio_log2, mode);
        }
    }
}
