// Copyright (c) 2015-2016, XMOS Ltd, All rights reserved
// This software is available under the terms provided in LICENSE.txt.
#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>

in port p_mclk  = XS1_PORT_1A;
out buffered port:32 p_bclk = XS1_PORT_1B;
out buffered port:32 p_lrclk = XS1_PORT_1C;

in buffered port:32 p_din [4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;

out port setup_strobe_port = XS1_PORT_1L;
out port setup_data_port = XS1_PORT_16A;
in port  setup_resp_port = XS1_PORT_1M;

#define MAX_RATIO 4

#define MAX_CHANNELS 8




#if defined(SMOKE)
#if NUM_OUT > 1 || NUM_IN > 1
#define NUM_MCLKS 1
static const unsigned mclock_freq[NUM_MCLKS] = {
        12288000,
};
#else
#define NUM_MCLKS 1
static const unsigned mclock_freq[NUM_MCLKS] = {
        24576000,
};
#endif
#else
#if NUM_OUT > 1 || NUM_IN > 1
#define NUM_MCLKS 2
static const unsigned mclock_freq[NUM_MCLKS] = {
        12288000,
        11289600,
};
#else
#define NUM_MCLKS 4
static const unsigned mclock_freq[NUM_MCLKS] = {
        24576000,
        22579200,
        12288000,
        11289600,
};
#endif
#endif

int32_t tx_data[MAX_CHANNELS][8] = {
        {  1,   2,   3,   4,   5,   6,   7,   8},
        {101, 102, 103, 104, 105, 106, 107, 108},
        {201, 202, 203, 204, 205, 206, 207, 208},
        {301, 302, 303, 304, 305, 306, 307, 308},
        {401, 402, 403, 404, 405, 406, 407, 408},
        {501, 502, 503, 504, 505, 506, 507, 508},
        {601, 602, 603, 604, 605, 606, 607, 608},
        {701, 702, 703, 704, 705, 706, 707, 708}};

int32_t rx_data[MAX_CHANNELS][8] = {
        {  1,   2,   3,   4,   5,   6,   7,   8},
        {101, 102, 103, 104, 105, 106, 107, 108},
        {201, 202, 203, 204, 205, 206, 207, 208},
        {301, 302, 303, 304, 305, 306, 307, 308},
        {401, 402, 403, 404, 405, 406, 407, 408},
        {501, 502, 503, 504, 505, 506, 507, 508},
        {601, 602, 603, 604, 605, 606, 607, 608},
        {701, 702, 703, 704, 705, 706, 707, 708}};


static void send_data_to_tester(
        out port setup_strobe_port,
        out port setup_data_port,
        unsigned data){
    setup_data_port <: data;
    sync(setup_data_port);
    setup_strobe_port <: 1;
    setup_strobe_port <: 0;
    sync(setup_strobe_port);
}

static void broadcast(unsigned mclk_freq, unsigned mclk_bclk_ratio,
        unsigned num_in, unsigned num_out, int is_i2s_justified){
    setup_strobe_port <: 0;
    send_data_to_tester(setup_strobe_port, setup_data_port, mclk_freq>>16);
    send_data_to_tester(setup_strobe_port, setup_data_port, mclk_freq);
    send_data_to_tester(setup_strobe_port, setup_data_port, mclk_bclk_ratio);
    send_data_to_tester(setup_strobe_port, setup_data_port, num_in);
    send_data_to_tester(setup_strobe_port, setup_data_port, num_out);
    send_data_to_tester(setup_strobe_port, setup_data_port, is_i2s_justified);
 }

static int request_response(
        out port setup_strobe_port,
        in port setup_resp_port){
    int r=0;
    while(!r)
        setup_resp_port :> r;
    setup_strobe_port <: 1;
    setup_strobe_port <: 0;
    setup_resp_port :> r;
    return r;
}
[[distributable]]
#pragma unsafe arrays
void app(server interface i2s_callback_if i2s_i){

    int error=0;
    unsigned frames_sent = 0;
    unsigned rx_data_counter[MAX_CHANNELS] = {0};
    unsigned tx_data_counter[MAX_CHANNELS] = {0};

    int first_time = 1;
    unsigned mclock_freq_index=0;
    unsigned ratio_log2 = 1;
    i2s_mode_t current_mode = I2S_MODE_I2S;

    while(1){
        select {
        case i2s_i.send(size_t index) -> int32_t r:{
            r = tx_data[index][tx_data_counter[index]];
            tx_data_counter[index]++;
            break;
        }
        case i2s_i.receive(size_t index, int32_t sample):{
            unsigned i = rx_data_counter[index];
            error |= (sample != rx_data[index][i]);
            rx_data_counter[index]=i+1;
            break;
        }
        case i2s_i.restart_check() -> i2s_restart_t restart:{
            frames_sent++;
            if (frames_sent == 4)
              restart = I2S_RESTART;
            else
              restart = I2S_NO_RESTART;
            break;
        }
        case i2s_i.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):{
            if(!first_time){
                 unsigned x=request_response(setup_strobe_port, setup_resp_port);
                 error |= x;
                 if(error)
                   printf("Error: test fail\n");

                 int s = 0;
                 while(!s){
                     if (ratio_log2 == MAX_RATIO){
                         ratio_log2 = 1;
                        if(mclock_freq_index == NUM_MCLKS-1){
                            mclock_freq_index = 0;
                            if (current_mode == I2S_MODE_I2S) {
                                current_mode = I2S_MODE_LEFT_JUSTIFIED;
                            } else {
                                _Exit(1);
                            }
                        } else {
                            mclock_freq_index++;
                        }
                    } else {
                        ratio_log2++;
                    }
                    if(mclock_freq[mclock_freq_index] / ((1<<ratio_log2)*64) <=48000)
                        s=1;
                }
            }

            i2s_config.mclk_bclk_ratio = (1<<ratio_log2);

            frames_sent = 0;
            error = 0;
            first_time = 0;

            i2s_config.mode = current_mode;

            for(unsigned i=0;i<MAX_CHANNELS;i++){
                tx_data_counter[i] = 0;
                rx_data_counter[i] = 0;
            }
            broadcast(mclock_freq[mclock_freq_index],
                      i2s_config.mclk_bclk_ratio, NUM_IN, NUM_OUT,
                      i2s_config.mode == I2S_MODE_I2S);

            break;
        }
        }
    }
}

int main(){
    interface i2s_callback_if i2s_i;

    stop_clock(mclk);
    configure_clock_src(mclk, p_mclk);
    start_clock(mclk);

    par {
        [[distribute]]
         app(i2s_i);
      i2s_master(i2s_i, p_dout, NUM_OUT, p_din, NUM_IN,
                 p_bclk, p_lrclk, bclk, mclk);
      par(int i=0;i<7;i++)while(1);
    }
    return 0;
}


