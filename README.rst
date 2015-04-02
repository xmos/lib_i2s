I2S/TDM Library
===============

.. |i2s| replace:: I |-| :sup:`2` |-| S

Summary
-------

A software library that allows you to control an |i2s| or TDM (time
division multiplexed) bus via xCORE ports. |i2s| and TDM are digital
data streaming interface particularly appropriate for transmission of
audio data. The components in the libary
are controlled via C using the XMOS multicore extensions (xC) and
can either act as |i2s| master, TDM master or |i2s| slave.

Features
........

 * |i2s| master, TDM master and |i2s| slave modes.
 * Handles multiple input and output data lines.
 * Support for standard |i2s|, left justified or right justified
   data modes for |i2s|.
 * Support for multiple formats of TDM synchronization signal.
 * Sample rate support up to 192KHz.
 * Up to 16 channels in/16 channels out (depending on sample rate)

Resource Usage
..............

.. resusage::

  * - configuration: I2S Master
    - globals:   out buffered port:32 p_dout[2] = {XS1_PORT_1D, XS1_PORT_1E};
                 in buffered port:32 p_din[2]  = {XS1_PORT_1I, XS1_PORT_1K};
                 port p_mclk  = XS1_PORT_1M;
                 out buffered port:32 p_bclk  = XS1_PORT_1A;
                 out buffered port:32 p_lrclk = XS1_PORT_1C;
                 clock mclk = XS1_CLKBLK_1;
                 clock bclk = XS1_CLKBLK_2;
    - locals: interface i2s_callback_if i;
    - fn: i2s_master(i, p_dout, 2, p_din, 2, p_bclk, p_lrclk, bclk, mclk);
    - pins: 3 + data lines
    - ports: 3 x (1-bit) + data lines
    - cores: 1
  * - configuration: I2S Slave
    - globals:   out buffered port:32 p_dout[2] = {XS1_PORT_1D, XS1_PORT_1E};
                 in buffered port:32 p_din[2]  = {XS1_PORT_1I, XS1_PORT_1K};
                 port p_mclk  = XS1_PORT_1M;
                 in port p_bclk  = XS1_PORT_1A;
                 in buffered port:32 p_lrclk = XS1_PORT_1C;
                 clock bclk = XS1_CLKBLK_2;
    - locals: interface i2s_callback_if i;
    - fn: i2s_slave(i, p_dout, 2, p_din, 2, p_bclk, p_lrclk, bclk);
    - pins: 2 + data lines
    - ports: 2 x (1-bit) + data lines
    - cores: 1
  * - configuration: TDM Master
    - globals:   out buffered port:32 p_dout[2] = {XS1_PORT_1D, XS1_PORT_1E};
                 in buffered port:32 p_din[2]  = {XS1_PORT_1I, XS1_PORT_1K};
                 out buffered port:32 p_fsync = XS1_PORT_1C;
                 clock bclk = XS1_CLKBLK_2;
    - locals: interface i2s_callback_if i;
    - fn: tdm_master(i, p_fsync, p_dout, 2, p_din, 2, bclk);
    - pins: 2 + data lines
    - ports: 2 x (1-bit) + data lines
    - cores: 1

Software version and dependencies
.................................

.. libdeps::

Related application notes
.........................

The following application notes use this library:

  * AN00162 - Using the I2S library
