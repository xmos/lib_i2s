#ifndef _i2s_h_
#define _i2s_h_
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>

typedef enum i2s_mode {
    I2S_MODE_I2S,            //Use this for when the LR clock is ahead of the data by one bit clock.
    I2S_MODE_LEFT_JUSTIFIED, //Use this for when the data and LR clock are phase aligned.
} i2s_mode;

typedef struct i2s_config_t {
  unsigned mclk_bclk_ratio;
  i2s_mode mode;
} i2s_config_t;

typedef struct tdm_config_t {
  int offset;
  unsigned sync_len;
  unsigned channels_per_frame;
} tdm_config_t;

typedef enum i2s_restart_t {
  I2S_NO_RESTART = 0,
  I2S_RESTART,
  I2S_SHUTDOWN
} i2s_restart_t;

/** Interface representing callback events that can occur during the
 *   operation of the I2S task
 */
typedef interface i2s_callback_if {

  /**  I2S initialization event callback.
   *
   *   The I2S component will call this
   *   when it first initializes on first run of after a restart.
   *
   *   \param mclk_bclk_ratio          This should be set to the desired master
   *                                   clock to bit clock ratio(must be a power
   *                                   of two thats greater than or equal to two
   *                                   and less than or equal to 32.
   *   \param mode                     The transfer mode (I2S_MODE_I2S,
   *                                   I2S_MODE_LEFT_JUSTIFIED). 
   */
  void init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config);

  /**  I2S frame start callback.
   *
   *   The I2S component will call this when a frame starts before the samples
   *   are input/output. If restart is set to non-zero then then current frame will
   *   be the last.
   *
   *   \param timestamp                The time (relative to the XS1 reference
   *                                   frequency) of the start of the frame.
   *   \param restart                  Setting this reference parameter to
   *                                   non-zero will cause the I2S component
   *                                   to restart.
   */
  i2s_restart_t restart_check();

  /**  Receive an incoming sample.
   *
   *   This callback will be called when a new sample is read in by the I2S
   *   component.
   *
   *   \param index     The index of the sample in the frame.
   *   \param sample    The sample data as a signed 32-bit value. The component
   *                    may not use all 32 bits of the value (for example, many
   *                    I2S codecs are 24-bit), in which case the bottom bits
   *                    are ignored.
   */
  void receive(size_t index, int32_t sample);

  /** Request an outgoing sample.
   *
   *  This callback will be called when the I2S component needs a new sample.
   *
   *  \param index      The index of the requested sample in the frame.
   *  \returns          The sample data as a signed 32-bit value.  The component
   *                    may not have 32-bits of accuracy (for example, many
   *                    I2S codecs are 24-bit), in which case the bottom bits
   *                    will be arbitrary values.
   */
  int32_t send(size_t index);

} i2s_callback_if;

/** I2S master component.
 *
 *  This task performs I2S on the provided pins. It will perform callbacks over
 *  the i2s_callback_if interface to get/receive data from the application
 *  using this component.
 *
 *  The component performs I2S master so will drive the word clock and
 *  bit clock lines.
 *
 *  \param i2s_i          The I2S callback interface to connect to
 *                        the application
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param p_bclk         The bit clock output port
 *  \param p_lrclk        The word clock output port
 *  \param bclk           A clock that will get configured for use with
 *                        the bit clock
 *  \param mclk           The clock connected to the master clock frequency.
 *                        Usually this should be configured to be driven by
 *                        an incoming master system clock.
 */
void i2s_master(client i2s_callback_if i2s_i,
                out buffered port:32 p_dout[num_out],
                static const size_t num_out,
                in buffered port:32 p_din[num_in],
                static const size_t num_in,
                out buffered port:32 p_bclk,
                out buffered port:32 p_lrclk,
                clock bclk,
                const clock mclk);

/** I2S slave component.
 *
 *  This task performs I2S on the provided pins. It will perform callbacks over
 *  the i2s_callback_if interface to get/receive data from the application
 *  using this component.
 *
 *  The component performs I2S slave so will expect the word clock and
 *  bit clock to be driven externally.
 *
 *  \param i2s_i          The I2S callback interface to connect to
 *                        the application
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param p_bclk         The bit clock input port
 *  \param p_lrclk        The word clock input port
 *  \param bclk           A clock that will get configured for use with
 *                        the bit clock
 */
void i2s_slave(client i2s_callback_if i2s_i,
        out buffered port:32 p_dout[num_out],
        static const size_t num_out,
        in buffered port:32 p_din[num_in],
        static const size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk);

void tdm_master(client interface i2s_callback_if tdm_i,
        out buffered port:32 p_fsync,
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
        size_t num_in,
        clock clk);

void i2s_tdm_master(client interface i2s_callback_if i,
        out buffered port:32 i2s_dout[num_i2s_out],
        static const size_t num_i2s_out,
        in buffered port:32 i2s_din[num_i2s_in],
        static const size_t num_i2s_in,
        out buffered port:32 i2s_bclk,
        out buffered port:32 i2s_lrclk,
        out buffered port:32 tdm_fsync,
        out buffered port:32 tdm_dout[num_tdm_out],
        size_t num_tdm_out,
        in buffered port:32 tdm_din[num_tdm_in],
        size_t num_tdm_in,
        clock clk_bclk,
        clock clk_mclk);

#include <i2s_master_impl.h>
#include <i2s_slave_impl.h>
#include <tdm_master_impl.h>
#include <i2s_tdm_master_impl.h>

#endif // _i2s_h_
