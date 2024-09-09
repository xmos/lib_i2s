// Copyright 2014-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <xs1.h>
#include "i2s.h"
#include "i2c.h"
#include "xassert.h"
#include <stdlib.h>
#include <debug_print.h>
#include <string.h>
#include "xk_audio_316_mc_ab/board.h"


#define SAMPLE_FREQUENCY        192000
#define MASTER_CLOCK_FREQUENCY  24576000
#define DATA_BITS               32
#define CHANS_PER_FRAME         2
#define NUM_I2S_LINES           4

// I2S resources
on tile[1]: in port p_mclk =                                PORT_MCLK_IN;
on tile[1]: buffered in port:32 p_lrclk =                   PORT_I2S_LRCLK;
on tile[1]: in port p_bclk =                                PORT_I2S_BCLK;
on tile[1]: buffered out port:32 p_dac[NUM_I2S_LINES] =     {PORT_I2S_DAC0, PORT_I2S_DAC1, PORT_I2S_DAC2, PORT_I2S_DAC3};
on tile[1]: buffered in port:32 p_adc[NUM_I2S_LINES] =      {PORT_I2S_ADC0 ,PORT_I2S_ADC1, PORT_I2S_ADC2, PORT_I2S_ADC3};
on tile[1]: clock clk_bclk =                                XS1_CLKBLK_1;

// Board configuration from lib_board_support
static const xk_audio_316_mc_ab_config_t hw_config = {
        CLK_FIXED,              // clk_mode. Drive a fixed MCLK output
        1,                      // 1 = dac_is_clock_master
        MASTER_CLOCK_FREQUENCY,
        0,                      // pll_sync_freq (unused when driving fixed clock)
        AUD_316_PCM_FORMAT_I2S,
        DATA_BITS,
        CHANS_PER_FRAME
};


[[distributable]]
#pragma unsafe arrays
void i2s_handler(server i2s_frame_callback_if i_i2s, client i2c_master_if i_i2c)
{

  int32_t loopback[NUM_I2S_LINES * 2] = {0};

  // Config can be done remotely via i_i2c
  xk_audio_316_mc_ab_AudioHwInit(i_i2c, hw_config);

  while (1) {
    select {
    case i_i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;

      xk_audio_316_mc_ab_AudioHwConfig(i_i2c, hw_config, SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY, 0, DATA_BITS, DATA_BITS);
      break;

    case i_i2s.receive(size_t num_chan_in, int32_t sample[num_chan_in]):
      memcpy(loopback, sample, num_chan_in * sizeof(int32_t));
      break;

    case i_i2s.send(size_t num_chan_out, int32_t sample[num_chan_out]):
      memcpy(sample, loopback, num_chan_out * sizeof(int32_t));
      break;

    case i_i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;
    }
  }
}


int main()
{
  interface i2s_frame_callback_if i_i2s_slave;
  interface i2c_master_if i_i2c[1];


  par {
    on tile[1]: i2s_frame_slave(i_i2s_slave, p_dac, NUM_I2S_LINES, p_adc, NUM_I2S_LINES, DATA_BITS, p_bclk, p_lrclk, clk_bclk);
    /* The application - loopback the I2S samples */
    on tile[1]: [[distribute]] i2s_handler(i_i2s_slave, i_i2c[0]);

    on tile[0]: {
        xk_audio_316_mc_ab_board_setup(hw_config); // Setup must be done on tile[0]
        xk_audio_316_mc_ab_i2c_master(i_i2c);      // Run I2C master server task to allow control from tile[1]
    }
  } 
  return 0;
}
