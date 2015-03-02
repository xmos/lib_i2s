#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>

in port p_bclk = XS1_PORT_1B;
in port p_lrclk = XS1_PORT_1C;

in buffered port:32 p_din [4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock bclk = XS1_CLKBLK_1;

out port setup_strobe_port = XS1_PORT_1L;
out port setup_data_port = XS1_PORT_16B;
in port  setup_resp_port = XS1_PORT_1M;

#define MAX_RATIO 3

#define MAX_CHANNELS 8
#define NUM_MCLKS 4

#define NUM_BCLKS 10

static const unsigned bclk_freq_lut[NUM_BCLKS] = {
        384000, 352800, 192000, 176400,
        96000, 88200, 48000, 44100, 24000, 22050
};

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

static void broadcast(unsigned bclk_freq,
        unsigned num_in, unsigned num_out, int is_i2s_justified){
    setup_strobe_port <: 0;
    send_data_to_tester(setup_strobe_port, setup_data_port, bclk_freq>>16);
    send_data_to_tester(setup_strobe_port, setup_data_port, bclk_freq);
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
void app(server interface i2s_slave_callback_if i2s_i){
    unsigned bclk_freq_index=0;
    unsigned frames_recieved = 0;
    unsigned rx_data_counter[MAX_CHANNELS] = {0};
    unsigned tx_data_counter[MAX_CHANNELS] = {0};
    int error=0;

    int first_time = 1;

    i2s_mode current_mode = I2S_MODE_I2S;
    while(1){
        select {
        case i2s_i.receive(size_t index, int32_t sample):{
            error |= (sample != rx_data[index][rx_data_counter[index]]);
            rx_data_counter[index]++;
            break;
        }
        case i2s_i.send(size_t index) -> int32_t r:{
            r = tx_data[index][tx_data_counter[index]];
            tx_data_counter[index]++;
            break;
        }
        case i2s_i.frame_start(unsigned timestamp, unsigned &restart):{
            frames_recieved++;
            restart = (frames_recieved == 4);
            break;
        }
        case i2s_i.init(i2s_mode & mode):{

            if(!first_time){
                 error |= request_response(setup_strobe_port, setup_resp_port);
            }
            if(error)
                printf("Error\n");
            frames_recieved = 0;
            mode = current_mode;

            broadcast(bclk_freq_lut[bclk_freq_index],
                    NUM_IN, NUM_OUT, mode == I2S_MODE_I2S);

            for(unsigned i=0;i<MAX_CHANNELS;i++){
                tx_data_counter[i] = 0;
                rx_data_counter[i] = 0;
            }

            if(bclk_freq_index == NUM_BCLKS-1){
                if (mode == I2S_MODE_I2S) {
                    current_mode = I2S_MODE_LEFT_JUSTIFIED;
                    bclk_freq_index = 0;
                } else {
                    _Exit(1);
                }
            } else {
                bclk_freq_index++;
            }

            error = 0;
            first_time = 0;
            break;
        }
        }
    }
}

int main(){
    interface i2s_slave_callback_if i2s_i;

    par {
      [[distribute]] app(i2s_i);
      i2s_slave(i2s_i, p_dout, NUM_OUT, p_din, NUM_IN,
                 p_bclk, p_lrclk, bclk);
      par(int i=0;i<7;i++)while(1);
    }
    return 0;
}

