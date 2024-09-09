// Copyright 2015-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <print.h>
#include <i2s.h>
#include <i2c.h>
#include <platform.h>
#include "xk_audio_316_mc_ab/board.h"

#define SAMPLE_FREQUENCY        48000
#define MASTER_CLOCK_FREQUENCY  24576000
#define DATA_BITS               32
#define CHANS_PER_FRAME         8
#define NUM_TDM_LINES           4


// TDM resources
on tile[1]: in port p_mclk =                                PORT_MCLK_IN;
on tile[1]: buffered out port:32 p_fsync =                  PORT_I2S_LRCLK;
on tile[1]: out port p_bclk =                               PORT_I2S_BCLK;
on tile[1]: buffered out port:32 p_dac[NUM_TDM_LINES] =     {PORT_I2S_DAC0, PORT_I2S_DAC1, PORT_I2S_DAC2, PORT_I2S_DAC3};
on tile[1]: buffered in port:32 p_adc[NUM_TDM_LINES] =      {PORT_I2S_ADC0 ,PORT_I2S_ADC1, PORT_I2S_ADC2, PORT_I2S_ADC3};
on tile[1]: clock bclk =                                    XS1_CLKBLK_1;

// Board configuration from lib_board_support
static const xk_audio_316_mc_ab_config_t hw_config = {
        CLK_FIXED,              // clk_mode. Drive a fixed MCLK output
        0,                      // 1 = dac_is_clock_master
        MASTER_CLOCK_FREQUENCY,
        0,                      // pll_sync_freq (unused when driving fixed clock)
        AUD_316_PCM_FORMAT_TDM,
        DATA_BITS,
        CHANS_PER_FRAME
};




[[distributable]]
void tdm_loopback(server i2s_callback_if i2s,
                  client i2c_master_if i2c)
{

  // Config can be done remotely via i_i2c
  xk_audio_316_mc_ab_AudioHwInit(i2c, hw_config);

  int32_t samples[32];

  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      tdm_config.offset = 0;
      tdm_config.sync_len = DATA_BITS;
      tdm_config.channels_per_frame = CHANS_PER_FRAME;

      xk_audio_316_mc_ab_AudioHwConfig(i2c, hw_config, SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY, 0, DATA_BITS, DATA_BITS);
      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;

    case i2s.receive(size_t index, int32_t sample):
      samples[index] = sample;
      break;

    case i2s.send(size_t index) -> int32_t sample:
      sample = samples[index];
      break;
    }
  }
}

int main() {
  interface i2s_callback_if i_i2s;
  interface i2c_master_if i_i2c[1];
  par {
    on tile[1]: {
      configure_clock_src_divide(bclk, p_mclk, 1);
      configure_port_clock_output(p_bclk, bclk); 
      tdm_master(i_i2s, p_fsync, p_dac, NUM_TDM_LINES, p_adc, NUM_TDM_LINES, bclk);
    }

    on tile[1]: [[distribute]]
      tdm_loopback(i_i2s, i_i2c[0]);

    on tile[1]: par(int i=0;i<7;i++) while(1);

    on tile[0]: {
        xk_audio_316_mc_ab_board_setup(hw_config); // Setup must be done on tile[0]
        xk_audio_316_mc_ab_i2c_master(i_i2c);      // Run I2C master server task to allow control from tile[1]
    }

  }
  return 0;
}
