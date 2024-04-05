// Copyright 2015-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>
#include <xclib.h>

#define IS_POWER_OF_2(x) ((x) && !((x) & ((x) - 1)))

#if MCLK_FAMILY == 48
    #define BASE_SAMPLE_RATE (6000)
    #define MAX_SAMPLE_RATE (192000)
#elif MCLK_FAMILY == 44
    #define BASE_SAMPLE_RATE (11025)
    #define MAX_SAMPLE_RATE (176400)
#else
    #error Set MCLK_FAMILY to either 48 or 44
#endif

#define MAX_RATIO (4)
#define MAX_CHANNELS (8)

#ifndef DATA_BITS
#define DATA_BITS (32)
#endif
#ifndef NUM_OUT
#define NUM_OUT (4)
#endif
#ifndef NUM_IN
#define NUM_IN (4)
#endif

in port p_mclk  = XS1_PORT_1A;
out port p_bclk = XS1_PORT_1B;
out buffered port:32 p_lrclk = XS1_PORT_1C;

#if NUM_IN
    in buffered port:32   ?p_din =  {XS1_PORT_4E};
#else
    in buffered port:32   ?p_din =  null;
#endif

#if NUM_OUT
    out buffered port:32  ?p_dout = {XS1_PORT_4F};
#else
    out buffered port:32  ?p_dout = null;
#endif

clock bclk = XS1_CLKBLK_2;

out port setup_strobe_port = XS1_PORT_1L;
out port setup_data_port = XS1_PORT_16A;
in port  setup_resp_port = XS1_PORT_1M;


#define NUM_MCLKS (1)
#if MCLK_FAMILY == 48
    static const unsigned mclk_freq[NUM_MCLKS] = {
        #if NUM_OUT > 1 || NUM_IN > 1
            12288000,
        #else
            24576000,
        #endif
    };
#elif MCLK_FAMILY == 44
    static const unsigned mclk_freq[NUM_MCLKS] = {
        #if NUM_OUT > 1 || NUM_IN > 1
            11289600,
        #else
            22579200,
        #endif
    };
#endif


unsigned current_sample_frequency = BASE_SAMPLE_RATE;
unsigned current_mclk_frequency;
unsigned mclk_count = NUM_MCLKS;
i2s_mode_t current_mode = I2S_MODE_I2S;

unsigned mclk_index = 0;
unsigned mclk_bclk_ratio;

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
        unsigned data)
{
    setup_data_port <: data;
    sync(setup_data_port);
    setup_strobe_port <: 1;
    setup_strobe_port <: 0;
    sync(setup_strobe_port);
}

static void broadcast(unsigned mclk_freq, unsigned mclk_bclk_ratio,
        unsigned num_in, unsigned num_out, int is_i2s_justified, unsigned data_bits){
    setup_strobe_port <: 0;
    send_data_to_tester(setup_strobe_port, setup_data_port, mclk_freq>>16);
    send_data_to_tester(setup_strobe_port, setup_data_port, mclk_freq);
    send_data_to_tester(setup_strobe_port, setup_data_port, mclk_bclk_ratio);
    send_data_to_tester(setup_strobe_port, setup_data_port, num_in);
    send_data_to_tester(setup_strobe_port, setup_data_port, num_out);
    send_data_to_tester(setup_strobe_port, setup_data_port, is_i2s_justified);
    send_data_to_tester(setup_strobe_port, setup_data_port, data_bits);
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


void set_mclk_and_ratio(unsigned sample_frequency)
{
    unsigned bclk_freq = 2 * sample_frequency * DATA_BITS;

    // If we're testing 1,2,4,8,16,32b data widths, then we can just use
    // the predesigned master clk frequencies
    // as there will be no error using an integer divider.
    // If we're testing anything else, we're better off providing an internal
    // clk and calculating the correct divider.
    if (IS_POWER_OF_2(DATA_BITS))
    {
        current_mclk_frequency = mclk_freq[mclk_index];
        mclk_bclk_ratio = current_mclk_frequency / bclk_freq;
    }
    else
    {
        unsigned numerator = bclk_freq / 1000;
        unsigned denominator = 1000;
        unsigned long long test_divisor;

        // Let's assume the use of a default core clk i.e. 500MHz.
        // This always gives better performance than the use of a 100MHz,
        // but may not be divisible in certain combinations - max clk divisor
        // is 255. In these instances, try other sensible lower clk speeds.
        // Unfortunately, the simulator doesn't seem to be able to go above 250.

        unsigned test_mclk_freqs[6] = {250000000, 100000000, 24576000,
                                            1228800, 6144000, 3072000};
        unsigned test_clk_idx = 0;

        do
        {
            test_divisor = ((unsigned long long) denominator * test_mclk_freqs[test_clk_idx])
                            / ((unsigned long long) numerator * (2 * 1000000));
            test_clk_idx += (test_divisor > 255 ? 1 : 0);

            if (test_clk_idx > 5)
            {
                printf("Unsupported sample rate and data bit depth combination!");
                _Exit(1);
            }
        } while (test_divisor > 255);

        if (test_divisor % 2 != 0)
        {
            test_divisor--;
        }

        mclk_bclk_ratio = 2 * test_divisor;

        // If we're here, then we don't want to iterate through multiple mclk
        // options - set the count to 1.
        current_mclk_frequency = test_mclk_freqs[test_clk_idx];
        mclk_count = 1;
        mclk_index = 0;
    }
}

[[distributable]]
#pragma unsafe arrays
void app(server interface i2s_frame_callback_if i2s_i)
{
    int error = 0;
    int first_time = 1;
    unsigned frames_sent = 0;
    unsigned rx_data_counter[MAX_CHANNELS] = {0};
    unsigned tx_data_counter[MAX_CHANNELS] = {0};

    while(1)
    {
        select
        {
            case i2s_i.send(size_t n, int32_t send_data[n]):
            {
                for (size_t c = 0; c < n; c++)
                {
                    unsigned i = tx_data_counter[c];
                    send_data[c] = tx_data[c][i];
                    tx_data_counter[c] = i + 1;
                }
                break;
            }
            case i2s_i.receive(size_t n, int32_t receive_data[n]):
            {
                for (size_t c = 0; c < n; c++)
                {
                    unsigned i = rx_data_counter[c];
                    // We shift here to pick up the case where the value we are
                    // testing with e.g. 401 cannot be represented in the given bit
                    // depth e.g. 8 bit
                    if ((receive_data[c] << (32-DATA_BITS)) != (rx_data[c][i] << (32-DATA_BITS)))
                    {
                        error |= 1;
                    }
                    rx_data_counter[c] = i + 1;
                }
                break;
            }
            case i2s_i.restart_check() -> i2s_restart_t restart:
            {
                frames_sent++;
                if (frames_sent == 4)
                    restart = I2S_RESTART;
                else
                    restart = I2S_NO_RESTART;
                break;
            }
            case i2s_i.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
            {
                if (!first_time)
                {
                    unsigned x = request_response(setup_strobe_port, setup_resp_port);
                    error |= x;
                    if (error)
                        printf("Error: No response from test harness, or data TX/RX mismatch!\nError = %d\n", error);

                    do {
                        if (mclk_index == mclk_count - 1)
                        {
                            current_mode = (current_mode == I2S_MODE_I2S ? I2S_MODE_LEFT_JUSTIFIED : I2S_MODE_I2S);
                            current_sample_frequency = (current_mode == I2S_MODE_I2S ? current_sample_frequency * 2 : current_sample_frequency);
                            mclk_index = 0;
                            if(current_sample_frequency > MAX_SAMPLE_RATE)
                            {
                                _Exit(0);
                            }
                        }
                        else
                        {
                            // For a given current_sample_frequency, go through all the mclks in mclk_freq array
                            mclk_index += 1;
                        }

                        set_mclk_and_ratio(current_sample_frequency);
                    }while((current_sample_frequency > MAX_SAMPLE_RATE || mclk_bclk_ratio == 1));
                }

                frames_sent = 0;
                error = 0;
                first_time = 0;

                i2s_config.mode = current_mode;
                i2s_config.mclk_bclk_ratio = mclk_bclk_ratio;

                for (unsigned i = 0; i < MAX_CHANNELS; i++){
                    tx_data_counter[i] = 0;
                    rx_data_counter[i] = 0;
                }
                broadcast(current_mclk_frequency, mclk_bclk_ratio, NUM_IN, NUM_OUT,
                        i2s_config.mode == I2S_MODE_I2S, DATA_BITS);

                break;
            }
        }
    }
}


void setup_bclk()
{
    set_mclk_and_ratio(current_sample_frequency);

    configure_clock_src_divide(bclk, p_mclk, (mclk_bclk_ratio / 2));

    broadcast(current_mclk_frequency, mclk_bclk_ratio, NUM_IN, NUM_OUT,
                current_mode == I2S_MODE_I2S, DATA_BITS);
}


int main()
{
    interface i2s_frame_callback_if i2s_i;
    par
    {
        {
            setup_bclk(); // For the very first iteration. For subsequent iterations, set in i2s_i.init()
            par {
                [[distribute]]
                app(i2s_i);
                i2s_frame_master_4b(i2s_i, p_dout, NUM_OUT, p_din, NUM_IN,
                        p_bclk, p_lrclk, p_mclk, bclk);
                par(int i=0;i<7;i++)while(1);
            }
        }
    }
    return 0;
}


