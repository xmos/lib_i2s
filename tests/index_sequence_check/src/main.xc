#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>
#include <print.h>

in port p_mclk  = XS1_PORT_1A;
out buffered port:32 p_bclk = XS1_PORT_1B;
out buffered port:32 p_lrclk = XS1_PORT_1C;

in buffered port:32 p_din [4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;


[[distributable]]
#pragma unsafe arrays
void app(server interface i2s_callback_if i2s){
  int fcount = 0;
  while(1) {
    select {
    case i2s.receive(size_t index, int32_t sample):
      printstr("R");
      printintln(index);
      break;
    case i2s.send(size_t index) -> int32_t r:
      printstr("S");
      printintln(index);
      break;
    case i2s.frame_start(unsigned timestamp, unsigned &restart):
      restart = 0;
      printstrln("F");
      fcount++;
      if (fcount == 3)
        exit(0);
      break;
    case i2s.init(unsigned &mclk_bclk_ratio, i2s_mode &mode):
      mclk_bclk_ratio = RATIO;
      mode = I2S_MODE_I2S;
      break;
    }
  }
}

int main(){
    interface i2s_callback_if i_i2s;
    configure_clock_ref(mclk, 32);
    start_clock(mclk);
    par {
      app(i_i2s);
      i2s_master(i_i2s, p_dout, 4, p_din, 4,
                 p_bclk, p_lrclk, bclk, mclk);
    }
    return 0;
}


