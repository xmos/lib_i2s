.. |I2S| replace:: I\ :sup:`2`\ S

Using the I2S library
=====================

Summary
-------

|I2S| interfaces are key to many audio systems. XMOS technology is perfectly suited
to these applications - supporting a wide variety of standard interfaces and
also a large range of DSP functions.

This application note demonstrates the use of the XMOS |I2S| library to
create a digital audio loopback on an XMOS multicore microcontroller.

The code used in the application note configures the audio codecs to simultaneously
send and receive audio samples. It then uses the |I2S| library to
loopback all 8 channels.

Required tools and libraries
............................

 * xTIMEcomposer Tools
 * XMOS |I2S|/TDM library
 * XMOS Board Support library

Required hardware
.................

The example code provided with the application has been implemented
and tested on the XU316 Multichannel Audio board.

Prerequisites
..............

 * This document assumes familarity with |I2S| interfaces, the XMOS xCORE
   architecture, the XMOS tool chain and the xC language. Documentation related
   to these aspects which are not specific to this application note are linked
   to in the references appendix.
