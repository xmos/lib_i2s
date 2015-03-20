#include <xs1.h>
#include <i2s.h>
#include <syscall.h>

out buffered port:32 p_fsync = XS1_PORT_1A;
out buffered port:32 p_tdm_dout[2] = { XS1_PORT_1B, XS1_PORT_1C };
in buffered port:32 p_tdm_din[0] = {};
out port p_clk = XS1_PORT_1D;

clock clk = XS1_CLKBLK_1;

void tdm_loop(client tdm_if tdm_i)
{

  _exit(0);
}

int main()
{
  tdm_if tdm_i;
  par {
     tdm_master(tdm_i, p_fsync,
             p_tdm_dout, 2,
             p_tdm_din,0,
             8, 0, 1);
    tdm_loop(tdm_i);
  }
  return 0;
}
