// Copyright (c) 2014-2016, XMOS Ltd, All rights reserved
#ifndef _i2s_h_
#define _i2s_h_
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>

/** I2S mode.
 *
 *  This type is used to describe the I2S mode.
 */
typedef enum i2s_mode_t {
    I2S_MODE_I2S,            ///< The LR clock transitions ahead of the data by one bit clock.
    I2S_MODE_LEFT_JUSTIFIED, ///< The LR clock and data are phase aligned.
} i2s_mode_t;

/** I2S slave bit clock polarity.
 *
 *  Standard I2S is positive, that is toggle data and LR clock on falling
 *  edge of bit clock and sample them on rising edge of bit clock. Some
 *  masters have it the other way around.
 */
typedef enum i2s_slave_bclk_polarity_t {
    I2S_SLAVE_SAMPLE_ON_BCLK_RISING,   ///<< Toggle falling, sample rising (default if not set)
    I2S_SLAVE_SAMPLE_ON_BCLK_FALLING,  ///<< Toggle rising, sample falling
} i2s_slave_bclk_polarity_t;

/** I2S configuration structure.
 *
 *  This structure describes the configuration of an I2S bus.
 */
typedef struct i2s_config_t {
  unsigned mclk_bclk_ratio; ///< The ratio between the master clock and bit clock signals.
  i2s_mode_t mode;          ///< The mode of the LR clock.
  i2s_slave_bclk_polarity_t slave_bclk_polarity;  ///< Slave bit clock polarity.
} i2s_config_t;

/** TDM configuration structure.
 *
 *  This structure describes the configuration of a TDM bus.
 */
typedef struct tdm_config_t {
  int offset;               ///< The number of bits that the FSYNC signal transitions before the data. Must be a value between -31 and 31.
  unsigned sync_len;        ///< The length that the FSYNC signal stays high counted as ticks of the bit clock.
  unsigned channels_per_frame; ///< The number of channels in a TDM frame. This must be a power of 2.
} tdm_config_t;

/** Restart command type.
 *
 *  Restart commands that can be signalled to the I2S or TDM component.
 */
typedef enum i2s_restart_t {
  I2S_NO_RESTART = 0,      ///< Do not restart.
  I2S_RESTART,             ///< Restart the bus (causes the I2S/TDM to stop and a new init callback to occur allowing reconfiguration of the BUS).
  I2S_SHUTDOWN             ///< Shutdown. This will cause the I2S/TDM component to exit.
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
   *   \param i2s_config        This structure is provided if the connected
   *                            component drives an I2S bus. The members
   *                            of the structure should be set to the
   *                            required configuration.
   *   \param tdm_config        This structure is provided if the connected
   *                            component drives an TDM bus. The members
   *                            of the structure should be set to the
   *                            required configuration.
   */
  void init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config);

  /**  I2S restart check callback.
   *
   *   This callback is called once per frame. The application must return the
   *   required restart behaviour.
   *
   *   \return          The return value should be set to
   *                    ``I2S_NO_RESTART``, ``I2S_RESTART`` or
   *                    ``I2S_SHUTDOWN``.
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

#if defined(__XS2A__) || defined(__DOXYGEN__)

/** Interface representing callback events that can occur during the
 *   operation of the I2S task. This is specific to the frame-based
 *   I2S master task which uses hardware generation of BCLK and transfers
 *   samples as arrays rather than individual channels, resulting in much
 *   less senesitivity to back pressure in the send/recieve cases.
 *   This interface is supported on xCORE200 processors only.
 */
typedef interface i2s_frame_callback_if {

  /**  I2S frame-based initialization event callback.
   *
   *   The I2S component will call this
   *   when it first initializes on first run of after a restart.
   *
   *   \param i2s_config        This structure is provided if the connected
   *                            component drives an I2S bus. The members
   *                            of the structure should be set to the
   *                            required configuration.
   *   \param tdm_config        This structure is provided if the connected
   *                            component drives an TDM bus. The members
   *                            of the structure should be set to the
   *                            required configuration.
   */
  void init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config);

  /**  I2S frame-based restart check callback.
   *
   *   This callback is called once per frame. The application must return the
   *   required restart behaviour.
   *
   *   \return          The return value should be set to
   *                    ``I2S_NO_RESTART``, ``I2S_RESTART`` or
   *                    ``I2S_SHUTDOWN``.
   */
  i2s_restart_t restart_check();

  /**  Receive an incoming frame of samples.
   *
   *   This callback will be called when a new frame of samples is read in by the I2S
   *   frame-based component.
   *
   *  \param num_out    The number of input channels contained within the array.
   *  \param samples    The samples data array as signed 32-bit values.  The component
   *                    may not have 32-bits of accuracy (for example, many
   *                    I2S codecs are 24-bit), in which case the bottom bits
   *                    will be arbitrary values.
   */
  void receive(size_t num_in, int32_t samples[num_in]);

  /** Request an outgoing frame of samples.
   *
   *  This callback will be called when the I2S frame-based component needs
   *  a new frame of samples.
   *
   *  \param num_out    The number of output channels contained within the array.
   *  \param samples    The samples data array as signed 32-bit values.  The component
   *                    may not have 32-bits of accuracy (for example, many
   *                    I2S codecs are 24-bit), in which case the bottom bits
   *                    will be arbitrary values.
   */
  void send(size_t num_out, int32_t samples[num_out]);

} i2s_frame_callback_if;

#endif // __XS2A__

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
                out buffered port:32 (&?p_dout)[num_out],
                static const size_t num_out,
                in buffered port:32 (&?p_din)[num_in],
                static const size_t num_in,
                out buffered port:32 p_bclk,
                out buffered port:32 p_lrclk,
                clock bclk,
                const clock mclk);

#if defined(__XS2A__) || defined(__DOXYGEN__)

/** I2S frame-based master component **for xCORE200 only**
 *
 *  This task performs I2S on the provided pins. It will perform callbacks over
 *  the i2s_frame_callback_if interface to get/receive frames of data from the
 *  application using this component.
 *
 *  The component performs I2S master so will drive the word clock and
 *  bit clock lines.
 *
 *  \param i2s_i          The I2S frame callback interface to connect to
 *                        the application
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param p_bclk         The bit clock output port
 *  \param p_lrclk        The word clock output port
 *  \param p_mclk         Input port which supplies the master clock
 *  \param bclk           A clock that will get configured for use with
 *                        the bit clock
 */
void i2s_frame_master(client i2s_frame_callback_if i2s_i,
                out buffered port:32 (&?p_dout)[num_out],
                static const size_t num_out,
                in buffered port:32 (&?p_din)[num_in],
                static const size_t num_in,
                out port p_bclk,
                out buffered port:32 p_lrclk,
                in port p_mclk,
                clock bclk);

#endif // __XS2A__

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
        out buffered port:32 (&?p_dout)[num_out],
        static const size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        static const size_t num_in,
        in port p_bclk,
        in buffered port:32 p_lrclk,
        clock bclk);

/** TDM master component.
 *
 *  This task performs TDM on the provided pins. It will perform callbacks over
 *  the i2s_callback_if interface to get/receive data from the application
 *  using this component.
 *
 *  The component performs as TDM master so will drive the fsync signal.
 *
 *  \param tdm_i          The TDM callback interface to connect to
 *                        the application
 *  \param p_fsync        The frame sync output port
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param clk            The clock connected to the bit/master clock frequency.
 *                        Usually this should be configured to be driven by
 *                        an incoming master system clock.
 */
void tdm_master(client interface i2s_callback_if tdm_i,
        out buffered port:32 p_fsync,
        out buffered port:32 (&?p_dout)[num_out],
        size_t num_out,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        clock clk);

/** I2S master + TDM master component.
 *
 *  This task performs I2S and TDM
 *  on the provided pins. The signals need to be synchronized.
 *  It will perform callbacks over
 *  the i2s_callback_if interface to get/receive data from the application
 *  using this component.
 *
 *  The component assumes that the bit clock of the TDM signal is the
 *  same as the master clock of the I2S signal.
 *
 *  The component performs I2S master so will drive the word clock and
 *  bit clock lines. It will also acts as TDM master and drives the fsync
 *  signal.
 *
 *  \param tdm_i          The TDM callback interface to connect to
 *                        the application
 *  \param i2s_dout       An array of I2S data output ports
 *  \param num_i2s_out    The number of I2S output data ports
 *  \param i2s_din        An array of I2S data input ports
 *  \param num_i2s_in     The number of I2S input data ports
 *  \param i2s_bclk       The I2S bit clock output port
 *  \param i2s_lrclk      The I2S word clock output port
 *  \param tdm_fsync      The TDM frame sync output port
 *  \param tdm_dout       An array of TDM data output ports
 *  \param num_tdm_out    The number of TDM output data ports
 *  \param tdm_din        An array of TDM data input ports
 *  \param num_tdm_in     The number of TDM input data ports
 *  \param bclk           A clock that will get configured for use with
 *                        the I2S bit clock
 *  \param mclk           The clock connected to the master clock frequency.
 *                        Usually this should be configured to be driven by
 *                        an incoming master system clock. This clock is also
 *                        used as the TDM bit clock.
 */
void i2s_tdm_master(client interface i2s_callback_if tdm_i,
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
        clock bclk,
        clock mclk);

#include <i2s_master_impl.h>
#include <i2s_frame_master_impl.h>
#include <i2s_slave_impl.h>
#include <tdm_master_impl.h>
#include <i2s_tdm_master_impl.h>

#endif // _i2s_h_
