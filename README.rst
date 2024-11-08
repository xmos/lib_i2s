:orphan:

########################
lib_i2s: I²S/TDM library
########################

:vendor: XMOS
:version: 6.0.1
:scope: General Use
:description: I²S/TDM controller ("master") and target ("slave")
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
with separate channels for clock and data, reducing jitter and ensuring synchronisation.

In TDM (Time-Division Multiplexing) mode, multiple audio channels can be sent over a single I²S data
line, with each channel occupying specific time slots. This allows I²S to support multi-channel
audio, useful for applications like surround sound.

``lib_i2s`` allows interfacing to I²S or TDM (time division multiplexed) buses via `xcore` ports
and can act either act as I²S `controller` (previously termed `master`) or `target` (previously termed
`slave`) or TDM `controller`.

.. [#] sometimes refered to as Bit Clock (`BCLK`)
.. [#] sometimes refered to as Left/Right(`LRCLK`)

********
Features
********

 * I²S `controller`, TDM `controller` and I²S `target` modes.
 * Supports multiple input and output data lines.
 * standard I²S, left justified or right justified data modes for I²S.
 * Multiple formats of TDM synchronisation signal supported.
 * Sample rates up to 384 kHz (TDM limited to 192 kHz).
 * Up to 32 channels in/32 channels out (depending on sample rate and protocol).

************
Known issues
************

 * I²S target cannot support > 96 kHz on a 4-bit port (`#141 <https://github.com/xmos/lib_i2s/issues/141>`_)

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

 * `AN02016: Integrating Audio Weaver (AWE) Core into USB Audio <https://www.xmos.com/file/an02016>`_
 * `AN02003: SPDIF/ADAT/I2S Receive to I²S Slave Bridge with ASRC <https://www.xmos.com/file/an02003>`_

*******
Support
*******

This package is supported by XMOS Ltd. Issues can be raised against the software at
`www.xmos.com/support <https://www.xmos.com/support>`_

