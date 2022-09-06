// Copyright 2015-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <print.h>
#include <i2s.h>
#include <i2c.h>
#include <gpio.h>
#include <platform.h>

/* Ports and clocks used by the application */
out buffered port:32 p_dout[4] = on tile[0]: {XS1_PORT_1M, XS1_PORT_1N,
                                              XS1_PORT_1O, XS1_PORT_1P};
in  buffered port:32 p_din[4] =  on tile[0]: {XS1_PORT_1I, XS1_PORT_1J,
                                              XS1_PORT_1K, XS1_PORT_1L};
out buffered port:32 p_fsync =   on tile[0]:  XS1_PORT_1G;
out port p_bclk = on tile[0]: XS1_PORT_1H;
in port p_mclk =  on tile[0]: XS1_PORT_1F;

out port p_gpio = on tile[0]: XS1_PORT_8C;
port p_i2c =      on tile[0]: XS1_PORT_4A;
port p_led1 = on tile[1]:XS1_PORT_4C;
port p_led2 = on tile[1]:XS1_PORT_4D;

clock clk1 = on tile[0]: XS1_CLKBLK_1;

//Address on I2C bus
#define CS5368_ADDR          (0x4C)

//Register Addresess
#define CS5368_CHIP_REV      (0x00)
#define CS5368_GCTL_MDE      (0x01)
#define CS5368_OVFL_ST       (0x02)
//Address on I2C bus
#define CS4384_ADDR          (0x18)

//Register Addresess
#define CS4384_CHIP_REV      (0x01)
#define CS4384_MODE_CTRL     (0x02)
#define CS4384_PCM_CTRL      (0x03)
#define CS4384_DSD_CTRL      (0x04)
#define CS4384_FLT_CTRL      (0x05)
#define CS4384_INV_CTRL      (0x06)
#define CS4384_GRP_CTRL      (0x07)
#define CS4384_RMP_MUTE      (0x08)
#define CS4384_MUTE_CTRL     (0x09)
#define CS4384_MIX_PR1       (0x0a)
#define CS4384_VOL_A1        (0x0b)
#define CS4384_VOL_B1        (0x0c)
#define CS4384_MIX_PR2       (0x0d)
#define CS4384_VOL_A2        (0x0e)
#define CS4384_VOL_B2        (0x0f)
#define CS4384_MIX_PR3       (0x10)
#define CS4384_VOL_A3        (0x11)
#define CS4384_VOL_B3        (0x12)
#define CS4384_MIX_PR4       (0x13)
#define CS4384_VOL_A4        (0x14)
#define CS4384_VOL_B4        (0x15)
#define CS4384_CM_MODE       (0x16)
#define CS5368_CHIP_REV      (0x00)
#define CS5368_GCTL_MDE      (0x01)
#define CS5368_OVFL_ST       (0x02)
#define CS5368_OVFL_MSK      (0x03)
#define CS5368_HPF_CTRL      (0x04)
#define CS5368_PWR_DN        (0x06)
#define CS5368_MUTE_CTRL     (0x08)
#define CS5368_SDO_EN        (0x0a)


[[distributable]]
void tdm_loopback(server i2s_callback_if i2s,
                  client i2c_master_if i2c,
                  client output_gpio_if dac_reset,
                  client output_gpio_if adc_reset,
                  client output_gpio_if clock_select,
                  client output_gpio_if led)
{
  int32_t samples[32];
  int count = 0;  
  int led_val = 1;
  led.output(led_val);
  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      tdm_config.offset = 0;
      tdm_config.sync_len = 32;
      tdm_config.channels_per_frame = 8;

      /* Set CODEC in reset */
      dac_reset.output(0);
      adc_reset.output(0);

      /* Select 48Khz family clock (24.576Mhz) */
      clock_select.output(1);

      /* Allow the clock to settle */
      delay_milliseconds(2);

      /* DAC out of reset */
      dac_reset.output(1);

      /* Mode Control 1 (Address: 0x02) */
      /* bit[7] : Control Port Enable (CPEN)     : Set to 1 for enable
       * bit[6] : Freeze controls (FREEZE)       : Set to 1 for freeze
       * bit[5] : PCM/DSD Selection (DSD/PCM)    : Set to 0 for PCM
       * bit[4:1] : DAC Pair Disable (DACx_DIS)  : All Dac Pairs enabled
       * bit[0] : Power Down (PDN)               : Powered down
       */
      i2c.write_reg(CS4384_ADDR, CS4384_MODE_CTRL, 0b11000001);

      uint8_t x;
      i2c_regop_res_t result;
      x = i2c.read_reg(CS4384_ADDR, CS4384_MODE_CTRL, result);
      printbinln(x);
      printintln(result);
      //uint8_t data[1];
      //      i2c.read(CS4384_ADDR, data, 1, 1);
      //      printbinln(data[0]);


      /* PCM Control (Address: 0x03) */
      /* bit[7:4] : Digital Interface Format (DIF) : 0b1100 for TDM
       * bit[3:2] : Reserved
       * bit[1:0] : Functional Mode (FM) : 0x11 for auto-speed detect (32 to 200kHz)
      */
      i2c.write_reg(CS4384_ADDR, CS4384_PCM_CTRL, 0b11000111);
      x = i2c.read_reg(CS4384_ADDR, CS4384_PCM_CTRL, result);
      printbinln(x);
      //      printintln(result);

      //      i2c.read(CS4384_ADDR, data, 1, 1);
      //      printbinln(data[0]);

      /* Mode Control 1 (Address: 0x02) */
      /* bit[7] : Control Port Enable (CPEN)     : Set to 1 for enable
       * bit[6] : Freeze controls (FREEZE)       : Set to 0 for freeze
       * bit[5] : PCM/DSD Selection (DSD/PCM)    : Set to 0 for PCM
       * bit[4:1] : DAC Pair Disable (DACx_DIS)  : All Dac Pairs enabled
       * bit[0] : Power Down (PDN)               : Not powered down
       */
      i2c.write_reg(CS4384_ADDR, CS4384_MODE_CTRL, 0b10000000);
      x = i2c.read_reg(CS4384_ADDR, CS4384_MODE_CTRL, result);
      printbinln(x);

      //      i2c.read(CS4384_ADDR, data, 1, 1);
      //      printbinln(data[0]);


      /* ADC out of reset */
      adc_reset.output(1);

      unsigned adc_dif = 0x02; // TDM mode
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
      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      restart = I2S_NO_RESTART;
      break;

    case i2s.receive(size_t index, int32_t sample):
      if (index == 0) {
        count++;
        if (count == 48000) {
          led_val = 1-led_val;
          //led.output(led_val);
          count = 0;
        }
      }
      samples[index] = sample;
      break;

    case i2s.send(size_t index) -> int32_t sample:
      sample = samples[index];
      break;
    }
  }
}


static char gpio_pin_map[3] = 
  {1, // dac reset
   2, // adc reset
   6  // clock select 
  };

int main() {
  interface i2s_callback_if i_i2s;
  interface i2c_master_if i_i2c[1];
  interface output_gpio_if i_gpio[3];
  interface output_gpio_if i_gpio_led[1]; 
  par {
    on tile[0]: {
      configure_clock_src_divide(clk1, p_mclk, 1);
      configure_port_clock_output(p_bclk, clk1); 
      tdm_master(i_i2s, p_fsync, p_dout, 4, p_din, 4, clk1);
    }

    on tile[0]: [[distribute]]
      tdm_loopback(i_i2s, i_i2c[0], i_gpio[0], i_gpio[1], i_gpio[2],
                   i_gpio_led[0]);

    on tile[0]: i2c_master_single_port(i_i2c, 1, p_i2c, 10, 0, 1, 0);

    on tile[0]: output_gpio(i_gpio, 3, p_gpio, gpio_pin_map);
    on tile[0]: par(int i=0;i<7;i++) while(1);
    on tile[1]: {p_led2 <: 0xf;output_gpio(i_gpio_led, 1, p_led1, null);}


  }
  return 0;
}
