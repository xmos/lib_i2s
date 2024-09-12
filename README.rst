.. |I2S| replace:: I\ :sup:`2`\ S

###############
I2S/TDM Library
###############

Summary
-------

This is a software library that allows you to control an |I2S| or TDM (time
division multiplexed) bus via xCORE ports. |I2S| and TDM are digital
data streaming interfaces particularly appropriate for transmission of
audio data. The components in the library
are controlled via C using the XMOS multicore extensions (xC) and
can either act as |I2S| master, TDM master or |I2S| slave.

Features
........

 * |I2S| master, TDM master and |I2S| slave modes.
 * Handles multiple input and output data lines.
 * Support for standard |I2S|, left justified or right justified
   data modes for |I2S|.
 * Support for multiple formats of TDM synchronization signal.
 * Efficient "frame-based" versions of |I2S| master and slave allowing use of processor cycles in between I2S signal handling.
 * Sample rate support up to 192kHz or 384kHz for |I2S|.
 * Up to 32 channels in/32 channels out (depending on sample rate and protocol).

Resource Usage
..............

The |I2S| and TDM modules use one logical core and between 1.6 and 2.1kB of memory. IO usage is 1 x 1b port for each signal.

Software version and dependencies
.................................

The CHANGELOG contains information about the current and previous versions.
For a list of direct dependencies, look for ``DEPENDENT_MODULES`` in ``lib_i2s/module_build_info``.

Related application notes
.........................

The following application notes use this library:

  * AN00162 - Using the |I2S| library
  * `AN02016: Integrating Audio Weaver (AWE) Core into USB Audio <https://www.xmos.com/file/an02016>`_
  * `AN02003: SPDIF/ADAT/I2S Receive to |I2S| Slave Bridge with ASRC <https://www.xmos.com/file/an02003>`_
