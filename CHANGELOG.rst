I2S library change log
======================

2.2.0
-----

  * Added High Efficiency I2S master.
  * Reduce number of LR clock ticks needed to synchronise.
  * Fixed bugs with slave mode and non I2S mode.

2.1.3
-----

  * Slave mode now includes sync error detection and correction e.g. when
    bit-clock is interrupted

2.1.2
-----

  * .Project file fixes such that example(s) import into xTIMEComposer correctly

2.1.1
-----

  * Update to source code license and copyright

2.1.0
-----

  * Input or output ports can now be null, for use when input or output-only is
    required
  * Software license changed to new license

2.0.1
-----

  * Performance improvement to TDM to allow 32x32 operation
  * Bug fix to initialisation callback timing that could cause I2S lock up

2.0.0
-----

  * Major update to API from previous I2S components

  * Changes to dependencies:

    - lib_logging: Added dependency 2.0.0

    - lib_xassert: Added dependency 2.0.0

