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
        // Inform the TDM master whether it should restart or exit
        restart = I2S_NO_RESTART;
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
in buffered port:32 p_din[2] = {XS1_PORT_1I, XS1_PORT_1K};
in port p_bclk = XS1_PORT_1A;
out buffered port:32 p_fsync = XS1_PORT_1C;

clock bclk = XS1_CLKBLK_1;

int main(void) {
  i2s_callback_if i_i2s;
  configure_clock_src(bclk, p_bclk);

  par {
    tdm_master(i_i2s, p_fsync, p_dout, 2, p_din, 2, bclk);
    my_application(i_i2s);
  }
  return 0;
}

// end
