// Copyright (c) 2015-2018, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <i2s.h>
#include <stdlib.h>
#include <stdio.h>
#include <print.h>

#define RATIO 2

in port p_mclk  = XS1_PORT_1A;

in buffered port:32 p_din[4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
out buffered port:32  p_dout[4] = {XS1_PORT_1H, XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K};

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;

#if defined(SLAVE)
in port p_bclk = XS1_PORT_1B;
in buffered port:32 p_lrclk = XS1_PORT_1C;
#else
out buffered port:32 p_bclk = XS1_PORT_1B;
out buffered port:32 p_lrclk = XS1_PORT_1C;
#endif

out buffered port:32 tdm_dout[1] = {XS1_PORT_1O};
in  buffered port:32 tdm_din[1] = {XS1_PORT_1P};
out buffered port:32 p_fsync = XS1_PORT_1N;

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


static int request_response(){
    int r=0;
    while(!r)
        setup_resp_port :> r;
    setup_strobe_port <: 1;
    setup_strobe_port <: 0;
    setup_resp_port :> r;
    return r;
}


[[distributable]]
#pragma unsafe arrays
void app(server interface i2s_callback_if i2s){
  int fcount = 0;
  i2s_mode_t mode = I2S_MODE_I2S;
  int first_time = 1;
  while(1) {
    select {
    case i2s.receive(size_t index, int32_t sample):
      printstr(" R");
      printint(index);
      break;
    case i2s.send(size_t index) -> int32_t r:
      printstr(" S");
      printint(index);
      break;
    case i2s.restart_check() -> i2s_restart_t restart:
      fcount++;
      if (fcount % 4 == 0)
        restart = I2S_RESTART;
      else
        restart = I2S_NO_RESTART;
      break;
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
#if defined(TDM)
      tdm_config.offset = 0;
      tdm_config.sync_len = 1;
      tdm_config.channels_per_frame = TDM_CHANS_PER_FRAME;
#endif

      if (!isnull(i2s_config)) {
        i2s_config.mclk_bclk_ratio = RATIO;
        i2s_config.mode = I2S_MODE_I2S;
      }
      if (!first_time)
        printstr("\n");
      printstrln("I");
      if (fcount == 8) {
        exit(0);
      }
      if (!first_time) {
        #ifdef SLAVE
        request_response();
        #endif
      }
      first_time = 0;
      #ifdef SLAVE
      broadcast(384000,
                0, 0, mode == I2S_MODE_I2S);
      #endif
      break;
    }
  }
}

int main(){
    interface i2s_callback_if i_i2s;
#if !defined(SLAVE)
    configure_clock_ref(mclk, 32);
    start_clock(mclk);
#endif
    par {
      app(i_i2s);
#if defined(TDM)
      tdm_master(i_i2s, p_fsync, p_dout, NUM_OUT, p_din, NUM_IN, mclk);
#elif defined(MASTER)
      i2s_master(i_i2s, p_dout, NUM_OUT, p_din, NUM_IN,
                 p_bclk, p_lrclk, bclk, mclk);
#else
      i2s_slave(i_i2s, p_dout, NUM_OUT, p_din, NUM_IN,
                p_bclk, p_lrclk, bclk);
#endif
    }
    return 0;
}


