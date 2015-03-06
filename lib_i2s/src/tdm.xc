#include <i2s.h>
#include <xs1.h>
#include <xassert.h>
#include <xclib.h>
#include <print.h>

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

#ifndef TDM_MAX_SAMPLES_PER_FRAME
#define TDM_MAX_SAMPLES_PER_FRAME 8
#endif

#ifndef TDM_MAX_NUM_IN
#define TDM_MAX_NUM_IN 4
#endif

[[distributable]]
void tdm_master(server interface tdm_if i_tdm,
                out buffered port:32 p_fsync,
                out buffered port:32 (&?p_out)[num_out],
                size_t num_out,
                in buffered port:32 (&?p_in)[num_in],
                size_t num_in,
                static const size_t samples_per_frame,
                unsigned format_flags)
{
  size_t findex = 0;
  size_t init_frame = 1;
  int32_t buf[TDM_MAX_SAMPLES_PER_FRAME * TDM_MAX_NUM_IN] = {0};
  assert(num_in <= TDM_MAX_NUM_IN);
  assert(samples_per_frame <= TDM_MAX_SAMPLES_PER_FRAME);
  while (1) {
    select {
    case i_tdm.configure(const clock clk):
      configure_out_port_no_ready(p_fsync, clk, 0);
      if (!isnull(p_out)) {
        for (size_t i = 0; i < num_out; i++)
          configure_out_port_no_ready(p_out[i], clk, 0);
      }
      if (!isnull(p_in)) {
        for (size_t i = 0; i < num_in; i++)
          configure_in_port_no_ready(p_in[i], clk);
      }
      break;
    case i_tdm.start():
      unsigned ts;
      p_fsync <: 0 @ ts;
      ts += 32 * (samples_per_frame - 1);
      p_fsync @ ts <: 0;
      if (format_flags & TDM_SYNC_DELAY_ONE)
        ts += 1;
      if (!isnull(p_out)) {
        for (size_t i = 0; i < num_out; i++)
          p_out[i] @ ts <: 0;
      }
      if (!isnull(p_in)) {
        for (size_t i = 0; i < num_in; i++) {
          setup_timed_input(p_in[i], ts);
        }
      }
      init_frame = 1;
      break;
    case i_tdm.transfer(size_t i, int32_t val) -> int32_t rval:
      if (!init_frame) {
        if (findex == 0)
          p_fsync <: format_flags & TDM_SYNC_LENGTH_WORD ? 0xffffffff : 0x1;
        else
          p_fsync <: 0;

        if (!isnull(p_out))
            p_out[i] <: val;

        if (!isnull(p_in)) {
          int32_t val = bitrev(complete_timed_input(p_in[i]));
          int prev_findex = findex - 2;
          if (prev_findex < 0)
            prev_findex += samples_per_frame;
          buf[i * samples_per_frame + prev_findex] = val;
        }
      }
      rval = buf[i * samples_per_frame + findex];
      findex++;
      if (findex == samples_per_frame) {
        if (init_frame)
          init_frame--;
        findex = 0;
      }
      break;
    }
  }
}
