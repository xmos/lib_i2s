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

I2S master
==========

The signals from the xCore required to drive an I2S Master are:

.. _i2s_master_wire_table:

.. list-table:: I2S data and signal wires
     :class: vertical-borders horizontal-borders

     * - *BCLK*
       - Bit clock line
     * - *LR_CLK*
       - Left/right clock
     * - *DOUT*
       - Data out. 
     * - *DIN*
       - Data in.

Additionally, there is an expected MCLK(master clock). This clock, typically 
divided down to form the bit clock, is used to distribute a system wide clock
to all devices wishing to synchronise to the I2S bus.


I2S has two alignment modes: data aligned to the LR clock and the data behind 
the LR clock by a single bit clock. These are refered to as I2S aligned(``I2S_MODE_I2S``) 
and left justified1(``I2S_MODE_LEFT_JUSTIFIED``).

Mode: I2S justified
~~~~~~~~~~~~~~~~~~~
 
.. wavedrom:: Left Justified Mode
  {signal: [
  {name: 'BCLK',  wave: '10101|010101|01..'},
  {name: 'LRCLK', wave: '10...|..1...|....'},
  {name: 'DOUT',  wave: 'x2.2.|2.2.2.|2.x.', data: ['MSB(l)',,'LSB(l)', 'MSB(r)',,'LSB(r)']},
  {name: 'DIN',   wave: 'x2.2.|2.2.2.|2.x.', data: ['MSB(l)',,'LSB(l)', 'MSB(r)',,'LSB(r)']},]
  }

Mode: Left justified
~~~~~~~~~~~~~~~~~~~~

.. wavedrom:: I2S Mode
  {signal: [
  {name: 'BCLK',  wave: '1010101|010101|01..'},
  {name: 'LRCLK', wave: '10.....|1.....|0..'},
  {name: 'DOUT',  wave: 'xxx2.2.|2.2.2.|2.x.', data: ['MSB(l)',,'LSB(l)', 'MSB(r)',,'LSB(r)']},
  {name: 'DIN',   wave: 'xxx2.2.|2.2.2.|2.x.', data: ['MSB(l)',,'LSB(l)', 'MSB(r)',,'LSB(r)']},]
  }

Note that left justified mode can be used for right justification also.
In the case of right justification it is up to the user to bit reverse 
the data before sending it and after recieveing it. 

I2S slave
=========

The signals from the xCore required to drive an I2S Slave are:

.. _i2s_master_wire_table:

.. list-table:: I2S data and signal wires
     :class: vertical-borders horizontal-borders

     * - *BCLK*
       - Bit clock line
     * - *LR_CLK*
       - Left/right clock
     * - *DOUT*
       - Data out. 
     * - *DIN*
       - Data in.

The i2s slave operates in much the same way as the master except it 
is no longer responsible for driving the bit clock and the LR clock. 
Instead the slave triggers off the first falling edge of the LR clock 
then clocks data in and out one frame later. It assumes 32 bit data and
the alignment with the LR clock is given by the same mode as with the 
master implementation.

The timing for the I2S slave is the same as the I2S master, see above.


Master API
----------

All |i2s| functions can be accessed via the ``i2s.h`` header::

  #include <i2s.h>

You will also have to add ``lib_i2s`` to the
``USED_MODULES`` field of your application Makefile.

|i2s| components are instantiated as parallel tasks that run in a
``par`` statement. The application can connect via an interface
connection.

For example, the following code instantiates an |i2s| master component
and connects to it::
     
  out buffered port:32 p_dout[2] = {XS1_PORT_1D, XS1_PORT_1E};
  in buffered port:32 p_din[2]  = {XS1_PORT_1I, XS1_PORT_1K};
  port p_mclk  = XS1_PORT_1M;
  out buffered port:32 p_bclk  = XS1_PORT_1A;
  out buffered port:32 p_lrclk = XS1_PORT_1C;

  clock mclk = XS1_CLKBLK_1;
  clock bclk = XS1_CLKBLK_2;

  int main(void) {
    i2s_callback_if i_i2s;
    configure_clock_src(mclk, p_mclk);
    start_clock(mclk);
    par {
      i2s_master(i_i2s, p_dout, 2, p_din, 2,
               p_bclk, p_lrclk, bclk, mclk);
      my_application(i_i2s);
    }
    return 0;
  }

The application provieds the *server* of the interface
connection. This means it must provide implementations of the
callbacks the |i2s| component make e.g.::

  void my_application(server i2s_callback_if i2s) {
  while (1) {
    select {
    case i2s.init(unsigned &mclk_bclk_ratio, i2s_mode &mode):
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



|newpage|


Slave API
----------

All |i2s| functions can be accessed via the ``i2s.h`` header::

  #include <i2s.h>

You will also have to add ``lib_i2s`` to the
``USED_MODULES`` field of your application Makefile.

|i2s| components are instantiated as parallel tasks that run in a
``par`` statement. The application can connect via an interface
connection.

For example, the following code instantiates an |i2s| slave component
and connects to it::
     
  out buffered port:32 p_dout[2] = {XS1_PORT_1D, XS1_PORT_1E};
  in buffered port:32 p_din[2]  = {XS1_PORT_1I, XS1_PORT_1K};
  in port p_bclk  = XS1_PORT_1A;
  in port p_lrclk = XS1_PORT_1C;

  clock bclk = XS1_CLKBLK_1;

  int main(void) {
    i2s_slave_callback_if i_i2s;
    configure_clock_src(mclk, p_mclk);
    start_clock(mclk);
    par {
      i2s_master(i2s_i, p_dout, 2, p_din, 2,
                 p_bclk, p_lrclk, bclk);
      my_application(i_i2s);
    }
    return 0;
  }

The application provieds the *server* of the interface
connection. This means it must provide implementations of the
callbacks the |i2s| component make e.g.::

  void my_application(server i2s_slave_callback_if i2s) {
  while (1) {
    select {
    case i2s.init(i2s_mode &mode):
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

The difference between the i2s master and slave is that the 
slave does not require a ``mclk_bclk_ratio`` to be set in 
the ``init`` method of the interface.

i2s calling protocol
~~~~~~~~~~~~~~~~~~~~

This applies to both master and slave.

In order to use the interfaces efficiently the user is expected to 
handle the callbacks with minimum delay. Both the i2s master and slave will 
call their methods in a predefined order.

digraph g {
  init -> frame_start;
  frame_start -> send_head;
  send_head -> send -> recieve -> send;
  send -> recieve_tail;
  recieve_tail -> init;
}

As the i2s library uses it ports in 32 bit buffered mode they are always sending 
data out one word ahead and recieving data in one word behind. For this 
reason after the user has responded to the ``init`` callback the i2s 
master will request data to send out twice before reporting that it has 
recieved any. Equally, after the user signals that the current frame 
should be the last(through ``frame_start``) then the i2s master will 
continue to recieve until the din buffer has been cleared. This allows 
the whole frame to be recieved by the client application.

Additionally, it is useful to know the order of the recieved and sent words 
when writing application code. The data words within frames will ordered by:
even numbers assigned to the left samples(first) and the odd numbers assigned 
to the right(second) samples. The actual sample number will be given with 
respect to the order that the ports are in the data in and data out arrays. 
For example: in a system with 4 data out ports declared as::

out buffered port:32 p_dout[4] = {XS1_PORT_1A, XS1_PORT_1B, XS1_PORT_1C, XS1_PORT_1D};

Then the samples wille be number as indicated below::

.. wavedrom:: i2s channel numbering
  {signal: [
  {name: 'LRCLK', wave: '1.0.1.0.1..'},
  {name: 'DOUT[0]',  wave: 'xx2.2.2.2.x.', data: ['0','1', '0','1']},
  {name: 'DOUT[1]',  wave: 'xx2.2.2.2.x.', data: ['2','3', '2','3']},
  {name: 'DOUT[2]',  wave: 'xx2.2.2.2.x.', data: ['4','5', '4','5']},
  {name: 'DOUT[3]',  wave: 'xx2.2.2.2.x.', data: ['6','7', '6','7']},
  {name: 'DIN[0]',  wave: 'xx2.2.2.2.x.', data: ['0','1', '0','1']},
  {name: 'DIN[1]',  wave: 'xx2.2.2.2.x.', data: ['2','3', '2','3']},
  {name: 'DIN[2]',  wave: 'xx2.2.2.2.x.', data: ['4','5', '4','5']},
  {name: 'DIN[3]',  wave: 'xx2.2.2.2.x.', data: ['6','7', '6','7']}]
  }

The user should expect to get call backs in the order of:

A lead in of:
init
send - the left channel data for port 1A. It will have index 0.
send - the left channel data for port 1B. It will have index 2.
send - the left channel data for port 1C. It will have index 4.
send - the left channel data for port 1D. It will have index 6.
frame_start
send - the right channel data for port 1A. It will have index 1.
send - the right channel data for port 1B. It will have index 3.
send - the right channel data for port 1C. It will have index 5.
send - the right channel data for port 1D. It will have index 7.

Then a body consisting of many of:(until restart is set to non-zero)
recieve - the left channel data for port 1A. It will have index 0.
recieve - the left channel data for port 1B. It will have index 2.
recieve - the left channel data for port 1C. It will have index 4.
recieve - the left channel data for port 1D. It will have index 6.
send    - the left channel data for port 1A. It will have index 0.
send    - the left channel data for port 1B. It will have index 2.
send    - the left channel data for port 1C. It will have index 4.
send    - the left channel data for port 1D. It will have index 6.
frame_start
recieve - the right channel data for port 1A. It will have index 1.
recieve - the right channel data for port 1B. It will have index 3.
recieve - the right channel data for port 1C. It will have index 5.
recieve - the right channel data for port 1D. It will have index 7.
send    - the right channel data for port 1A. It will have index 1.
send    - the right channel data for port 1B. It will have index 3.
send    - the right channel data for port 1C. It will have index 5.
send    - the right channel data for port 1D. It will have index 7.

Then a tail of:
recieve - the left channel data for port 1A. It will have index 0.
recieve - the left channel data for port 1B. It will have index 2.
recieve - the left channel data for port 1C. It will have index 4.
recieve - the left channel data for port 1D. It will have index 6.
recieve - the right channel data for port 1A. It will have index 1.
recieve - the right channel data for port 1B. It will have index 3.
recieve - the right channel data for port 1C. It will have index 5.
recieve - the right channel data for port 1D. It will have index 7.

The ``frame_start`` callback returns a timestamp. This timestamp should 
be used to compare the time of one frame to another to detemine the speed 
and jitter of the i2s data. The user should ignore the first timestamp as 
its position in the frame can be non-deterministic, however, from then on 
all timstamps are taken at exactly the same point in a frame and should be 
considered stable. ``frame_start`` is also used for ending the i2s 
transaction. When restart is set to non-zero then the current frame will 
be the last. 


More information on interfaces and tasks can be be found in
the :ref:`XMOS Programming Guide<programming_guide>`. Often it makes
sense to make the application task connected to the |i2s| component to
be a ``[[distributed]]`` function. This means that the application
callbacks will not run on a core of their own by on the same logical
core that the |i2s| component is using.

Creating an I2S instance
........................

.. doxygenfunction:: i2s_master

|newpage|

.. doxygenfunction:: i2s_slave

|newpage|

The I2S master callback interface
.................................

.. doxygeninterface:: i2s_callback_if

The I2S slave callback interface
................................

.. doxygeninterface:: i2s_slave_callback_if
