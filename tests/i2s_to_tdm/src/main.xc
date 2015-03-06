#include <xs1.h>
#include <i2s.h>
#include <syscall.h>
#include "debug_print.h"

#define MASTER_CLOCK_FREQUENCY 12880000
#define SAMPLE_FREQUENCY          48000

/* Ports and clocks used by the application */

in port p_mclk  = XS1_PORT_1M;

out buffered port:32 p_i2s_out[4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
in buffered port:32 p_i2s_in[4]  = {XS1_PORT_1I, XS1_PORT_1K, XS1_PORT_1L, XS1_PORT_1N};

out buffered port:32 p_i2s_bclk  = XS1_PORT_1A;
out buffered port:32 p_i2s_lrclk = XS1_PORT_1C;

out buffered port:32 p_tdm_fsync = XS1_PORT_1B;
in buffered port:32 p_tdm_in[1] = { XS1_PORT_1H };
out buffered port:32 p_tdm_out[1] = { XS1_PORT_1O };

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;

[[distributable]]
void i2s_to_tdm(server i2s_callback_if i2s,
                client tdm_if tdm)
{
  int32_t samples[8];
  int init_tdm = 0;
  while (1) {
    select {
    case i2s.init(unsigned &sample_frequency, unsigned &master_clock_frequency):
      init_tdm = 1;
      break;

    case i2s.frame_start(unsigned timestamp, unsigned &restart):
      if (init_tdm) {
        tdm.start();
        init_tdm = 0;
      }
      break;

    case i2s.receive(size_t index, int32_t sample):
      samples[index] = tdm.transfer(0, sample);
      break;

    case i2s.send(size_t index) -> int32_t sample:
      sample = samples[index];
      break;
    }
  }
}


int main() {
  interface i2s_callback_if i_i2s;
  interface tdm_if i_tdm;
  par {
    tdm_master(i_tdm, p_tdm_fsync, p_tdm_out, 1, p_tdm_in, 1, 8,
               TDM_SYNC_LENGTH_BIT | TDM_SYNC_DELAY_ZERO);
    {
      configure_clock_src(mclk, p_mclk);
      i_tdm.configure(mclk);
      start_clock(mclk);
      par {
        i2s_master(i_i2s, p_i2s_out, 4, p_i2s_in, 4,
                   p_i2s_bclk, p_i2s_lrclk, bclk, mclk,
                   SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY,
                   I2S_FORMAT_STANDARD);
        i2s_to_tdm(i_i2s, i_tdm);
      }
    }

  }
  return 0;
}
