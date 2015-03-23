#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>
#include <print.h>

in port p_bclk = XS1_PORT_1B;
in buffered port:32 p_lrclk = XS1_PORT_1C;

in buffered port:32 p_din [4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock bclk = XS1_CLKBLK_1;

out port setup_strobe_port = XS1_PORT_1L;
out port setup_data_port = XS1_PORT_16A;
in port  setup_resp_port = XS1_PORT_1M;

static void send_data_to_tester(
        out port setup_strobe_port,
        out port setup_data_port,
        unsigned data){
    setup_data_port <: data;
    sync(setup_data_port);
    setup_strobe_port <: 1;
    setup_strobe_port <: 0;
    sync(setup_strobe_port);
}

static void broadcast(unsigned bclk_freq,
        unsigned num_in, unsigned num_out, int is_i2s_justified){
    setup_strobe_port <: 0;

    send_data_to_tester(setup_strobe_port, setup_data_port, bclk_freq>>16);
    send_data_to_tester(setup_strobe_port, setup_data_port, bclk_freq);
    send_data_to_tester(setup_strobe_port, setup_data_port, num_in);
    send_data_to_tester(setup_strobe_port, setup_data_port, num_out);
    send_data_to_tester(setup_strobe_port, setup_data_port, is_i2s_justified);
 }

[[distributable]]
#pragma unsafe arrays
void app(server interface i2s_slave_callback_if i2s){
  int fcount = 0;

    i2s_mode mode = I2S_MODE_I2S;
    broadcast( 384000,
            NUM_IN, NUM_OUT, mode == I2S_MODE_I2S);
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
      printstr("F");
      printintln(fcount);
      fcount++;
      restart = fcount == 4; 
      break;
    case i2s.init(i2s_mode &mode):

      if (fcount >0 )
        exit(0);
      mode = I2S_MODE_I2S;
      break;
    }
  }
}

int main(){
    interface i2s_slave_callback_if i2s_i;
    par {
      [[distribute]] app(i2s_i);
      i2s_slave(i2s_i, p_dout, NUM_OUT, p_din, NUM_IN,
                 p_bclk, p_lrclk, bclk);
      par(int i=0;i<7;i++)while(1);
    }
    return 0;
}


