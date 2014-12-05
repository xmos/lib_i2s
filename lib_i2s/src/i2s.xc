#include <xs1.h>
#include <xclib.h>
#include "xassert.h"
#include "i2s.h"
#include "print.h"
#ifdef __i2s_callbacks_h_exists__
#include "i2s_callbacks.h"
#endif

static inline void setup_timed_input(in buffered port:32 p, unsigned t)
{
  asm volatile("setpt res[%0], %1" : : "r"(p), "r"(t):"memory");
}

static inline unsigned complete_timed_input(in buffered port:32 p)
{
  unsigned val;
  asm volatile("in %0, res[%1]":"=r"(val):"r"(p):"memory");
  return val;
}

#ifdef I2S_MASTER_SPECIALIZE
#define FULL_UNROLL 1
#else
#define FULL_UNROLL 0
#define I2S_MASTER_SPECIALIZE
#endif


#ifndef I2S_MASTER_SPECIALIZE_NUM_IN
#define I2S_MASTER_SPECIALIZE_NUM_IN -1
#endif

#ifndef I2S_MASTER_SPECIALIZE_NUM_OUT
#define I2S_MASTER_SPECIALIZE_NUM_OUT -1
#endif

#define MCLKS_PER_32_BCLKS  64

#define BITCLOCK_PATTERN_2 0x55555555
#define BITCLOCK_PATTERN_4 0x33333333
#define BITCLOCK_PATTERN_8 0x0f0f0f0f

#pragma unsafe arrays
static inline void i2s_master_aux(
        client I2S_MASTER_SPECIALIZE interface i2s_callback_if i_client,
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
        size_t num_in,
        out buffered port:32 p_bclk,
        out buffered port:32 p_lrclk,
        clock bclk,
        const clock mclk,
        unsigned sample_frequency,
        unsigned master_clock_frequency
        )
{
  unsigned master_to_word_clock_ratio = master_clock_frequency / sample_frequency;

  if (I2S_MASTER_SPECIALIZE_NUM_IN != -1) {
    if (I2S_MASTER_SPECIALIZE_NUM_IN != num_in)
      fail("i2s_master called with num_in argument different to I2S_MASTER_SPECIALIZE_NUM_IN");
    num_in = I2S_MASTER_SPECIALIZE_NUM_IN;
  }

  if (I2S_MASTER_SPECIALIZE_NUM_OUT != -1) {
    if (I2S_MASTER_SPECIALIZE_NUM_OUT != num_out)
      fail("i2s_master called with num_in argument different to I2S_MASTER_SPECIALIZE_NUM_IN");
    num_out = I2S_MASTER_SPECIALIZE_NUM_OUT;
  }

  configure_clock_src(bclk, p_bclk);
  set_port_clock(p_bclk, mclk);

  set_port_clock(p_lrclk, bclk);

  for (size_t i = 0; i < num_in; i++)
    set_port_clock(p_din[i], bclk);

  for (size_t i = 0; i < num_out; i++)
    set_port_clock(p_dout[i], bclk);

  // Start clock blocks after configuration
  start_clock(bclk);

  int mclk_to_bclk_ratio = master_to_word_clock_ratio / MCLKS_PER_32_BCLKS;

  // This sections aligns the ports so that the dout/din ports are
  // inputting and outputting in sync,
  // setting the t variable at the end sets when the lrclk will change
  // w.r.t to the bitclock.
  for (size_t i=0;i<num_out;i++) {
    p_dout[i] <: 0;
  }

  for (size_t i=0;i<num_in;i++)
    setup_timed_input(p_din[i], 31);

  p_lrclk <: 0;

  // Output 32 ticks
  for (size_t i=0;i<mclk_to_bclk_ratio;i++)  {
    switch (mclk_to_bclk_ratio) {
    case 2:
      p_bclk <: BITCLOCK_PATTERN_2;
      break;
    case 4:
      p_bclk <: BITCLOCK_PATTERN_4;
      break;
    case 8:
      p_bclk <: BITCLOCK_PATTERN_8;
      break;
    default:
      fail("unknown master clock/word clock ratio");
      break;
    }
  }

  for (size_t i=0;i<num_out;i++) {
    p_dout[i] <: 0;
  }
  p_lrclk <: 0;

  unsigned max_io_count = num_in > num_out ? num_in : num_out;
  unsigned int lrclk_val = 0x7FFFFFFF;
  // This is the master timing clock for the audio system. It is used to
  // timestamp every frame to aid any clock recovery mechanism attached to the
  // audio
  timer tmr;
  unsigned restart = 0;
  while (!restart) {
    unsigned int timestamp;
    tmr :> timestamp;
    i_client.frame_start(timestamp, restart);

    #pragma loop unroll
    for (size_t lr=0;lr<2;lr++) {
      // This assumes that there are 32 BCLKs in one half of an LRCLK
      lrclk_val = ~lrclk_val;

      switch (mclk_to_bclk_ratio) {
      case 2:
        unsigned samples_per_bclk = (max_io_count + 1) / 2;
        unsigned bclk_val = BITCLOCK_PATTERN_2;
        #pragma loop unroll
        for (size_t k=0;k<2;k++) {
          p_bclk <: bclk_val;

          #if FULL_UNROLL
          #pragma loop unroll
          #endif
          for (size_t j=0;j<samples_per_bclk;j++) {
            int pnum = k*samples_per_bclk + j;
            if (pnum < num_in) {
              #pragma xta endpoint "i2s_master_sample_input"
              unsigned sample = complete_timed_input(p_din[pnum]);
              sample = (bitrev(sample) << 1);
              i_client.receive(pnum*2+lr, sample);
            }
            if (pnum < num_out) {
              unsigned sample = i_client.send(pnum*2+lr);
              sample = bitrev(sample);
              #pragma xta endpoint "i2s_master_sample_output"
              p_dout[pnum] <: sample;
            }
          }

        }
        break;
      case 4:
        unsigned bclk_val = BITCLOCK_PATTERN_4;
        unsigned
samples_per_bclk = (max_io_count + 3) / 4;
        #pragma loop unroll
        for (size_t k=0;k<4;k++) {
          p_bclk <: bclk_val;

          for (size_t j=0;j<samples_per_bclk;j++) {
            int pnum = k*samples_per_bclk + j;
            if (pnum < num_in) {
              #pragma xta endpoint "i2s_master_sample_input"
              unsigned sample = complete_timed_input(p_din[pnum]);
              sample = (bitrev(sample) << 1);
              i_client.receive(pnum*2+lr, sample);
            }
          }

          for (size_t j=0;j<samples_per_bclk;j++) {
            int pnum = k*samples_per_bclk + j;
            if (pnum < num_out) {
              unsigned sample = i_client.send(pnum*2+lr);
              sample = bitrev(sample);
              #pragma xta endpoint "i2s_master_sample_output"
              p_dout[pnum] <: sample;
            }
          }
        }
        break;
      case 8:
        unsigned bclk_val = BITCLOCK_PATTERN_8;
        unsigned samples_per_bclk = (max_io_count + 7) / 8;
        #pragma loop unroll
        for (size_t k=0;k<8;k++) {
          p_bclk <: bclk_val;

          for (size_t j=0;j<samples_per_bclk;j++) {
            int pnum = k*samples_per_bclk + j;
            if (pnum < num_in) {
              #pragma xta endpoint "i2s_master_sample_input"
              unsigned sample = complete_timed_input(p_din[pnum]);
              sample = (bitrev(sample) << 1);
              i_client.receive(pnum*2+lr, sample);
            }
          }

          for (size_t j=0;j<samples_per_bclk;j++) {
            int pnum = k*samples_per_bclk + j;
            if (pnum < num_out) {
              unsigned sample = i_client.send(pnum*2+lr);
              sample = bitrev(sample);
              #pragma xta endpoint "i2s_master_sample_output"
              p_dout[pnum] <: sample;
            }
          }
        }
        break;
      default:
        unreachable();
        break;
      }
      #pragma xta endpoint "i2s_master_lrclk_output"
      p_lrclk <: lrclk_val;
    }
  }

}

void i2s_master(
        client I2S_MASTER_SPECIALIZE interface i2s_callback_if i_client,
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
        size_t num_in,
        out buffered port:32 p_bclk,
        out buffered port:32 p_lrclk,
        clock bclk,
        const clock mclk,
        unsigned sample_frequency,
        unsigned master_clock_frequency)
{
  while (1) {
    i_client.init(sample_frequency, master_clock_frequency);
    i2s_master_aux(i_client, p_dout, num_out, p_din, num_in,
                   p_bclk, p_lrclk, bclk, mclk,
                   sample_frequency, master_clock_frequency);
    for (size_t i = 0; i < num_out; i++)
      clearbuf(p_dout[i]);
    clearbuf(p_lrclk);
    p_bclk <: 0;
    stop_clock(bclk);
    sync(p_bclk);
  }
}
