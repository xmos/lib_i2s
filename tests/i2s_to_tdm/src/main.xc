// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <i2s.h>
#include <platform.h>
/* Ports and clocks used by the application */

in port p_mclk  = XS1_PORT_1M;

out buffered port:32 p_i2s_dout[4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
in buffered port:32 p_i2s_din[4]  = {XS1_PORT_1I, XS1_PORT_1K, XS1_PORT_1L, XS1_PORT_1N};

out buffered port:32 p_i2s_bclk  = XS1_PORT_1A;
out buffered port:32 p_i2s_lrclk = XS1_PORT_1C;

out buffered port:32 p_tdm_fsync = XS1_PORT_1B;
in buffered port:32 p_tdm_din[1] = { XS1_PORT_1H };
out buffered port:32 p_tdm_dout[1] = { XS1_PORT_1O };

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;

#define MCLK_TO_BCLK_RATIO 4

#pragma unsafe arrays
[[distributable]]
extern void inline i2s_to_tdm(server i2s_callback_if i2s)
{
  /* This code works by buffering incoming samples into one buffer whilst
     outputting samples from the a second buffer.
     After all samples are used, the buffers are swapped.
  */
  int32_t i2s_to_tdm_a1[8] = {0};
  int32_t i2s_to_tdm_a2[8] = {0};
  int32_t tdm_to_i2s_a1[8] = {0};
  int32_t tdm_to_i2s_a2[8] = {0};
  int32_t *i2s_to_tdm_in = i2s_to_tdm_a1;
  int32_t *i2s_to_tdm_out = i2s_to_tdm_a2;
  int32_t *tdm_to_i2s_in = tdm_to_i2s_a1;
  int32_t *tdm_to_i2s_out = tdm_to_i2s_a2;
  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mclk_bclk_ratio = MCLK_TO_BCLK_RATIO;
      i2s_config.mode = I2S_MODE_I2S;
      tdm_config.offset = 0;
      tdm_config.sync_len = 1;
      tdm_config.channels_per_frame = MCLK_TO_BCLK_RATIO*2;
      break;

    case i2s.frame_start(unsigned timestamp, unsigned &restart):
      break;

    case i2s.receive(size_t index, int32_t sample):
      // The first sample of I2S, swap the in and out buffers
      if (index == 0) {
        int32_t *tmp;
        tmp = i2s_to_tdm_in;
        i2s_to_tdm_in = i2s_to_tdm_out;
        i2s_to_tdm_out = tmp;
      }

      // The first sample of TDM, swap the in and out buffers
      if (index == 8) {
        int32_t *tmp;
        tmp = tdm_to_i2s_in;
        tdm_to_i2s_in = tdm_to_i2s_out;
        tdm_to_i2s_out = tmp;
      }

      if (index < 8)
        i2s_to_tdm_in[index] = sample;
      else
        tdm_to_i2s_in[index - 8] = sample;
      break;

    case i2s.send(size_t index) -> int32_t sample:
      if (index < 8)
        sample = tdm_to_i2s_out[index];
      else
        sample = i2s_to_tdm_out[index - 8];
      break;
    }
  }
}


int main() {
  interface i2s_callback_if i_i2s;
  par {
    {
      configure_clock_src(mclk, p_mclk);
      i2s_tdm_master(i_i2s, p_i2s_dout, 4, p_i2s_din, 4,
                     p_i2s_bclk,
                     p_i2s_lrclk,
                     p_tdm_fsync,
                     p_tdm_dout, 1,
                     p_tdm_din, 1,
                     bclk,
                     mclk);
    }
    i2s_to_tdm(i_i2s);
  }
  return 0;
}
