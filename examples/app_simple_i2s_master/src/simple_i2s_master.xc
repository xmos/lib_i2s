// Copyright (c) 2018-2021, XMOS Ltd, All rights reserved
// This software is available under the terms provided in LICENSE.txt.

/* A simple application example used for code snippets in the library
 * documentation.
 */
#include <platform.h>
#include <xs1.h>
#include "i2s.h"
#include <print.h>
#include <stdlib.h>

#define SAMPLE_FREQUENCY 192000
#define MASTER_CLOCK_FREQUENCY 24576000

[[distributable]]
void my_application(server i2s_callback_if i_i2s) {
  while (1) {
    select {
      case i_i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
        i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;
        i2s_config.mode = I2S_MODE_LEFT_JUSTIFIED;
        // Complete setup
        break;
      case i_i2s.restart_check() -> i2s_restart_t restart:
        // Inform the I2S master whether it should restart or exit
        break;
      case i_i2s.receive(size_t index, int32_t sample):
        // Handle a received sample
        break;
      case i_i2s.send(size_t index) -> int32_t sample:
        // Provide a sample to send
        break;
    }
  }
}

out buffered port:32 p_dout[2] = {XS1_PORT_1D, XS1_PORT_1E};
in buffered port:32 p_din[2] = {XS1_PORT_1I, XS1_PORT_1J};
port p_mclk = XS1_PORT_1M;
out buffered port:32 p_bclk = XS1_PORT_1A;
out buffered port:32 p_lrclk = XS1_PORT_1C;

clock bclk = XS1_CLKBLK_1;
clock mclk = XS1_CLKBLK_2;

int main() {
  interface i2s_callback_if i_i2s;

  configure_clock_src(mclk, p_mclk);
  start_clock(mclk);

  par {
    i2s_master(i_i2s, p_dout, 2, p_din, 2, p_bclk, p_lrclk, bclk, mclk);
    my_application(i_i2s);
  }
  return 0;
}

// end
