#include <xs1.h>
#include <i2s.h>
#include <syscall.h>

out buffered port:32 p_fsync = XS1_PORT_1A;
out buffered port:32 p_out[2] = { XS1_PORT_1B, XS1_PORT_1C };
out port p_clk = XS1_PORT_1D;

clock clk = XS1_CLKBLK_1;

void tdm_loop(client tdm_if tdm)
{
  configure_clock_rate(clk, 100, 8);
  configure_port_clock_output(p_clk, clk);
  tdm.configure(clk);
  start_clock(clk);
  tdm.start();

  int32_t val = 0;

  for (int i = 0; i < 10; i++) {
   for (size_t i = 0; i < 8; i++) {
     val = ~val;
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
