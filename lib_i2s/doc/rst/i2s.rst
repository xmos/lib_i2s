I2S Library
===========

.. |i2s| replace:: I |-| :sup:`2` |-| S

.. rheader::

   I2S |version|

I2S Libary
----------

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

Components
...........

 * |i2s| master
 * |i2s| slave

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

This document pertains to version |version| of the |i2s| library. It is
intended to be used with version 13.x of the xTIMEcomposer studio tools.

The library does not have any dependencies (i.e. it does not rely on any
other libraries).

Related application notes
.........................

The following application notes use this library:

  * AN00052 - How to use the I2S component

Hardware characteristics
------------------------

TODO

Master API
----------

All |i2s| functions can be accessed via the ``i2s.h`` header::

  #include <i2s.h>

You will also have to add ``lib_i2s`` to the
``USED_MODULES`` field of your application Makefile.

|i2s| components are instantiated as parallel tasks that run in a
``par`` statement. The application can connect via an interface
connection.

TODO DIAGRAM!!!

For example, the following code instantiates an |i2s| master component
and connect to it::
     
  out buffered port:32 p_dout[2] = {XS1_PORT_1D, XS1_PORT_1E};
  in buffered port:32 p_din[2]  = {XS1_PORT_1I, XS1_PORT_1K};
  port p_mclk  = XS1_PORT_1M;
  port p_bclk  = XS1_PORT_1A;
  port p_lrclk = XS1_PORT_1C;

  int main(void) {
    i2s_callback_if i_i2s;
    par {
      i2s_master(i_i2s, p_dout, 2, p_din, 2,
                 p_bclk, p_lrclk, bclk, mclk,
                 48000, 24576000);
      my_application(i_i2s]);
    }
    return 0;
  }

The application provieds the *server* of the interface
connection. This means it must provide implementations of the
callbacks the |i2s| component make e.g.::

  void my_application(server i2c_master_if i2c) {
  while (1) {
    select {
    case i2s.init(unsigned &sample_frequency, unsigned &master_clock_frequency):
      ...
      break;

    case i2s.frame_start(unsigned timestamp, unsigned &restart):
      ...
      break;

    case i2s.receive(size_t index, int32_t sample):
      ...
      break;

    case i2s.send(size_t index) -> int32_t sample:
      ...
      break;
    }
  }

More information on interfaces and tasks can be be found in
the :ref:`XMOS Programming Guide<programming_guide>`. Ofter it makes
sense to make the application task connected to the |i2s| component to
be a ``[[distributed]]`` function. This means that the application
callbacks will not run on a core of their own by on the same logical
core that the |i2s| component is using.

|newpage|

Creating an I2S instance
........................

.. doxygenfunction:: i2s_master

|newpage|

.. doxygenfunction:: i2s_slave

|newpage|

The I2S callback interface
..........................

.. doxygeninterface:: i2s_callback_if
