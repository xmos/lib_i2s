#include <xs1.h>
#include <i2s.h>
#include <i2c.h>
#include <gpio.h>
#include <print.h>

/* Ports and clocks used by the application */
out buffered port:32 p_dout[4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
in buffered port:32 p_din[4]  = {XS1_PORT_1I, XS1_PORT_1K, XS1_PORT_1L, XS1_PORT_1N};

in port p_mclk  = XS1_PORT_1M;
out buffered port:32 p_bclk  = XS1_PORT_1A;
out buffered port:32 p_lrclk = XS1_PORT_1C;

port p_sda = XS1_PORT_1O;
port p_scl = XS1_PORT_1P;

port p_gpio = XS1_PORT_8D;

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;

#define SAMPLE_FREQUENCY 48000
#define MASTER_CLOCK_FREQUENCY 24576000
#define CODEC_I2C_DEVICE_ADDR 0x48

#define MCLK_FREQUENCY_48  24576000
#define MCLK_FREQUENCY_441 22579200

enum codec_mode_t {
  CODEC_IS_I2S_MASTER,
  CODEC_IS_I2S_SLAVE
};

#define CODEC_DEV_ID_ADDR           0x01
#define CODEC_PWR_CTRL_ADDR         0x02
#define CODEC_MODE_CTRL_ADDR        0x03
#define CODEC_ADC_DAC_CTRL_ADDR     0x04
#define CODEC_TRAN_CTRL_ADDR        0x05
#define CODEC_MUTE_CTRL_ADDR        0x06
#define CODEC_DACA_VOL_ADDR         0x07
#define CODEC_DACB_VOL_ADDR         0x08

void cs4270_reset(client i2c_master_if i2c, uint8_t device_addr,
                 unsigned sample_frequency, unsigned master_clock_frequency,
                 enum codec_mode_t codec_mode)
{
  /* Set power down bit in the CODEC over I2C */
  i2c.write_reg(device_addr, CODEC_DEV_ID_ADDR, 0x01);

  /* Now set all registers as we want them */


  if (codec_mode == CODEC_IS_I2S_SLAVE) {
    /* Mode Control Reg:
       Set FM[1:0] as 11. This sets Slave mode.
       Set MCLK_FREQ[2:0] as 010. This sets MCLK to 512Fs in Single,
       256Fs in Double and 128Fs in Quad Speed Modes.
       This means 24.576MHz for 48k and 22.5792MHz for 44.1k.
       Set Popguard Transient Control.
       So, write 0x35. */
    i2c.write_reg(device_addr, CODEC_MODE_CTRL_ADDR, 0x35);
  } else {
    /* In master mode (i.e. Xcore is I2S slave) to avoid contention
       configure one CODEC as master one the other as slave */

    /* Set FM[1:0] Based on Single/Double/Quad mode
       Set MCLK_FREQ[2:0] as 010. This sets MCLK to 512Fs in Single, 256Fs in Double and 128Fs in Quad Speed Modes.
       This means 24.576MHz for 48k and 22.5792MHz for 44.1k.
       Set Popguard Transient Control.*/

    unsigned char val = 0b0101;

    if(sample_frequency < 54000) {
      // | with 0..
    } else if(sample_frequency < 108000) {
      val |= 0b00100000;
    } else  {
      val |= 0b00100000;
    }
    i2c.write_reg(device_addr, CODEC_MODE_CTRL_ADDR, val);
  }

  /* ADC & DAC Control Reg:
     Leave HPF for ADC inputs continuously running.
     Digital Loopback: OFF
     DAC Digital Interface Format: I2S
     ADC Digital Interface Format: I2S
     So, write 0x09. */
  i2c.write_reg(device_addr, CODEC_ADC_DAC_CTRL_ADDR, 0x09);

  /* Transition Control Reg:
     No De-emphasis. Don't invert any channels.
     Independent vol controls. Soft Ramp and Zero Cross enabled.*/
  i2c.write_reg(device_addr, CODEC_TRAN_CTRL_ADDR, 0x60);

  /* Mute Control Reg: Turn off AUTO_MUTE */
  i2c.write_reg(device_addr, CODEC_MUTE_CTRL_ADDR, 0x00);

  /* DAC Chan A Volume Reg:
     We don't require vol control so write 0x00 (0dB) */
  i2c.write_reg(device_addr, CODEC_DACA_VOL_ADDR, 0x00);

  /* DAC Chan B Volume Reg:
     We don't require vol control so write 0x00 (0dB)  */
  i2c.write_reg(device_addr, CODEC_DACB_VOL_ADDR, 0x00);

  /* Clear power down bit in the CODEC over I2C */
  i2c.write_reg(device_addr, CODEC_PWR_CTRL_ADDR, 0x00);
}



[[distributable]]
void i2s_loopback(server i2s_callback_if i2s,
                         client i2c_master_if i2c,
                         client output_gpio_if codec_reset,
                         client output_gpio_if clock_select)
{
  int32_t samples[8];
  while (1) {
    select {
    case i2s.init(unsigned & mclk_bclk_ratio, i2s_mode & mode):
      /* Set CODEC in reset */
      codec_reset.output(0);

      mode = I2S_MODE_I2S;

      /* Set master clock select appropriately */
      mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/SAMPLE_FREQUENCY)/64;

      if ((SAMPLE_FREQUENCY % 22050) == 0) {
        clock_select.output(0);
      }else {
        clock_select.output(1);
      }

      /* Hold in reset for 2ms while waiting for MCLK to stabilise */
      delay_milliseconds(2);

      /* CODEC out of reset */
      codec_reset.output(1);

      cs4270_reset(i2c, CODEC_I2C_DEVICE_ADDR,
              SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY,
                   CODEC_IS_I2S_SLAVE);
      break;

    case i2s.frame_start(unsigned timestamp, unsigned &restart):
      // Nothing to do on frame start
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


static char gpio_pin_map[2] = {2, 1};

int main() {
  interface i2s_callback_if i_i2s;
  interface i2c_master_if i_i2c[1];
  interface output_gpio_if i_gpio[2];
  configure_clock_src(mclk, p_mclk);
  start_clock(mclk);
  par {
    /* System setup, I2S + Codec control over I2C */
    i2s_master(i_i2s, p_dout, 4, p_din, 4,
               p_bclk, p_lrclk, bclk, mclk);
    i2c_master(i_i2c, 1, p_sda, p_scl, 100000);
    output_gpio(i_gpio, 2, p_gpio, gpio_pin_map);

    /* The application - loopback the I2S samples */
    [[distribute]]i2s_loopback(i_i2s, i_i2c[0], i_gpio[0], i_gpio[1]);
  }
  return 0;
}
