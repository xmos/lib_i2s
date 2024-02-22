I2S library change log
======================

5.1.0
-----

  * ADDED: Support for XCommon CMake build system
  * RESOLVED: Added missing shutdown feature to i2s_frame_slave
  * FIXED: Allow input and output ports in the 4-bit port implementation to be
    nullable
  * FIXED: Behaviour of the restart_check() callback function in the example
    applications
  * REMOVED: Unused dependency lib_logging
  * ADDED: Frame synch error field in i2s_config_t for I2S slave

  * Changes to dependencies:

    - lib_logging: Removed dependency

    - lib_xassert: 2.0.0 -> 4.2.0

5.0.0
-----

  * ADDED: Support for I2S data lengths less than 32 bit.
  * ADDED: Implementation allowing use of a 4-bit port for up to 4 simultaneous
    streaming inputs or outputs.

4.3.0
-----

  * CHANGED: Use XMOS Public Licence Version 1

4.2.0
-----

  * ADDED: Support for XS3 architecture

4.1.1
-----

  * CHANGED: Pin Python package versions
  * REMOVED: not necessary cpanfile

4.1.0
-----

  * ADDED: Frame based I2S master that needs the bit clock to be set up
    externally.
  * REMOVED: I2S_BCLOCK_FROM_XCORE and I2S_XCORE_BLOCK_DIV optional #ifdefs

4.0.0
-----

  * CHANGED: Build files updated to support new "xcommon" behaviour in xwaf.

3.0.1
-----

  * CHANGE: At initialisation, configure LR clock of frame-based I2S slave for
    input.
  * CHANGE: Renamed example application directories to have standard "app"
    prefix.
  * ADDED: I2S_BCLOCK_FROM_XCORE and I2S_XCORE_BLOCK_DIV optional #ifdefs

3.0.0
-----

  * REMOVED: Combined I2S and TDM master

2.4.0
-----

  * ADDED: Frame-based I2S slave implementation.
  * CHANGE: AN00162 now uses frame-based I2S master component.

2.3.0
-----

  * ADDED: Configuration option for slave bit clock polarity. This allows
    supporting masters that toggle word clock and data on rising edge of bit
    clock.

2.2.0
-----

  * ADDED: Frame-based I2S master using the new i2s_frame_callback_if. This
    reduces the overhead of an interface call per sample.
  * CHANGE: Reduce number of LR clock ticks needed to synchronise.
  * RESOLVED: Documentation now correctly documents the valid values for FSYNC.
  * RESOLVED: The I2S slave will now lock correctly in both I2S and
    LEFT_JUSTFIED modes. Previously there was a bug that meant LEFT_JUSTFIED
    would not work.

2.1.3
-----

  * CHANGE: Slave mode now includes sync error detection and correction e.g.
    when bit-clock is interrupted

2.1.2
-----

  * RESOLVED: .project file fixes such that example(s) import into xTIMEComposer
    correctly

2.1.1
-----

  * CHANGE: Update to source code license and copyright

2.1.0
-----

  * CHANGE: Input or output ports can now be null, for use when input or
    output-only is required
  * CHANGE: Software license changed to new license

2.0.1
-----

  * CHANGE: Performance improvement to TDM to allow 32x32 operation
  * RESOLVED: Bug fix to initialisation callback timing that could cause I2S
    lock up

2.0.0
-----

  * CHANGE: Major update to API from previous I2S components

  * Changes to dependencies:

    - lib_logging: Added dependency 2.0.0

    - lib_xassert: Added dependency 2.0.0

