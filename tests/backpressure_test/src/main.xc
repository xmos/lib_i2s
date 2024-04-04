// Copyright 2016-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include "i2s.h"
#include "xassert.h"
#include "debug_print.h"

#ifndef NUM_I2S_LINES
#define NUM_I2S_LINES   (2)
#endif
#ifndef BURN_THREADS
#define BURN_THREADS    (6)
#endif
#ifndef SAMPLE_FREQUENCY
#define SAMPLE_FREQUENCY (768000)
#endif
#ifndef TEST_LEN
#define TEST_LEN (1000)
#endif
#ifndef RECEIVE_DELAY_INCREMENT
#define RECEIVE_DELAY_INCREMENT (5)
#endif
#ifndef SEND_DELAY_INCREMENT
#define SEND_DELAY_INCREMENT (5)
#endif
#ifndef GENERATE_MCLK
#define GENERATE_MCLK (0)
#endif
#ifndef DATA_BITS
#define DATA_BITS (32)
#endif

#if GENERATE_MCLK
#define MASTER_CLOCK_FREQUENCY (25000000)
#else
#define MASTER_CLOCK_FREQUENCY (24576000)
#endif

enum {
    SAMPLE_RATE_192000,
    SAMPLE_RATE_384000,
    NUM_SAMPLE_RATES
}e_sample_rates;

enum {
    BITDEPTH_8,
    BITDEPTH_16,
    BITDEPTH_32,
    NUM_BIT_DEPTHS
}e_bit_depth;

enum {
    NUM_I2S_LINES_1,
    NUM_I2S_LINES_2,
    NUM_I2S_LINES_3,
    NUM_I2S_LINES_4,
}e_channel_config;

static int acceptable_receive_delay = 0, acceptable_send_delay = 0;
static int acceptable_delay_ticks[NUM_SAMPLE_RATES][NUM_I2S_LINES_4+1][NUM_BIT_DEPTHS];

static inline void populate_acceptable_delay_ticks()
{
    // These numbers are logged by running the test and logging the delay at the last passing iteration
    // before the backpressure test starts failing. So, on top of the bare minimum code in the i2s_send()
    // and i2s_receive() functions in this file plus their calling overheads, we have acceptable_delay_ticks number
    // of cycles per send and receive callback function call to add any extra processing.

    // 192 KHz
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_1][BITDEPTH_8] = 185;
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_1][BITDEPTH_16] = 190;
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_1][BITDEPTH_32] = 200;

    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_2][BITDEPTH_8] = 155;
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_2][BITDEPTH_16] = 165;
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_2][BITDEPTH_32] = 180;

    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_3][BITDEPTH_8] = 125;
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_3][BITDEPTH_16] = 135;
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_3][BITDEPTH_32] = 160;

    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_4][BITDEPTH_8] = 100;
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_4][BITDEPTH_16] = 100;
    acceptable_delay_ticks[SAMPLE_RATE_192000][NUM_I2S_LINES_4][BITDEPTH_32] = 125;

    // 384 KHz
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_1][BITDEPTH_8] = 65;
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_1][BITDEPTH_16] = 70;
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_1][BITDEPTH_32] = 75;

    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_2][BITDEPTH_8] = 35;
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_2][BITDEPTH_16] = 40;
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_2][BITDEPTH_32] = 50;

    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_3][BITDEPTH_8] = 5;
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_3][BITDEPTH_16] = 5;
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_3][BITDEPTH_32] = 25;

    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_4][BITDEPTH_8] = 0;
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_4][BITDEPTH_16] = 0;
    acceptable_delay_ticks[SAMPLE_RATE_384000][NUM_I2S_LINES_4][BITDEPTH_32] = 5;
}

void get_acceptable_delay()
{
    int sample_rate;
    if(SAMPLE_FREQUENCY == 192000)
    {
        sample_rate = SAMPLE_RATE_192000;
    }
    else if(SAMPLE_FREQUENCY == 384000)
    {
        sample_rate = SAMPLE_RATE_384000;
    }
    else
    {
        debug_printf("ERROR: Invalid sample rate %d\n", SAMPLE_FREQUENCY);
        _Exit(1);
    }

    int bit_depth;
    if(DATA_BITS == 8)
    {
        bit_depth = BITDEPTH_8;
    }
    else if(DATA_BITS == 16)
    {
        bit_depth = BITDEPTH_16;
    }
    else if(DATA_BITS == 32)
    {
        bit_depth = BITDEPTH_32;
    }
    else
    {
        debug_printf("ERROR: Invalid bit_depth %d\n", DATA_BITS);
        _Exit(1);
    }
    if((NUM_I2S_LINES < 1) || (NUM_I2S_LINES > 4))
    {
        debug_printf("ERROR: Invalid NUM_I2S_LINES %d\n", NUM_I2S_LINES);
        _Exit(1);
    }
    int delay = acceptable_delay_ticks[sample_rate][NUM_I2S_LINES-1][bit_depth];

    if(delay <= 0)
    {
        debug_printf("ERROR: Invalid delay %d. Check if testing an unsupported configuration\n", delay);
        _Exit(1);
    }

    // get the send and receive delay based on the
    if((RECEIVE_DELAY_INCREMENT == 5) && (SEND_DELAY_INCREMENT == 5))
    {
        // Backpressure passes at delay, so add another increment number of ticks to get to the first fail instance
        acceptable_receive_delay = delay + 5;
        acceptable_send_delay = delay + 5;
    }
    else if((RECEIVE_DELAY_INCREMENT == 0) && (SEND_DELAY_INCREMENT == 10))
    {
        // Backpressure passes at 2*delay, so add another increment number of ticks to get to the first fail instance
        acceptable_receive_delay = 0;
        acceptable_send_delay = 2*delay + 10;
    }
    else if((RECEIVE_DELAY_INCREMENT == 10) && (SEND_DELAY_INCREMENT == 0))
    {
        // Backpressure passes at 2*delay, so add another increment number of ticks to get to the first fail instance
        acceptable_receive_delay = 2*delay + 10;
        acceptable_send_delay = 0;
    }
    else
    {
        debug_printf("ERROR: Unsupported receive (%d) and send (%d) delay increment combination\n", RECEIVE_DELAY_INCREMENT, SEND_DELAY_INCREMENT);
        _Exit(1);
    }
}

/* Ports and clocks used by the application */
on tile[0]: out buffered port:32 p_lrclk = XS1_PORT_1G;
on tile[0]: out port p_bclk = XS1_PORT_1H;
on tile[0]: in port p_mclk = XS1_PORT_1F;
on tile[0]: out buffered port:32 p_dout[4] = {XS1_PORT_1M, XS1_PORT_1N, XS1_PORT_1O, XS1_PORT_1P};
on tile[0]: in buffered port:32 p_din[4] = {XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K, XS1_PORT_1L};

on tile[0]: clock mclk = XS1_CLKBLK_1;
on tile[0]: clock bclk = XS1_CLKBLK_2;

int receive_delay = 0;
int send_delay = 0;

unsafe{
    int * unsafe p_receive_delay= &receive_delay;
    int * unsafe p_send_delay = &send_delay;
    static int32_t receive_data_store[8];
}

[[distributable]]
void i2s_loopback(server i2s_frame_callback_if i2s)
{
  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/(SAMPLE_FREQUENCY*2*DATA_BITS));
      break;

    case i2s.receive(size_t num_chan_in, int32_t sample[num_chan_in]):
      for (size_t i = 0; i < num_chan_in; i++) {
        receive_data_store[i] = sample[i];
      }

      if (receive_delay) {
        delay_ticks(receive_delay);
      }
      break;

    case i2s.send(size_t num_chan_out, int32_t sample[num_chan_out]):
      for (size_t i = 0; i < num_chan_out; i++) {
        sample[i] = i;
      }
      if (send_delay) {
        delay_ticks(send_delay);
      }
      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;
    }
  }
}

#define JITTER (1)   //Allow for rounding so does not break when diff = period + 1
#define N_CYCLES_AT_DELAY (1) //How many LR clock cycles to measure at each backpressure delay value
#define DIFF_WRAP_16(new, old) ((new) > (old) ? (new) - (old) : (new) + 0x10000 - (old))
on tile[0]: port p_lr_test = XS1_PORT_1A;
void test_lr_period(void){
    unsafe {
      const int ref_tick_per_sample = XS1_TIMER_HZ/SAMPLE_FREQUENCY;
      const int period = ref_tick_per_sample;

      set_core_fast_mode_on();

      int time;

      // Synchronise with LR clock
      p_lr_test when pinseq(1) :> void;
      p_lr_test when pinseq(0) :> void;
      p_lr_test when pinseq(1) :> void;
      p_lr_test when pinseq(0) :> void;
      p_lr_test when pinseq(1) :> void @ time;

      int time_old = time;
      int counter = 0; // Do a number cycles at each delay value
      while (1) {
          p_lr_test when pinseq(0) :> void;
          counter++;

          p_lr_test when pinseq(1) :> void @ time;
          int diff = DIFF_WRAP_16(time, time_old);

          if (diff > (period + JITTER)) {
            if(receive_delay < acceptable_receive_delay)
            {
                printf("Backpressure breaks at receive delay ticks = %d, acceptable receive delay = %d\n",
                    receive_delay, acceptable_receive_delay);
                printf("actual diff: %d, maximum (period + Jitter): %d\n", diff, (period + JITTER));
                _Exit(1);
            }

            // The delay we're able to add in the i2s_send() function should be acceptable_send_delay ticks or more
            if(send_delay < acceptable_send_delay)
            {
                printf("Backpressure breaks at send delay ticks = %d, acceptable send delay = %d\n",
                    send_delay, acceptable_send_delay);
                printf("actual diff: %d, maximum (period + Jitter): %d\n", diff, (period + JITTER));
                _Exit(1);
            }
            printf("PASS\n");
            _Exit(0);
          }

          if (counter == N_CYCLES_AT_DELAY) {
              *(p_receive_delay) += RECEIVE_DELAY_INCREMENT;
              *(p_send_delay) += SEND_DELAY_INCREMENT;
              counter = 0;
          }
          time_old = time;
      }
    }
}

void burn(void){
    set_core_fast_mode_on();
    while(1);
}

int main()
{
  interface i2s_frame_callback_if i_i2s;

  par {
    on tile[0]: {
      populate_acceptable_delay_ticks();
      get_acceptable_delay();
#if GENERATE_MCLK
      // Generate a 25Mhz clock internally and drive p_mclk from that
      debug_printf("Using divided reference clock\n");

      configure_clock_ref(mclk, 2); // 100 / 2*2 = 25Mhz
      set_port_clock(p_mclk, mclk);
      set_port_mode_clock(p_mclk);
      start_clock(mclk);
#endif
      par {
        i2s_frame_master(i_i2s, p_dout, NUM_I2S_LINES, p_din, NUM_I2S_LINES, DATA_BITS, p_bclk, p_lrclk, p_mclk, bclk);
        [[distribute]] i2s_loopback(i_i2s);
        test_lr_period();
        par (int i=0; i<BURN_THREADS; i++) {burn();};
      }
    }
  }
  return 0;
}
