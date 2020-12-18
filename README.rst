.. |I2S| replace:: I\ :sup:`2`\ S

I2S/TDM Library
===============

Summary
-------

A software library that allows you to control an |I2S| or TDM (time
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
 * Sample rate support up to 192kHz or 768kHz for "frame-based" versions.
 * Up to 32 channels in/32 channels out (depending on sample rate and protocol).

Resource Usage
..............

The I2S and TDM modules use one logical core and between 1.6 and 2.1kB of memory. IO usage is 1 x 1b port for each signal.

Software version and dependencies
.................................

The CHANGELOG contains information about the current and previous versions.
For a list of direct dependencies, look for DEPENDENT_MODULES in lib_i2s/module_build_info.

Notes on "frame-based" |I2S| implementations
............................................

The library supports both "sample-based" and "frame-based" versions of |I2S| master and slave. The "frame-based" versions are recommended for new designs and support higher |I2S| channel counts and rates. In addition, the number of callbacks to pass data to and from the |I2S| handler task are reduced. "Frame-based" |I2S| pass an array of channels per sample period whereas "sample-based" versions make a callback per channel within a sample period. The "frame-based" callbacks are all grouped together allowing the user side to make maximum use of the MIPS between |I2S| frames. For example, a 48kHz (20.83us) |I2S| interface supports a total of 19us processing per sample period, in any order, across the callbacks. The older "sample-based" versions are currently maintained to provide compatibility with existing code examples.


Related application notes
.........................

The following application notes use this library:

  * AN00162 - Using the |I2S| library
