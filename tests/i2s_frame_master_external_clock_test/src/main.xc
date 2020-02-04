// Copyright (c) 2015-2020, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>

in port p_mclk  = XS1_PORT_1A;
out port p_bclk = XS1_PORT_1B;
out buffered port:32 p_lrclk = XS1_PORT_1C;

in buffered port:32 p_din [4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock bclk = XS1_CLKBLK_2;

out port setup_strobe_port = XS1_PORT_1L;
out port setup_data_port = XS1_PORT_16A;
in port  setup_resp_port = XS1_PORT_1M;

#define MAX_RATIO 4

#define MAX_CHANNELS 8

#define MAX_NUM_RESTARTS (4)




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
unsigned mclock_freq_index;
unsigned ratio_log2;
uint32_t mclk_bclk_ratio;
i2s_mode_t current_mode;
[[distributable]]
#pragma unsafe arrays
void app(server interface i2s_frame_callback_if i2s_i){

    int error=0;
    unsigned frames_sent = 0;
    unsigned rx_data_counter[MAX_CHANNELS] = {0};
    unsigned tx_data_counter[MAX_CHANNELS] = {0};

    int first_time = 1;
    uint32_t num_restarts = 0;

    while(1){
        select {
        case i2s_i.send(size_t n, int32_t send_data[n]):{
            for(size_t c=0; c<n; c++){
                unsigned i = tx_data_counter[c];
                send_data[c] = tx_data[c][i];
                tx_data_counter[c] = i+1;
            }
            break;
        }
        case i2s_i.receive(size_t n, int32_t receive_data[n]):{
            for(size_t c=0; c<n; c++){
                unsigned i = rx_data_counter[c];
                error |= (receive_data[c] != rx_data[c][i]);
                rx_data_counter[c] = i+1;
            }
            break;
        }
        case i2s_i.restart_check() -> i2s_restart_t restart:{
            frames_sent++;
            if (frames_sent == 4)
            {
              restart = I2S_RESTART;
              num_restarts += 1;
            }
            else
              restart = I2S_NO_RESTART;
            break;
        }
        case i2s_i.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):{
            //bclock frequency is not changed in restart when using i2s_frame_master_external_clock.
            //The clock needs to be set externally once, before starting i2s_frame_master_external_clock.

            if(!first_time) 
            {
                 unsigned x=request_response(setup_strobe_port, setup_resp_port);
                 error |= x;
                 if(error)
                   printf("Error: test fail\n");
                 if (current_mode == I2S_MODE_I2S) {
                     current_mode = I2S_MODE_LEFT_JUSTIFIED;
                 }
                 else
                 {
                    current_mode = I2S_MODE_I2S;
                 }
                if(num_restarts >= MAX_NUM_RESTARTS)
                {
                    _Exit(1);
                }
            }

            frames_sent = 0;
            error = 0;
            first_time = 0;

            i2s_config.mode = current_mode;

            for(unsigned i=0;i<MAX_CHANNELS;i++){
                tx_data_counter[i] = 0;
                rx_data_counter[i] = 0;
            }
            broadcast(mclock_freq[mclock_freq_index],
                      mclk_bclk_ratio, NUM_IN, NUM_OUT,
                      i2s_config.mode == I2S_MODE_I2S);

            break;
        }
        }
    }
}


void setup_bclock()
{
    mclock_freq_index=0;
    ratio_log2 = 1;
    mclk_bclk_ratio = (1<<ratio_log2);
    current_mode = I2S_MODE_I2S;

    broadcast(mclock_freq[mclock_freq_index],
            mclk_bclk_ratio, NUM_IN, NUM_OUT,
            current_mode == I2S_MODE_I2S);
    
    configure_clock_src_divide(bclk, p_mclk, mclk_bclk_ratio >> 1);
}


int main(){
    interface i2s_frame_callback_if i2s_i;
    
    par {
    {
        setup_bclock();
        par {
            [[distribute]]
                app(i2s_i);
            i2s_frame_master_external_clock(i2s_i, p_dout, NUM_OUT, p_din, NUM_IN,
                    p_bclk, p_lrclk, bclk);
            par(int i=0;i<7;i++)while(1);
        }
    }
    }
    return 0;
}


