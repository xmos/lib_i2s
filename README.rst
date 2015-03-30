I2S Library
===========

.. |i2s| replace:: I |-| :sup:`2` |-| S

Summary
-------

A software defined, industry-standard, |i2s| library
that allows you to control an |i2s| bus via xCORE ports.
|i2s| is a digital data streaming interface. The components in the libary
are controlled via C using the XMOS multicore extensions (xC) and
can either act as |i2s| master or slave.

Features
........

 * |i2s| master and |i2s| slave modes.
 * Handles up to ?? input and output channels
 * Support for standard |i2s|, left justified or right justified modes.

Resource Usage
..............

.. list-table::
   :header-rows: 1
   :class: wide vertical-borders horizontal-borders

   * - Component
     - Pins
     - Ports
     - Clock Blocks
     - Ram
     - Logical cores
   * - Master
     - 3 + data lines
     - 3 x (1-bit) + data lines
     - 0
     - ~0.7K
     - 1
   * - Slave
     - 3 + data lines
     - 3 x (1-bit) + data lines
     - 0
     - ~0.7K
     - 1

Software version and dependencies
.................................

.. libdeps::

Related application notes
.........................

The following application notes use this library:

  * AN00162 - Using the I2S library
