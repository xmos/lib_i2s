// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include "i2s.h"
#include "i2c.h"
#include "gpio.h"
#include "xassert.h"
#include <print.h>
#include <stdlib.h>
#include <debug_print.h>
#include <stdio.h>

#define TEST_LENGTH     256

#ifndef NUM_I2S_LINES
#define NUM_I2S_LINES   1
#endif
#ifndef BURN_THREADS
#define BURN_THREADS    7
#endif
#ifndef SAMPLE_FREQUENCY
#define SAMPLE_FREQUENCY 192000
#endif
#define MASTER_CLOCK_FREQUENCY 24576000
#ifndef ADDITIONAL_SERVER_CASE
#define ADDITIONAL_SERVER_CASE 0
#endif

#ifndef SIM_SIM_LOOPBACK_TEST
#define SIM_LOOPBACK_TEST 1
#endif

#if ADDITIONAL_SERVER_CASE
typedef interface test_serv_if{
  void do_something(void);
}test_serv_if;
#endif


/* Ports and clocks used by the application */
on tile[0]: in buffered port:32 p_lrclk = XS1_PORT_1G;
on tile[0]: in port  p_bclk = XS1_PORT_1H;
on tile[0]: out buffered port:32 p_dout[4] = {XS1_PORT_1M, XS1_PORT_1N, XS1_PORT_1O, XS1_PORT_1P};
on tile[0]: in buffered port:32 p_din[4] = {XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K, XS1_PORT_1L};

on tile[0]: clock bclk = XS1_CLKBLK_2;

on tile[0]: port p_i2c = XS1_PORT_4A;
on tile[0]: port p_gpio = XS1_PORT_8C;

//Master ports
on tile[1]: clock bclk_master = XS1_CLKBLK_2;
on tile[1]: in port p_mclk_master = XS1_PORT_1F;
on tile[1]: out buffered port:32 p_lrclk_master = XS1_PORT_1G;
on tile[1]: out port  p_bclk_master = XS1_PORT_1H;
on tile[1]: out buffered port:32 p_dout_master[4] = {XS1_PORT_1M, XS1_PORT_1N, XS1_PORT_1O, XS1_PORT_1P};
on tile[1]: in buffered port:32 p_din_master[4] = {XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K, XS1_PORT_1L};

#if SIM_LOOPBACK_TEST
on tile[1]: out port  p_mclk = XS1_PORT_1C;
on tile[1]: clock mclk_master = XS1_CLKBLK_1;

#endif


#define CS5368_ADDR           0x4C // I2C address of the CS5368 DAC
#define CS5368_GCTL_MDE       0x01 // I2C mode control register number
#define CS5368_PWR_DN         0x06

#define CS4384_ADDR           0x18 // I2C address of the CS4384 ADC
#define CS4384_MODE_CTRL      0x02 // I2C mode control register number
#define CS4384_PCM_CTRL       0x03 // I2C PCM control register number

enum gpio_shared_audio_pins {
  GPIO_DAC_RST_N = 1,
  GPIO_PLL_SEL = 5,     // 1 = CS2100, 0 = Phaselink clock source
  GPIO_ADC_RST_N = 6,
  GPIO_MCLK_FSEL = 7,   // Select frequency on Phaselink clock. 0 = 24.576MHz for 48k, 1 = 22.5792MHz for 44.1k.
};

void reset_codecs(client i2c_master_if i2c)
{
  /* Mode Control 1 (Address: 0x02) */
  /* bit[7] : Control Port Enable (CPEN)     : Set to 1 for enable
   * bit[6] : Freeze controls (FREEZE)       : Set to 1 for freeze
   * bit[5] : PCM/DSD Selection (DSD/PCM)    : Set to 0 for PCM
   * bit[4:1] : DAC Pair Disable (DACx_DIS)  : All Dac Pairs enabled
   * bit[0] : Power Down (PDN)               : Powered down
   */
  i2c.write_reg(CS4384_ADDR, CS4384_MODE_CTRL, 0b11000001);

  /* PCM Control (Address: 0x03) */
  /* bit[7:4] : Digital Interface Format (DIF) : 0b1100 for TDM
   * bit[3:2] : Reserved
   * bit[1:0] : Functional Mode (FM) : 0x11 for auto-speed detect (32 to 200kHz)
   */
  i2c.write_reg(CS4384_ADDR, CS4384_PCM_CTRL, 0b00010111);

  /* Mode Control 1 (Address: 0x02) */
  /* bit[7] : Control Port Enable (CPEN)     : Set to 1 for enable
   * bit[6] : Freeze controls (FREEZE)       : Set to 0 for freeze
   * bit[5] : PCM/DSD Selection (DSD/PCM)    : Set to 0 for PCM
   * bit[4:1] : DAC Pair Disable (DACx_DIS)  : All Dac Pairs enabled
   * bit[0] : Power Down (PDN)               : Not powered down
   */
  i2c.write_reg(CS4384_ADDR, CS4384_MODE_CTRL, 0b10000000);

  unsigned adc_dif = 0x01;  // I2S mode
  unsigned adc_mode = 0x03; // Slave mode all speeds

  /* Reg 0x01: (GCTL) Global Mode Control Register */
  /* Bit[7]: CP-EN: Manages control-port mode
   * Bit[6]: CLKMODE: Setting puts part in 384x mode
   * Bit[5:4]: MDIV[1:0]: Set to 01 for /2
   * Bit[3:2]: DIF[1:0]: Data Format: 0x01 for I2S, 0x02 for TDM
   * Bit[1:0]: MODE[1:0]: Mode: 0x11 for slave mode
   */
  i2c.write_reg(CS5368_ADDR, CS5368_GCTL_MDE, 0b10010000 | (adc_dif << 2) | adc_mode);

  /* Reg 0x06: (PDN) Power Down Register */
  /* Bit[7:6]: Reserved
   * Bit[5]: PDN-BG: When set, this bit powers-own the bandgap reference
   * Bit[4]: PDM-OSC: Controls power to internal oscillator core
   * Bit[3:0]: PDN: When any bit is set all clocks going to that channel pair are turned off
   */
  i2c.write_reg(CS5368_ADDR, CS5368_PWR_DN, 0b00000000);
}

int delay = 0;

unsafe{
    int * unsafe delay_ptr = &delay;
}

[[distributable]]
void i2s_loopback(server i2s_callback_if i2s,
                  client i2c_master_if i2c,
                  client output_gpio_if dac_reset,
                  client output_gpio_if adc_reset,
                  client output_gpio_if pll_select,
                  client output_gpio_if mclk_select
#if ADDITIONAL_SERVER_CASE
                  ,server test_serv_if i_test_serv
#endif
                   )
{
  int32_t samples[8] = {0, 0, 0, 0, 0, 0, 0, 0};
#if SIM_LOOPBACK_TEST
  int32_t tx_data = 0;
  int32_t rx_data = -1; //Need to start one frame later
#endif

  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;

#if !SIM_LOOPBACK_TEST
      // Set CODECs in reset
      dac_reset.output(0);
      adc_reset.output(0);

      // Select 48Khz family clock (24.576Mhz)
      mclk_select.output(1);
      pll_select.output(0);

      // Allow the clock to settle
      delay_milliseconds(2);

      // Take CODECs out of reset
      dac_reset.output(1);
      adc_reset.output(1);

      reset_codecs(i2c);
#endif
      break;

    case i2s.receive(size_t index,  int32_t sample):
      timer t;
      int time;
      t :> time;
#if SIM_LOOPBACK_TEST
      if(rx_data >= 0){
          samples[index] = sample;
          //assert(samples[index] == (rx_data << 16) + index);
      }
      if ((index == NUM_I2S_LINES << 1) - 1) rx_data++;
#else
      samples[index] = sample;
#endif

      t when timerafter(time + delay) :> void;
      break;

    case i2s.send(size_t index) -> int32_t sample:
      timer t;
      int time;
      t :> time;
#if SIM_LOOPBACK_TEST
      {
          sample = samples[index];
      }
      if ((index == NUM_I2S_LINES << 1) - 1) tx_data++;
#else
      sample = 0xFFFFFFFF;
#endif

      t when timerafter(time + delay) :> void;
      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      delay++;
      break;

#if ADDITIONAL_SERVER_CASE
    case i_test_serv.do_something():
      printstrln("Foo!");
      break;
#endif

    }
  }
}

static char gpio_pin_map[4] =  {
  GPIO_DAC_RST_N,
  GPIO_ADC_RST_N,
  GPIO_PLL_SEL,
  GPIO_MCLK_FSEL
};


#if ADDITIONAL_SERVER_CASE
void test_client_task(client test_serv_if i_test_serv){
    while(1);
}
#endif

void burn(void){
    while(1);
}

[[distributable]]
void i2s_handler_master(server i2s_he_callback_if i2s)
{
  int32_t samples[TEST_LENGTH][8] = {{0}};

  int32_t tx_data = 0;
  int32_t rx_data = -1; //Ignore first..

  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;
      break;

    case i2s.receive(size_t num_chan_in, int32_t sample[num_chan_in]):

      if(rx_data > 0){
          for (size_t i=0; i<num_chan_in; i++) {
              samples[rx_data][i] = sample[i];
          }
      }
      rx_data++;
      if (rx_data == TEST_LENGTH){
          for (size_t i=0; i<TEST_LENGTH; i++) {
              //debug_printf("Rx from master %d = 0x%x, sent = 0x%x\n", i, samples[i][0], (i << 16) + 0);
              if (i >= 3) {
                  if (samples[i][0] != (i << 16) + 0){
                      debug_printf("Rx from master at cycle %d. Data = 0x%x, sent = 0x%x\n", i, samples[i][0], (i << 16) + 0);
                      fail("Data mismatch");
                  }
              }
          }
          debug_printf("Test pass\n");
          delay_microseconds(10);
          _Exit(0);
      }
      //unsafe {(*delay_ptr)++;} Doesn't work as wrong tile!!
      break;

    case i2s.send(size_t num_chan_out, int32_t sample[num_chan_out]):
      for (size_t i=0; i<num_chan_out; i++){
              sample[i] = (tx_data << 16) + i;
          }
      tx_data++;
      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;
    }
  }
}


int main()
{
  interface i2s_callback_if i_i2s;
  interface i2s_he_callback_if i_i2s_master;
  interface i2c_master_if i_i2c[1];
  interface output_gpio_if i_gpio[4];

#if ADDITIONAL_SERVER_CASE
  test_serv_if i_test_serv;
#endif

  par {
    on tile[0]: {
      /* System setup, I2S + Codec control over I2C */
        i2s_slave(i_i2s, p_dout, NUM_I2S_LINES, p_din, NUM_I2S_LINES, p_bclk, p_lrclk, bclk);
      //i2s_master(i_i2s, p_dout, NUM_I2S_LINES, p_din, NUM_I2S_LINES, p_bclk, p_lrclk, p_mclk, bclk, mclk);
    }

    on tile[0]: [[distribute]] i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
    on tile[0]: [[distribute]] output_gpio(i_gpio, 4, p_gpio, gpio_pin_map);

    /* The application - loopback the I2S samples */
    on tile[0]: [[distribute]] i2s_loopback(i_i2s, i_i2c[0], i_gpio[0], i_gpio[1], i_gpio[2], i_gpio[3]
#if ADDITIONAL_SERVER_CASE
           ,i_test_serv);
    on tile[0]: test_client_task(i_test_serv);
#else
            );
#endif


    on tile[1]: {
#if SIM_LOOPBACK_TEST
        configure_clock_ref(mclk_master, 2); //100 / (2*2) = 25MHz
        set_port_clock(p_mclk, mclk_master);
        set_port_mode_clock(p_mclk);
        start_clock(mclk_master);
#endif
        i2s_he_master(i_i2s_master, p_dout_master, NUM_I2S_LINES, p_din_master, NUM_I2S_LINES, p_bclk_master, p_lrclk_master, p_mclk_master, bclk_master);
    }
    on tile[1]: i2s_handler_master(i_i2s_master);


    on tile[0]: par (int i=0; i<(BURN_THREADS > 1 ? BURN_THREADS - ADDITIONAL_SERVER_CASE: 0); i++) {burn();};
  }
  return 0;
}
