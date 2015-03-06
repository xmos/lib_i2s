#include <xs1.h>
#include <i2s.h>
#include <syscall.h>
#include <debug_print.h>
out buffered port:32 p_fsync = XS1_PORT_1A;
in buffered port:32 p_in[1] = { XS1_PORT_1B };
in port p_mclk = XS1_PORT_1E;
clock clk = XS1_CLKBLK_1;

#define SAMPLES_PER_FRAME 8
#define NUM_FRAMES 10

void tdm_loop(client tdm_if tdm)
{
  configure_clock_src(clk, p_mclk);
  tdm.configure(clk);
  start_clock(clk);
  tdm.start();

  int32_t vals[NUM_FRAMES * SAMPLES_PER_FRAME];

  //Initial 2 frames will have no data
  for (size_t j = 0; j < SAMPLES_PER_FRAME * 2; j++) {
    tdm.transfer(0, 0);
  }

  for (size_t i = 0; i < NUM_FRAMES; i++) {
   for (size_t j = 0; j < SAMPLES_PER_FRAME; j++) {
     vals[i * SAMPLES_PER_FRAME + j] = tdm.transfer(0, 0);
   }
  }
  for (size_t i = 0; i < NUM_FRAMES; i++) {
   for (size_t j = 0; j < SAMPLES_PER_FRAME; j++) {
     int expected = j + (1 << i);
     if (vals[i * SAMPLES_PER_FRAME + j] != expected)
       debug_printf("Error got unexpected value, frame %d, sample %d: %x (expected %x)\n", i, j, vals[i * SAMPLES_PER_FRAME + j], expected);
   }
  }
  _exit(0);
}

void dummy() {while(1);}

int main()
{
  tdm_if i_tdm;
  par {
    tdm_master(i_tdm, p_fsync, null, 0, p_in, 1, 8,
               TDM_SYNC_LENGTH_BIT | TDM_SYNC_DELAY_ZERO);
    tdm_loop(i_tdm);
    par(int i = 0; i < 7; i++)
         dummy();
  }
  return 0;
}
