// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include <i2s.h>
#include <i2c.h>
#include <gpio.h>
#include <print.h>

/* Ports and clocks used by the application */
on tile[0]: out buffered port:32 p_lrclk = XS1_PORT_1G;
on tile[0]: out buffered port:32 p_bclk = XS1_PORT_1H;
on tile[0]: in port p_mclk = XS1_PORT_1F;
on tile[0]: out buffered port:32 p_dout[4] = {XS1_PORT_1M, XS1_PORT_1N, XS1_PORT_1O, XS1_PORT_1P};
on tile[0]: in buffered port:32 p_din[4] = {XS1_PORT_1I, XS1_PORT_1J, XS1_PORT_1K, XS1_PORT_1L};

on tile[0]: port p_i2c = XS1_PORT_4A;

on tile[0]: port p_gpio = XS1_PORT_8C;

on tile[0]: clock mclk = XS1_CLKBLK_1;
on tile[0]: clock bclk = XS1_CLKBLK_2;

#define SAMPLE_FREQUENCY 48000
#define MASTER_CLOCK_FREQUENCY 24576000

#define MCLK_FREQUENCY_48  24576000
#define MCLK_FREQUENCY_441 22579200

#define CS5368_ADDR           0x4C // I2C address of the CS5368 DAC
#define CS5368_CHIP_REV       0x00 // DAC register addresses...
#define CS5368_GCTL_MDE       0x01
#define CS5368_OVFL_ST        0x02

#define CS4384_ADDR           0x18 // I2C address of the CS4384 ADC
#define CS4384_CHIP_REV       0x01 // ADC register addresses...
#define CS4384_MODE_CTRL      0x02
#define CS4384_PCM_CTRL       0x03
#define CS4384_DSD_CTRL       0x04
#define CS4384_FLT_CTRL       0x05
#define CS4384_INV_CTRL       0x06
#define CS4384_GRP_CTRL       0x07
#define CS4384_RMP_MUTE       0x08
#define CS4384_MUTE_CTRL      0x09
#define CS4384_MIX_PR1        0x0a
#define CS4384_VOL_A1         0x0b
#define CS4384_VOL_B1         0x0c
#define CS4384_MIX_PR2        0x0d
#define CS4384_VOL_A2         0x0e
#define CS4384_VOL_B2         0x0f
#define CS4384_MIX_PR3        0x10
#define CS4384_VOL_A3         0x11
#define CS4384_VOL_B3         0x12
#define CS4384_MIX_PR4        0x13
#define CS4384_VOL_A4         0x14
#define CS4384_VOL_B4         0x15
#define CS4384_CM_MODE        0x16
#define CS5368_CHIP_REV       0x00
#define CS5368_GCTL_MDE       0x01
#define CS5368_OVFL_ST        0x02
#define CS5368_OVFL_MSK       0x03
#define CS5368_HPF_CTRL       0x04
#define CS5368_PWR_DN         0x06
#define CS5368_MUTE_CTRL      0x08
#define CS5368_SDO_EN         0x0a

#define CODEC_DEV_ID_ADDR           0x01
#define CODEC_PWR_CTRL_ADDR         0x02
#define CODEC_MODE_CTRL_ADDR        0x03
#define CODEC_ADC_DAC_CTRL_ADDR     0x04
#define CODEC_TRAN_CTRL_ADDR        0x05
#define CODEC_MUTE_CTRL_ADDR        0x06
#define CODEC_DACA_VOL_ADDR         0x07
#define CODEC_DACB_VOL_ADDR         0x08

enum gpio_shared_audio_pins {
  GPIO_DAC_RST_N = 1,
  GPIO_PLL_SEL = 5,     // 1 = CS2100, 0 = Phaselink clock source
  GPIO_ADC_RST_N = 6,
  GPIO_MCLK_FSEL = 7,   // Select frequency on Phaselink clock. 0 = 24.576MHz for 48k, 1 = 22.5792MHz for 44.1k.
};

void reset_codecs(client i2c_master_if i2c,
                 unsigned sample_frequency, unsigned master_clock_frequency)
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

  unsigned adc_dif = 0x01; // I2S mode
  unsigned adc_mode = 0x03;    /* Slave mode all speeds */

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



[[distributable]]
void i2s_loopback(server i2s_callback_if i2s,
                         client i2c_master_if i2c,
                         client output_gpio_if dac_reset,
                         client output_gpio_if adc_reset,
                         client output_gpio_if pll_select,
                         client output_gpio_if mclk_select)
{
  int32_t samples[8];
  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      i2s_config.mode = I2S_MODE_I2S;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;

      // Set CODEC in reset
      dac_reset.output(0);
      adc_reset.output(0);

      // Select 48Khz family clock (24.576Mhz)
      mclk_select.output(0);
      pll_select.output(0);

      // Allow the clock to settle
      delay_milliseconds(2);

      // Take DAC out of reset
      dac_reset.output(1);
      adc_reset.output(1); // and ADC

      reset_codecs(i2c, SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY);
      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;

    case i2s.receive(size_t index, int32_t sample):
      samples[index] = sample;
      break;

    case i2s.send(size_t index) -> int32_t sample:
      sample = samples[index];
      break;
    }
  }
};

static char gpio_pin_map[4] =  {
  GPIO_DAC_RST_N,
  GPIO_ADC_RST_N,
  GPIO_PLL_SEL,
  GPIO_MCLK_FSEL
};

int main() {
  interface i2s_callback_if i_i2s;
  interface i2c_master_if i_i2c[1];
  interface output_gpio_if i_gpio[4];
  par {
    /* System setup, I2S + Codec control over I2C */
    on tile[0]: {
      configure_clock_src(mclk, p_mclk);
      start_clock(mclk);
      i2s_master(i_i2s, p_dout, 4, p_din, 4,
                           p_bclk, p_lrclk, bclk, mclk);
    }
    on tile[0]: [[distribute]] i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
    on tile[0]: output_gpio(i_gpio, 4, p_gpio, gpio_pin_map);

    /* The application - loopback the I2S samples */
    on tile[0]: [[distribute]] i2s_loopback(i_i2s, i_i2c[0], i_gpio[0], i_gpio[1], i_gpio[2], i_gpio[3]);
  }
  return 0;
}
