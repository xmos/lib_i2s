#include <xs1.h>
#include <i2s.h>
#include <print.h>
#include <syscall.h>

#define NUM_TEST_EVENTS (4)

/* Ports and clocks used by the application */
out buffered port:32 p_dout[4] = {XS1_PORT_1D, XS1_PORT_1E, XS1_PORT_1F, XS1_PORT_1G};
in buffered port:32 p_din[4]  = {XS1_PORT_1I, XS1_PORT_1K, XS1_PORT_1L, XS1_PORT_1N};

in port p_mclk  = XS1_PORT_1M;
out buffered port:32 p_bclk  = XS1_PORT_1A;
out buffered port:32 p_lrclk = XS1_PORT_1C;

clock mclk = XS1_CLKBLK_1;
clock bclk = XS1_CLKBLK_2;

out port p_trigger = XS1_PORT_1B;

void i2s_loopback(server i2s_callback_if i2s)
{
  int32_t samples[8];
  unsigned int num_events = 0;
  p_trigger <: 0;
  do {
    select {
    case i2s.init(unsigned &sample_frequency, unsigned &master_clock_frequency):
      // Nothing to do on i2s init
      printstr("Sample Frequency = "); printintln(sample_frequency);
      printstr("Master Clock Frequency = "); printintln(master_clock_frequency);
      break;

    case i2s.frame_start(unsigned timestamp, unsigned &restart):
      // Nothing to do on frame start
      num_events++;
      break;

    case i2s.receive(size_t index, int32_t sample):
      samples[index] = sample;
      //printstr("Rx: ");printhexln(sample);
      break;

    case i2s.send(size_t index) -> int32_t sample:
      sample = samples[index];
      printstr("Tx: ");printhexln(sample);
      break;
    }
    
    if (num_events > NUM_TEST_EVENTS) {
      //printstrln("num events reached");
      p_trigger <: 1;
      _exit(0);
    }
    
  } while (1);
};


int main() {
  interface i2s_callback_if i_i2s;
  configure_clock_src(mclk, p_mclk);
  start_clock(mclk);
  par {
    /* System setup, I2S + Codec control over I2C */
    i2s_master(i_i2s, p_dout, 4, p_din, 4,
               p_bclk, p_lrclk, bclk, mclk,
               SAMPLE_FREQUENCY, MASTER_CLOCK_FREQUENCY);

    /* The application - loopback the I2S samples */
    i2s_loopback(i_i2s);
  }
  return 0;
}
