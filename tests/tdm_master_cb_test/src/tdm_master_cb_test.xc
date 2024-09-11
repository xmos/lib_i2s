// Copyright 2015-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>
#include <print.h>

typedef struct {
    int offset;
    unsigned sclk_edge_count;
    unsigned channels_per_data_line;
    unsigned sample_rate;
} test_setup;

#if defined(SMOKE) 
#define TEST_COUNT (2)
#if NUM_OUT > 2 || NUM_IN > 2
test_setup tests[TEST_COUNT] = {
  {0 , 1,   4, 48000},
  {-1, 1,   4, 48000},
};
#else
test_setup tests[TEST_COUNT] = {
  {0 , 1,   8, 48000},
  {-1, 1,   8, 48000},
};
#endif
#else
#define TEST_COUNT (10)
test_setup tests[TEST_COUNT] = {
    {0 , 1,   2, 48000},
    {-1, 1,   2, 48000},
    {0 , 1,   4, 48000},
    {-1, 1,   4, 48000},
    //{0 , 1,   8, 48000},
   // {-1, 1,   8, 48000},

    {0 , 32,  2, 48000},
    {-1, 32,  2, 48000},
    {0 , 32,  4, 48000},
    {-1, 32,  4, 48000},
  //  {0 , 32,  8, 48000},
  //  {-1, 32,  8, 48000},

    {0 , 64,  4, 48000},
    {-1, 64,  4, 48000},
   // {0 , 128, 8, 48000},
   // {-1, 128, 8, 48000},
};
#endif
in port p_sclk  = XS1_PORT_1A;
out buffered port:32 p_fsync = XS1_PORT_1C;

in buffered port:32 p_din [4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock sclk = XS1_CLKBLK_1;

out port setup_strobe_port = XS1_PORT_1L;
out port setup_data_port = XS1_PORT_16A;
in port  setup_resp_port = XS1_PORT_1M;

#define MAX_CHANNELS (32)
#define NUM_SCLKS_TO_CHECK (3)
#define NUM_SCLKS (10)


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

static void broadcast(unsigned sample_rate,
        unsigned num_in, unsigned num_out, int is_i2s_justified,
        unsigned sclk_edge_count,
        unsigned channels_per_data_line
){
    setup_strobe_port <: 0;
    send_data_to_tester(setup_strobe_port, setup_data_port, sample_rate>>16);
    send_data_to_tester(setup_strobe_port, setup_data_port, sample_rate);
    send_data_to_tester(setup_strobe_port, setup_data_port, num_in);
    send_data_to_tester(setup_strobe_port, setup_data_port, num_out);
    send_data_to_tester(setup_strobe_port, setup_data_port, is_i2s_justified);
    send_data_to_tester(setup_strobe_port, setup_data_port, sclk_edge_count);
    send_data_to_tester(setup_strobe_port, setup_data_port, channels_per_data_line);
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
void app(server interface tdm_callback_if tdm_i){


    int error=0;
    unsigned y=0;
    unsigned x=0;
    unsigned frames_sent = 0;

    unsigned rx_data_counter[MAX_CHANNELS] = {0};
    unsigned tx_data_counter[MAX_CHANNELS] = {0};
    int first_time = 1;
    unsigned test_index = 0;

    while(1){
        select {
        case tdm_i.receive(size_t index, int32_t sample):{
            error |= (sample != y++);
            rx_data_counter[index]++;
            break;
        }
        case tdm_i.send(size_t index) -> int32_t r:{
            r=x++;
            tx_data_counter[index]++;
            break;
        }
        case tdm_i.restart_check() -> i2s_restart_t restart:{
            frames_sent++;
            if (frames_sent == 4)
              restart = I2S_RESTART;
            else
              restart = I2S_NO_RESTART;
            break;
        }

        case tdm_i.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):{
            if(!first_time){

                unsigned x=request_response(setup_strobe_port, setup_resp_port);
                error |= x;
                if(error)
                  printf("Error: test fail\n");
                test_index++;
                if(test_index == TEST_COUNT)
                    _Exit(1);
            }
            tdm_config.offset = tests[test_index].offset;
            tdm_config.sync_len = tests[test_index].sclk_edge_count;
            tdm_config.channels_per_frame = tests[test_index].channels_per_data_line;
            frames_sent = 0;
            broadcast(tests[test_index].sample_rate, NUM_IN, NUM_OUT,
                      tdm_config.offset ==-1,
                      tdm_config.sync_len,
                      tdm_config.channels_per_frame );
            first_time = 0;
            y=0;
            x=0;
            break;
        }
        }
    }
}

int main(){
    interface tdm_callback_if tdm_i;

    stop_clock(sclk);
    configure_clock_src(sclk, p_sclk);
    start_clock(sclk);

    par {
      [[distribute]] app(tdm_i);
      tdm_master(tdm_i, p_fsync, p_dout, NUM_OUT, p_din, NUM_IN, sclk);
      par(int i=0;i<7;i++) while(1);
    }
    return 0;
}


