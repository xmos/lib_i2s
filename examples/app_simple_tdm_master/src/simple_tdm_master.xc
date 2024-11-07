// Copyright 2018-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

/* A simple application example used for code snippets in the library
 * documentation.
 */
#include <platform.h>
#include <xs1.h>
#include "i2s.h"

#define SAMPLE_FREQUENCY (192000)
#define MASTER_CLOCK_FREQUENCY (24576000)

[[distributable]]
void my_application(server tdm_callback_if i_tdm) {
  while (1) {
    select {
      case i_tdm.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
        tdm_config.offset = 0;
        tdm_config.sync_len = 32;
        tdm_config.channels_per_frame = 8;
        // Complete setup
        break;
      case i_tdm.restart_check() -> i2s_restart_t restart:
        // Inform the TDM master whether it should restart or exit
        restart = I2S_NO_RESTART;
        break;
      case i_tdm.receive(size_t index, int32_t sample):
        // Handle a received sample
        break;
      case i_tdm.send(size_t index) -> int32_t sample:
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
  tdm_callback_if i_tdm;
  configure_clock_src(bclk, p_bclk);

  par {
    tdm_master(i_tdm, p_fsync, p_dout, 1, p_din, 1, bclk);
    my_application(i_tdm);
  }
  return 0;
}
