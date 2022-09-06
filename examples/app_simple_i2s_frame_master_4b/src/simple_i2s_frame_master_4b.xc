// Copyright 2018-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

/* A simple application example used for code snippets in the library
 * documentation.
 */
#include <platform.h>
#include <xs1.h>
#include "i2s.h"
#include <print.h>
#include <stdlib.h>

#define SAMPLE_FREQUENCY (192000)
#define MASTER_CLOCK_FREQUENCY (24576000)
#define DATA_BITS (32)

[[distributable]]
void my_application(server i2s_frame_callback_if i_i2s) {
  while (1) {
    select {
      case i_i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
        i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY / (SAMPLE_FREQUENCY*2*DATA_BITS));
        i2s_config.mode = I2S_MODE_LEFT_JUSTIFIED;
        // Complete setup
        break;
      case i_i2s.restart_check() -> i2s_restart_t restart:
        // Inform the I2S slave whether it should restart or exit
        restart = I2S_NO_RESTART;
        break;
      case i_i2s.receive(size_t num_in, int32_t samples[num_in]):
        // Handle a received sample
        break;
      case i_i2s.send(size_t num_out, int32_t samples[num_out]):
        // Provide a sample to send
        break;
    }
  }
}

out buffered port:32 p_dout = XS1_PORT_4F;
in buffered port:32 p_din = XS1_PORT_4E;
out port p_bclk = XS1_PORT_1M;
out buffered port:32 p_lrclk = XS1_PORT_1A;
in port p_mclk = XS1_PORT_1B;

clock bclk = XS1_CLKBLK_1;

int main(void) {
  i2s_frame_callback_if i_i2s;

  par {
    i2s_frame_master_4b(i_i2s, p_dout, 4, p_din, 4, p_bclk, p_lrclk, p_mclk, bclk);
    my_application(i_i2s);
  }
  return 0;
}

// end
