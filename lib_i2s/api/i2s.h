// Copyright (c) 2014-2020, XMOS Ltd, All rights reserved
#ifndef _i2s_h_
#define _i2s_h_
#include <xs1.h>
#include <stdint.h>
#include <stddef.h>
#include <xcore/port.h>
#include <xcore/clock.h>

#define I2S_MAX_DATALINES 8

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

/** Restart command type.
 *
 *  Restart commands that can be signalled to the I2S or TDM component.
 */
typedef enum i2s_restart_t {
  I2S_NO_RESTART = 0,      ///< Do not restart.
  I2S_RESTART,             ///< Restart the bus (causes the I2S/TDM to stop and a new init callback to occur allowing reconfiguration of the BUS).
  I2S_SHUTDOWN             ///< Shutdown. This will cause the I2S/TDM component to exit.
} i2s_restart_t;

#define I2S_CALLBACK_ATTR __attribute__((fptrgroup("i2s_callback")))

/**
 * I2S initialization event callback.
 *
 * The I2S component will call this
 * when it first initializes on first run of after a restart.
 *
 * \param app_data    Points to application specific data supplied
 *                    by the application. May be used for context
 *                    data specific to each I2S task instance.
 *
 * \param i2s_config  This structure is provided if the connected
 *                    component drives an I2S bus. The members
 *                    of the structure should be set to the
 *                    required configuration.
 */
typedef void (*i2s_init_t)(void *app_data, i2s_config_t *i2s_config);

/**
 * I2S restart check callback.
 *
 * This callback is called once per frame. The application must return the
 * required restart behavior.
 *
 * \param app_data  Points to application specific data supplied
 *                  by the application. May be used for context
 *                  data specific to each I2S task instance.
 *
 * \return          The return value should be set to
 *                  ``I2S_NO_RESTART``, ``I2S_RESTART`` or
 *                  ``I2S_SHUTDOWN``.
 */
typedef i2s_restart_t (*i2s_restart_check_t)(void *app_data);

/**
 * Receive an incoming frame of samples.
 *
 * This callback will be called when a new frame of samples is read in by the I2S
 * task.
 *
 * \param app_data  Points to application specific data supplied
 *                  by the application. May be used for context
 *                  data specific to each I2S task instance.
 *
 * \param num_in    The number of input channels contained within the array.
 *
 * \param samples   The samples data array as signed 32-bit values.  The component
 *                  may not have 32-bits of accuracy (for example, many
 *                  I2S codecs are 24-bit), in which case the bottom bits
 *                  will be arbitrary values.
 */
typedef void (*i2s_receive_t)(void *app_data, size_t num_in, const int32_t *samples);

/**
 * Request an outgoing frame of samples.
 *
 * This callback will be called when the I2S task needs a new frame of samples.
 *
 * \param app_data  Points to application specific data supplied
 *                  by the application. May be used for context
 *                  data specific to each I2S task instance.
 *
 * \param num_out   The number of output channels contained within the array.
 *
 * \param samples   The samples data array as signed 32-bit values.  The component
 *                  may not have 32-bits of accuracy (for example, many
 *                  I2S codecs are 24-bit), in which case the bottom bits
 *                  will be arbitrary values.
 */
typedef void (*i2s_send_t)(void *app_data, size_t num_out, int32_t *samples);

/**
 * Callback group representing callback events that can occur during the
 * operation of the I2S task. Must be initialized by the application prior
 * to passing it to one of the I2S tasks.
 */
typedef struct {
    I2S_CALLBACK_ATTR i2s_init_t init; ///< Pointer to the init function.
    I2S_CALLBACK_ATTR i2s_restart_check_t restart_check; ///< Pointer to the restart check function.
    I2S_CALLBACK_ATTR i2s_receive_t receive; ///< Pointer to the receive function.
    I2S_CALLBACK_ATTR i2s_send_t send; ///< Pointer to the send function.
    void *app_data; ///< Pointer to application specific data which is passed to each callback.
} i2s_callback_group_t;


/** I2S master task
 *
 *  This task performs I2S on the provided pins. It will perform callbacks over
 *  the i2s_callback_group_t callback group to get/receive frames of data from the
 *  application using this component.
 *
 *  The task performs I2S master so will drive the word clock and
 *  bit clock lines.
 *
 *  \param i2s_cbg        The I2S callback group pointing to the application's
 *                        functions to use for initialization and getting and receiving
 *                        frames. Also points to application specific data which will
 *                        be shared between the callbacks.
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
void i2s_master(
        const i2s_callback_group_t *const i2s_cbg,
        const port_t p_dout[],
        const size_t num_out,
        const port_t p_din[],
        const size_t num_in,
        const port_t p_bclk,
        const port_t p_lrclk,
        const port_t p_mclk,
        const xclock_t bclk);

/** I2S master task
 *
 *  This task differs from i2s_master() in that \p bclk must already be configured to
 *  the BCLK frequency. Other than that, it is identical.
 *
 *  This task performs I2S on the provided pins. It will perform callbacks over
 *  the i2s_callback_group_t callback group to get/receive frames of data from the
 *  application using this component.
 *
 *  The task performs I2S master so will drive the word clock and
 *  bit clock lines.
 *
 *  \param i2s_cbg        The I2S callback group pointing to the application's
 *                        functions to use for initialization and getting and receiving
 *                        frames. Also points to application specific data which will
 *                        be shared between the callbacks.
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param p_bclk         The bit clock output port
 *  \param p_lrclk        The word clock output port
 *  \param bclk           A clock that is configured externally to be used as the bit clock
 *
 */
void i2s_master_external_clock(
        const i2s_callback_group_t *const i2s_cbg,
        const port_t p_dout[],
        const size_t num_out,
        const port_t p_din[],
        const size_t num_in,
        const port_t p_bclk,
        const port_t p_lrclk,
        const xclock_t bclk);

#if 0

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


/** Interface representing callback events that can occur during the
 *  operation of the I2S task. This is a more efficient interface
 *  and reccomended for new designs.
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

} i2s_frame_callback_if;

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
 *  This is a more efficient version of i2s master which reduces callback
 *  frequency and allows useful processing to be done in distributable i2s handler tasks.
 *  It also uses xCORE200 specific features to remove the need for software
 *  BCLK generation which decreases processor overhead.
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

/** I2S frame-based master component **for xCORE200 only**
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
 *  It also uses xCORE200 specific features to remove the need for software
 *  BCLK generation which decreases processor overhead.
 *
 *  \param i2s_i          The I2S frame callback interface to connect to
 *                        the application
 *  \param p_dout         An array of data output ports
 *  \param num_out        The number of output data ports
 *  \param p_din          An array of data input ports
 *  \param num_in         The number of input data ports
 *  \param p_bclk         The bit clock output port
 *  \param p_lrclk        The word clock output port
 *  \param bclk           A clock that is configured externally to be used as the bit clock
 *                        
 */
void i2s_frame_master_external_clock(client i2s_frame_callback_if i2s_i,
                out buffered port:32 (&?p_dout)[num_out],
                static const size_t num_out,
                in buffered port:32 (&?p_din)[num_in],
                static const size_t num_in,
                out port p_bclk,
                out buffered port:32 p_lrclk,
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
void i2s_frame_slave(client i2s_frame_callback_if i2s_i,
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


#include <i2s_master_impl.h>
#include <i2s_frame_master_impl.h>
#include <i2s_slave_impl.h>
#include <i2s_frame_slave_impl.h>
#include <tdm_master_impl.h>

#endif

#endif // _i2s_h_
