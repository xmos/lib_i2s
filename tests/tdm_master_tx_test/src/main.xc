#include <xs1.h>
#include <i2s.h>
#include <syscall.h>
#include <print.h>
out buffered port:32 p_fsync = XS1_PORT_1A;
out buffered port:32 p_out[2] = { XS1_PORT_1B, XS1_PORT_1C };
in port p_mclk = XS1_PORT_1E;
clock clk = XS1_CLKBLK_1;

void tdm_loop(client tdm_if tdm)
{
  configure_clock_src(clk, p_mclk);
  tdm.configure(clk);
  start_clock(clk);
  tdm.start();

  int32_t val = 0;

  for (size_t i = 0; i < 32; i++) {
   for (size_t j = 0; j < 8; j++) {
     val = j + (1 << i);
     tdm.transfer(0, val);
   }
  }
  _exit(0);
}

int main()
{
  tdm_if i_tdm;
  par {
    tdm_master(i_tdm, p_fsync, p_out, 1, null, 0, 8,
               TDM_SYNC_LENGTH_BIT | TDM_SYNC_DELAY_ZERO);
    tdm_loop(i_tdm);
  }
  return 0;
}
