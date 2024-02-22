// Copyright 2014-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <xs1.h>
#include "i2s.h"
#include "i2c.h"
#include "gpio.h"
#include "xassert.h"
#include <stdlib.h>
#include <debug_print.h>
#include <string.h>

#define TEST_LENGTH     (8) // Number of I2S frames to check

#ifndef NUM_I2S_LINES
#define NUM_I2S_LINES   (4)
#endif
#ifndef SAMPLE_FREQUENCY
#define SAMPLE_FREQUENCY (192000)
#endif
#ifndef MASTER_CLOCK_FREQUENCY
#define MASTER_CLOCK_FREQUENCY (24576000)
#endif
#ifndef SIM_LOOPBACK_TEST
#define SIM_LOOPBACK_TEST (0)
#endif
#ifndef DATA_BITS
#define DATA_BITS (32)
#endif


/* Ports and clocks used by the application */
on tile[0]: in buffered port:32 p_lrclk    = XS1_PORT_1G;
on tile[0]: in port p_bclk                 = XS1_PORT_1H;
on tile[0]: out buffered port:32 p_dout[4] = {XS1_PORT_1M, XS1_PORT_1N, XS1_PORT_1O, XS1_PORT_1P};
on tile[0]: in buffered port:32 p_din[4]   = {XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K, XS1_PORT_1L};
on tile[0]: clock clk_bclk = XS1_CLKBLK_2;

on tile[0]: port p_i2c = XS1_PORT_4A;
on tile[0]: port p_gpio = XS1_PORT_8C;

enum gpio_shared_audio_pins {
  GPIO_DAC_RST_N = 1,
  GPIO_PLL_SEL = 5,     // 1 = CS2100, 0 = Phaselink clock source
  GPIO_ADC_RST_N = 6,
  GPIO_MCLK_FSEL = 7,   // Select frequency on Phaselink clock. 0 = 24.576MHz for 48k, 1 = 22.5792MHz for 44.1k.
};

#define CS5368_ADDR           (0x4C) // I2C address of the CS5368 DAC
#define CS5368_GCTL_MDE       (0x01) // I2C mode control register number
#define CS5368_PWR_DN         (0x06)

#define CS4384_ADDR           (0x18) // I2C address of the CS4384 ADC
#define CS4384_MODE_CTRL      (0x02) // I2C mode control register number
#define CS4384_PCM_CTRL       (0x03) // I2C PCM control register number

//Simulator master I2S waveform gen
on tile[0]: out port p_mclk_gen       = XS1_PORT_1A; 
on tile[0]: clock clk_audio_mclk_gen  = XS1_CLKBLK_3;

on tile[0]: out port  p_bclk_gen      = XS1_PORT_1B;  
on tile[0]: clock clk_audio_bclk_gen  = XS1_CLKBLK_4;
on tile[0]: out port  p_lrclk_gen     = XS1_PORT_1C; 
on tile[0]: clock clk_audio_lrclk_gen = XS1_CLKBLK_5;

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
  const unsigned samFreq = SAMPLE_FREQUENCY;
  unsigned adc_mode;
  if(samFreq < 54000)
      adc_mode = 0x00;     /* Single-speed Mode Master */
  else if(samFreq < 108000)
      adc_mode = 0x01;     /* Double-speed Mode Master */
  else if(samFreq < 216000)
      adc_mode = 0x02;     /* Quad-speed Mode Master */

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

void slave_mode_clk_setup_sim(const unsigned samFreq, const unsigned chans_per_frame){
  const unsigned data_bits = DATA_BITS;
  const unsigned mclk_freq = MASTER_CLOCK_FREQUENCY;
  const unsigned mclk_freq_round_up = (mclk_freq / 1000000) + 1;

  const unsigned mclk_bclk_ratio = mclk_freq / (chans_per_frame * samFreq * data_bits); 
  const unsigned bclk_lrclk_ratio = (chans_per_frame * data_bits); // 48.828Hz  LRCLK 

  debug_printf("mclk:bclk - %d\nbclk_lrclk - %d\nmclk_freq_round_up - %d\n", mclk_bclk_ratio, bclk_lrclk_ratio, mclk_freq_round_up);

  //bclk generator
  configure_clock_src_divide(clk_audio_bclk_gen, p_mclk_gen, mclk_bclk_ratio/2);
  configure_port_clock_output(p_bclk_gen, clk_audio_bclk_gen);
  start_clock(clk_audio_bclk_gen);

  //lrclk generator
  configure_clock_src_divide(clk_audio_lrclk_gen, p_bclk_gen, bclk_lrclk_ratio/2);
  configure_port_clock_output(p_lrclk_gen, clk_audio_lrclk_gen);
  start_clock(clk_audio_lrclk_gen);

  //mclk generator
  configure_clock_rate(clk_audio_mclk_gen, mclk_freq_round_up, 1); // Slighly faster than typical MCLK of 24.576MHz
  configure_port_clock_output(p_mclk_gen, clk_audio_mclk_gen);
  start_clock(clk_audio_mclk_gen);
}

static char gpio_pin_map[4] =  {
  GPIO_DAC_RST_N,
  GPIO_ADC_RST_N,
  GPIO_PLL_SEL,
  GPIO_MCLK_FSEL
};

//Generate psuedo-random test sequence
int32_t random(int32_t rand){
    unsigned random = (unsigned)rand;
    crc32(random, -1, 0xEB31D82E);
    return (int32_t)random;
}

[[distributable]]
#pragma unsafe arrays
void i2s_handler(server i2s_frame_callback_if i_i2s, client i2c_master_if i_i2c, 
                 client output_gpio_if dac_reset,
                 client output_gpio_if adc_reset,
                 client output_gpio_if pll_select,
                 client output_gpio_if mclk_select)
{
  int32_t tx_data = 0xf00faa00; //Seed
  int32_t rx_data = 0xf00faa00; //Seed 
  uint32_t cycle_count = 0;

  int32_t loopback[NUM_I2S_LINES * 2] = {0};

  while (1) {
    select {
    case i_i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;

      if (SIM_LOOPBACK_TEST){
        slave_mode_clk_setup_sim(SAMPLE_FREQUENCY, 2);
        debug_printf("Initialse I2S on simulator\n");
      }

      else{
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

        reset_codecs(i_i2c);
        debug_printf("Initialse I2S on hardware\n");
        delay_milliseconds(500); //Allow print to complete

      }
      break;

    case i_i2s.receive(size_t num_chan_in, int32_t sample[num_chan_in]):
      if(SIM_LOOPBACK_TEST){
        for (size_t i=0; i<num_chan_in; i++) {
          if(sample[i] != rx_data){
              debug_printf("Rx from master at cycle %d. Data = 0x%x, expected = 0x%x\n", cycle_count, sample[i], rx_data);
              fail("ERROR: Data mismatch");
          }
          else{
            //debug_printf("OK\n");
          }
          rx_data = random(rx_data);
          cycle_count++;
          if (cycle_count >= TEST_LENGTH){
            debug_printf("Test pass\n");
            delay_microseconds(10); //Allow print to happen before we exit
            _Exit(0);
          }
        }
      }
      else{
        memcpy(loopback, sample, num_chan_in * sizeof(int32_t));
      }
      //delay_microseconds(19);
      break;

    case i_i2s.send(size_t num_chan_out, int32_t sample[num_chan_out]):
      if(SIM_LOOPBACK_TEST){
        for (size_t i=0; i<num_chan_out; i++){
          sample[i] = tx_data;
          tx_data = random(tx_data);
        }
      }
      else{
        memcpy(sample, loopback, num_chan_out * sizeof(int32_t));
      }
      //delay_microseconds(19);
      break;

    case i_i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;
    }
  }
}


int main()
{
  interface i2s_frame_callback_if i_i2s_slave;
  interface i2c_master_if i_i2c[1];
  interface output_gpio_if i_gpio[4];


  par {
    on tile[0]: i2s_frame_slave(i_i2s_slave, p_dout, NUM_I2S_LINES, p_din, NUM_I2S_LINES, DATA_BITS, p_bclk, p_lrclk, clk_bclk);

    on tile[0]: [[distribute]] i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
    on tile[0]: [[distribute]] output_gpio(i_gpio, 4, p_gpio, gpio_pin_map);

    /* The application - loopback the I2S samples */
    on tile[0]: [[distribute]] i2s_handler(i_i2s_slave, i_i2c[0], i_gpio[0], i_gpio[1], i_gpio[2], i_gpio[3]);

    on tile[0]: par (int i=0; i<7; i++) while(1); //Burn threads to restrict i2s to 62.5MIPS
  } 
  return 0;
}
