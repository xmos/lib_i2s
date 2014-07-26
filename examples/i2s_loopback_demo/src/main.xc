#include <xs1.h>
#include <i2s.h>
#include <audio_codec.h>
#include <i2c.h>
#include <gpio.h>

/* Ports and clocks used by the application */
out buffered port:32 p_dout[4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
in buffered port:32 p_din[4]  = {XS1_PORT_1I, XS1_PORT_1K, XS1_PORT_1L, XS1_PORT_1N};

port p_mclk  = XS1_PORT_1M;
port p_bclk  = XS1_PORT_1A;
port p_lrclk = XS1_PORT_1C;

port p_sda = XS1_PORT_1O;
port p_scl = XS1_PORT_1P;

port p_gpio = XS1_PORT_8D;

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;

[[distributable]]
static void i2s_loopback(server i2s_callback_if i2s,
                         client audio_codec_config_if codec)
{
  int32_t samples[8];
  while (1) {
    select {
    case i2s.init(unsigned &sample_frequency, unsigned &master_clock_frequency):
      codec.reset(sample_frequency, master_clock_frequency);
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

#define SAMPLE_FREQUENCY 48000
#define MASTER_CLOCK_FREQUENCY 24576000

static unsigned gpio_pin_map[2] = {0, 1};

int main() {
  interface i2s_callback_if i_i2s;
  interface audio_codec_config_if i_codec;
  interface i2c_master_if i_i2c[1];
  interface output_gpio_if i_gpio[2];
  configure_clock_src(mclk, p_mclk);
  start_clock(mclk);
  par {
    /* System setup, I2S + Codec control over I2C */
    i2s_master(i_i2s, p_dout, 4, p_din, 4,
               p_bclk, p_lrclk, bclk, mclk,
               SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY);
    audio_codec_cs4720(i_codec, i_i2c[0], i_gpio[0], i_gpio[1]);
    i2c_master(i_i2c, 1, p_sda, p_scl, 100000, I2C_DISABLE_MULTIMASTER);
    multibit_output_gpio(i_gpio, 2, gpio_pin_map, p_gpio);

    /* The application - loopback the I2S samples */
    i2s_loopback(i_i2s, i_codec);
  }
  return 0;
}
