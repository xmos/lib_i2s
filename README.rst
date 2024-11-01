:orphan:

########################
lib_i2s: I²S/TDM library
########################

:vendor: XMOS
:version: 6.0.0
:scope: General Use
:description: I²S/TDM master and slave
:category: Audio
:keywords: Audio, PCM
:devices: xcore-200, xcore.ai

*******
Summary
*******

I²S (Inter-IC Sound) is a digital serial protocol developed for transmitting high-quality audio
data between components, like microcontrollers, audio codecs, and DSPs. It’s commonly used for
PCM (Pulse Code Modulation) audio, which is the standard form for digital audio representation.
I²S has three main lines: Serial Data (SD), Serial Clock (`SCK`) [#]_, and Word Select (`WS`) [#]_,
with separate channels for clock and data, reducing jitter and ensuring synchronization

TDM (Time-Division Multiplexing) mode, multiple audio channels can be sent over a single I²S data
line, with each channel occupying specific time slots. This allows I²S to support multi-channel
audio, useful for applications like surround sound.

``lib_i2s`` allows interfacing to I²S or TDM (time division multiplexed) buses via `xcore` ports
and can act either act as I²S master, TDM master or I²S slave.

.. [#] sometimes refered to as Bit Clock (`BCLK`)
.. [#] sometimes refered to as Left/Right(`LRCLK`)

********
Features
********

 * I²S master, TDM master and I²S slave modes.
 * Handles multiple input and output data lines.
 * Support for standard I²S, left justified or right justified data modes for I²S.
 * Support for multiple formats of TDM synchronization signal.
 * Sample rate support up to 192kHz or 384kHz for I²S.
 * Up to 32 channels in/32 channels out (depending on sample rate and protocol).

************
Known issues
************

 * None

****************
Development repo
****************

 * `https://github.com/xmos/lib_i2s <https://github.com/xmos/lib_i2s>`_

**************
Required tools
**************

 * XMOS XTC Tools: 15.3.0

*********************************
Required libraries (dependencies)
*********************************

 * lib_xassert (www.github.com/xmos/lib_xassert)

*************************
Related application notes
*************************

The following application notes use this library:

 * AN00162 - Using the I²S library
 * `AN02016: Integrating Audio Weaver (AWE) Core into USB Audio <https://www.xmos.com/file/an02016>`_
 * `AN02003: SPDIF/ADAT/I2S Receive to I²S Slave Bridge with ASRC <https://www.xmos.com/file/an02003>`_

*******
Support
*******

This package is supported by XMOS Ltd. Issues can be raised against the software at
`www.xmos.com/support <https://www.xmos.com/support>`_

