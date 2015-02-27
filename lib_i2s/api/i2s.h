#ifndef _i2s_h_
#define _i2s_h_
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>

typedef enum {
    e_i2s_mode,
    e_left_justified,
    e_right_justified,
} i2s_mode;

/** Interface representing callback events that can occur during the
 *   operation of the I2S task
 */
typedef interface i2s_callback_if {

  /**  I2S initialization event callback.
   *
   *   The I2S component will call this
   *   when it first initializes on first run of after a restart.
   *
   *   \param mclk_bclk_ratio_log2     This should be set to the desired master
   *                                   clock to bit clock ratio(must be a power
   *                                   of two thats greater then or equal to two
   *                                   and less than or euqal to 32.
   *   \param mode                     The transfer mode(i2s, left justified,
   *                                   right justified)
   */
  void init(unsigned &mclk_bclk_ratio, i2s_mode &mode);

  /**  I2S frame start callback.
   *
   *   The I2S component will call this when a frame starts before the samples
   *   are input/output.
   *
   *   \param timestamp                The time (relative to the XS1 reference
   *                                   frequency) of the start of the frame
   *   \param restart                  Setting this reference parameter to
   *                                   non-zero will cause the I2S component
   *                                   to restart.
   */
  void frame_start(unsigned timestamp, unsigned &restart);

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
 *  \param i              The I2S callback interface to connect to
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
void i2s_master(client i2s_callback_if i,
                out buffered port:32 p_dout[num_out],
                size_t num_out,
                in buffered port:32 p_din[num_in],
                size_t num_in,
                out buffered port:32 p_bclk,
                out buffered port:32 p_lrclk,
                clock bclk,
                const clock mclk);
/** Interface representing callback events that can occur during the
 *   operation of the I2S task
 */
typedef interface i2s_slave_callback_if {

  /**  I2S initialization event callback.
   *
   *   The I2S component will call this
   *   when it first initializes on first run of after a restart.
   *
   *   \param mclk_bclk_ratio_log2     This should be set to the desired master
   *                                   clock to bit clock ratio(must be a power
   *                                   of two thats greater then or equal to two
   *                                   and less than or euqal to 32.
   *   \param mode                     The transfer mode(i2s, left justified,
   *                                   right justified)
   */
  void init(i2s_mode &mode);

  /**  I2S frame start callback.
   *
   *   The I2S component will call this when a frame starts before the samples
   *   are input/output.
   *
   *   \param timestamp                The time (relative to the XS1 reference
   *                                   frequency) of the start of the frame
   *   \param restart                  Setting this reference parameter to
   *                                   non-zero will cause the I2S component
   *                                   to restart.
   */
  void frame_start(unsigned timestamp, unsigned &restart);

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

} i2s_slave_callback_if;
/** I2S slave component.
 *
 *  This task performs I2S on the provided pins. It will perform callbacks over
 *  the i2s_callback_if interface to get/receive data from the application
 *  using this component.
 *
 *  The component performs I2S slave so will expect the word clock and
 *  bit clock to be driven externally.
 *
 *  \param i              The I2S callback interface to connect to
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
void i2s_slave(client i2s_slave_callback_if i,
        out buffered port:32 p_dout[num_out],
        size_t num_out,
        in buffered port:32 p_din[num_in],
        size_t num_in,
        in port p_bclk,
        in port p_lrclk,
        clock bclk);

#endif // _i2s_h_
