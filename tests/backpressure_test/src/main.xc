// Copyright (c) 2016-2018, XMOS Ltd, All rights reserved
// This software is available under the terms provided in LICENSE.txt.
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include "i2s.h"
#include "xassert.h"
#include "debug_print.h"

#ifndef NUM_I2S_LINES
#define NUM_I2S_LINES   2
#endif
#ifndef BURN_THREADS
#define BURN_THREADS    6
#endif
#ifndef SAMPLE_FREQUENCY
#define SAMPLE_FREQUENCY 768000
#endif
#ifndef TEST_LEN
#define TEST_LEN 1000
#endif
#ifndef RECEIVE_DELAY_INCREMENT
#define RECEIVE_DELAY_INCREMENT 5
#endif
#ifndef SEND_DELAY_INCREMENT
#define SEND_DELAY_INCREMENT 5
#endif

#ifndef GENERATE_MCLK
#define GENERATE_MCLK 0
#endif

#if GENERATE_MCLK
#define MASTER_CLOCK_FREQUENCY 25000000
#else
#define MASTER_CLOCK_FREQUENCY 24576000
#endif

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
}

[[distributable]]
void i2s_loopback(server i2s_frame_callback_if i2s)
{
  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;
      break;

    case i2s.receive(size_t num_chan_in, int32_t sample[num_chan_in]):
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

#define OVERHEAD_TICKS 160 // Some of the period needs to be allowed for the interface handling
#define JITTER  1   //Allow for rounding so does not break when diff = period + 1
#define N_CYCLES_AT_DELAY   1 //How many LR clock cycles to measure at each backpressure delay value
#define DIFF_WRAP_16(new, old)  (new > old ? new - old : new + 0x10000 - old)
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
          if (counter == N_CYCLES_AT_DELAY) {
              *(p_receive_delay) += RECEIVE_DELAY_INCREMENT;
              *(p_send_delay) += SEND_DELAY_INCREMENT;
              if ((*p_receive_delay + *p_send_delay) > (period - OVERHEAD_TICKS)) {
                debug_printf("PASS\n");
                _Exit(0);
              }
              counter = 0;
          }
          p_lr_test when pinseq(1) :> void @ time;
          int diff = DIFF_WRAP_16(time, time_old);
          if (diff > (period + JITTER)) {
              debug_printf("Backpressure breaks at receive delay ticks=%d, send delay ticks=%d\n",
                *p_receive_delay, *p_send_delay);
              debug_printf("actual diff: %d, maximum (period + Jitter): %d\n",
                diff, (period + JITTER));
              _Exit(1);
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
#if GENERATE_MCLK
      // Generate a 25Mhz clock internally and drive p_mclk from that
      debug_printf("Using divided reference clock\n");

      configure_clock_ref(mclk, 2); // 100 / 2*2 = 25Mhz
      set_port_clock(p_mclk, mclk);
      set_port_mode_clock(p_mclk);
      start_clock(mclk);
#endif
      i2s_frame_master(i_i2s, p_dout, NUM_I2S_LINES, p_din, NUM_I2S_LINES, p_bclk, p_lrclk, p_mclk, bclk);
    }

    on tile[0]: [[distribute]] i2s_loopback(i_i2s);

    on tile[0]: test_lr_period();

    on tile[0]: par (int i=0; i<BURN_THREADS; i++) {burn();};
  }
  return 0;
}
