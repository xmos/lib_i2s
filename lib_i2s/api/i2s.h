// Copyright 2014-2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef _i2s_h_
#define _i2s_h_
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>
#include <xccompat.h>

// These are needed for DOXYGEN to render properly
#ifndef __DOXYGEN__
#define static_const_size_t static const size_t
#define in_port_t in port
#define out_port_t out port
#endif

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
  unsigned slave_frame_synch_error;///< Set if I2S slave restarted because of a frame synch error. No meaning for master.
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
 *  operation of the I2S task. This is a more efficient interface
 *  and reccomended for new designs.
 */
#ifndef __DOXYGEN__
typedef interface i2s_frame_callback_if {
#endif
  /**
   * \addtogroup i2s_frame_callback_if
   * @{
   */

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
  void init(NULLABLE_REFERENCE_PARAM(i2s_config_t, i2s_config), NULLABLE_REFERENCE_PARAM(tdm_config_t, tdm_config));

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
   *  \param num_in     The number of input channels contained within the array.
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


/**@}*/ // END: addtogroup i2s_frame_callback_if

#ifndef __DOXYGEN__
} i2s_frame_callback_if;

/** Interface representing callback events that can occur during the
 *   operation of the TDM task
 */
typedef interface tdm_callback_if {
#endif // __DOXYGEN__


  /**
   * \addtogroup tdm_callback_if
   * @{
   */

  /**  TDM initialization event callback.
   *
   *   The TDM component will call this
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
  void init(NULLABLE_REFERENCE_PARAM(i2s_config_t, i2s_config), NULLABLE_REFERENCE_PARAM(tdm_config_t, tdm_config));

  /**  TDM restart check callback.
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
   *   This callback will be called when a new sample is read in by the TDM
   *   component.
   *
   *   \param index     The index of the sample in the frame.
   *   \param sample    The sample data as a signed 32-bit value. 
   */
  void receive(size_t index, int32_t sample);

  /** Request an outgoing sample.
   *
   *  This callback will be called when the TDM component needs a new sample.
   *
   *  \param index      The index of the requested sample in the frame.
   *  \returns          The sample data as a signed 32-bit value.
   */
  int32_t send(size_t index);

/**@}*/ // END: addtogroup tdm_callback_if


#ifndef __DOXYGEN__
} tdm_callback_if;
#endif // __DOXYGEN__


/** I2S frame-based master component **for xCORE200 and xcore.ai only**
 *
 *  This task performs I2S on the provided pins. It will perform callbacks over
 *  the i2s_frame_callback_if interface to get/receive frames of data from the
 *  application using this component.
 *
 *  The component performs I2S master so will drive the word clock and
 *  bit clock lines.
 *
 *  This is a more efficient version of i2s master which reduces callback
 *  frequency and allows useful processing to be done in distributable i2s handler tasks.
 *  It also uses xCORE200 and xcore.ai specific features to remove the need for software
 *  BCLK generation which decreases processor overhead.
 *
 *  \param i2s_i          The I2S frame callback interface to connect to
 *                        the application
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param num_data_bits  The number of bits per data word
 *  \param p_bclk         The bit clock output port
 *  \param p_lrclk        The word clock output port
 *  \param p_mclk         Input port which supplies the master clock
 *  \param bclk           A clock that will get configured for use with
 *                        the bit clock
 */
void i2s_frame_master(
                CLIENT_INTERFACE(i2s_frame_callback_if, i2s_i),
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                static_const_size_t num_data_bits,
                out_port_t p_bclk,
                out_buffered_port_32_t p_lrclk,
                in_port_t p_mclk,
                clock bclk);

/** I2S frame-based master component with 4-bit ports **for xCORE200 and xcore.ai only**
 *
 *  This task performs I2S on the provided 4-bit ports. It will perform callbacks over
 *  the i2s_frame_callback_if interface to get/receive frames of data from the
 *  application using this component.
 *
 *  The component performs I2S master so will drive the word clock and
 *  bit clock lines.
 *
 *  This is a more efficient version of i2s master which reduces callback
 *  frequency and allows useful processing to be done in distributable i2s handler tasks.
 *  It also uses xCORE200 and xcore.ai specific features to remove the need for software
 *  BCLK generation which decreases processor overhead.
 *
 *  This component can only operate with a 32-bit data word length.
 *
 *  \param i2s_i          The I2S frame callback interface to connect to
 *                        the application
 *  \param p_dout         A 4-bit data output port
 *  \param num_out        The number of output data streams
 *  \param p_din          A 4-bit data input port
 *  \param num_in         The number of input data streams
 *  \param p_bclk         The bit clock output port
 *  \param p_lrclk        The word clock output port
 *  \param p_mclk         Input port which supplies the master clock
 *  \param bclk           A clock that will get configured for use with
 *                        the bit clock
 */
void i2s_frame_master_4b(CLIENT_INTERFACE(i2s_frame_callback_if, i2s_i),
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                out_port_t p_bclk,
                out_buffered_port_32_t p_lrclk,
                in_port_t p_mclk,
                clock bclk);

/** I2S frame-based master component **for xCORE200 and xcore.ai only**
 *
 *  This task performs I2S on the provided pins. It will perform callbacks over
 *  the i2s_frame_callback_if interface to get/receive frames of data from the
 *  application using this component.
 *
 *  The component performs I2S master so will drive the word clock and
 *  bit clock lines.
 *
 *  This is a more efficient version of i2s master which reduces callback
 *  frequency and allows useful processing to be done in distributable i2s handler tasks.
 *  It also uses xCORE200 and xcore.ai specific features to remove the need for software
 *  BCLK generation which decreases processor overhead.
 *
 *  \param i2s_i          The I2S frame callback interface to connect to
 *                        the application
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param num_data_bits  The number of bits per data word
 *  \param p_bclk         The bit clock output port
 *  \param p_lrclk        The word clock output port
 *  \param bclk           A clock that is configured externally to be used as the bit clock
 *                        
 */
void i2s_frame_master_external_clock(CLIENT_INTERFACE(i2s_frame_callback_if, i2s_i),
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                static_const_size_t num_data_bits,
                out_port_t p_bclk,
                out_buffered_port_32_t p_lrclk,
                in_port_t p_mclk,
                clock bclk);

/** I2S frame-based master component with 4-bit ports **for xCORE200 amd xcore.ai only**
 *
 *  This task performs I2S on the provided 4-bit ports. It will perform callbacks over
 *  the i2s_frame_callback_if interface to get/receive frames of data from the
 *  application using this component.
 *
 *  The component performs I2S master so will drive the word clock and
 *  bit clock lines.
 *
 *  This is a more efficient version of i2s master which reduces callback
 *  frequency and allows useful processing to be done in distributable i2s handler tasks.
 *  It also uses xCORE200 and xcore.ai specific features to remove the need for software
 *  BCLK generation which decreases processor overhead.
 *
 *  This component can only operate with a 32-bit data word length.
 *
 *  \param i2s_i          The I2S frame callback interface to connect to
 *                        the application
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param p_bclk         The bit clock output port
 *  \param p_lrclk        The word clock output port
 *  \param bclk           A clock that will get configured for use with
 *                        the bit clock
 */
void i2s_frame_master_external_clock_4b(CLIENT_INTERFACE(i2s_frame_callback_if, i2s_i),
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                out_port_t p_bclk,
                out_buffered_port_32_t p_lrclk,
                in_port_t p_mclk,
                clock bclk);

/** I2S High Efficiency slave component.
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
 *  \param num_data_bits  The number of bits per data word
 *  \param p_bclk         The bit clock input port
 *  \param p_lrclk        The word clock input port
 *  \param bclk           A clock that will get configured for use with
 *                        the bit clock
 */
void i2s_frame_slave(CLIENT_INTERFACE(i2s_frame_callback_if, i2s_i),
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                static_const_size_t num_data_bits,
                in_port_t p_bclk,
                in_buffered_port_32_t p_lrclk,
                clock bclk);

/** I2S High Efficiency slave component.
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
void i2s_frame_slave_4b(CLIENT_INTERFACE(i2s_frame_callback_if, i2s_i),
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                out_port_t p_bclk,
                out_buffered_port_32_t p_lrclk,
                clock bclk);

/** TDM master component.
 *
 *  This task performs TDM on the provided pins. It will perform callbacks over
 *  the tdm_callback_if interface to get/receive data from the application
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
void tdm_master(CLIENT_INTERFACE(tdm_callback_if, tdm_i),
                out_buffered_port_32_t p_fsync,
                NULLABLE_ARRAY_OF_SIZE(out_buffered_port_32_t, p_dout, num_out),
                static_const_size_t num_out,
                NULLABLE_ARRAY_OF_SIZE(in_buffered_port_32_t, p_din, num_in),
                static_const_size_t num_in,
                clock clk);


#include <i2s_frame_master_impl.h>
#include <i2s_frame_master_4b_impl.h>
#include <i2s_frame_slave_impl.h>
#include <i2s_frame_slave_4b_impl.h>
#include <tdm_master_impl.h>

#endif // _i2s_h_
