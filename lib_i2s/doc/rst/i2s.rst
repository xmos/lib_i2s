.. include:: ../../../README.rst

External signal description
---------------------------

I2S
...

I2S is a protocol between two devices where one is the *master* and
one is the *slave* . The protocol is made up of four signals shown
in :ref:`i2s_wire_table`.

.. _i2s_wire_table:

.. list-table:: I2S data wires
     :class: vertical-borders horizontal-borders

     * - *MCLK*
       - Clock line, driven by external oscillator
     * - *BCLK*
       - Bit clock. This is a fixed divide of the *MCLK* and is driven
         by the master.
     * - *LRCLK* (or *WCLK*)
       - Word clock (or word select). This is driven by the master.
     * - *DATA*
       - Data line, driven by one of the slave or master depending on
         the data direction. There may be several data lines in
         differing directions.


The configuration of an |i2s| signal depends on the parameters shown
in :ref:`i2s_signal_params`.

.. _i2s_signal_params:

.. list-table:: I2S configuration parameters
     :class: vertical-borders horizontal-borders

     * - *MCLK_BCLK_RATIO*
       - The fixed ratio between the master clock and the bit clock.
     * - *MODE*
       - The mode - either |i2s| or left justified.

The *MCLK_BCLK_RATIO* should be such that 64 bits can be output by the
bit clock at the data rate of the |i2s| signal. For example, a
24.576Mhz master clock with a ratio of 8 gives a bit clock at
3.072Mhz. This bit clock can output 64 bits at a frequency of 48Khz -
which is the underlying rate of the data.

The master signals data transfer should occur by a transition on the
*LRCLK* wire. There are two supported modes for |i2s|. In *I2S mode*
(shown in :ref:`i2s_i2s_mode_signal`) data is transferred on the
second falling edge after the *LRCLK* transitions.

.. _i2s_i2s_mode_signal:

.. wavedrom:: I2S Mode

  {signal: [
  {name: 'BCLK',  wave: '1010101|010101|01..'},
  {name: 'LRCLK', wave: '10.....|1.....|0..'},
  {name: 'DOUT',  wave: 'xxx2.2.|2.2.2.|2.x.', data: ['MSB(l)',,'LSB(l)', 'MSB(r)',,'LSB(r)']},
  {name: 'DIN',   wave: 'xxx2.2.|2.2.2.|2.x.', data: ['MSB(l)',,'LSB(l)', 'MSB(r)',,'LSB(r)']},]
  }


In *Left Justified Mode* (shown in :ref:`i2s_left_justified_mode_signal`) the
data is transferred on the next falling edge after the *LRCLK*
transition.

.. _i2s_left_justified_mode_signal:

.. wavedrom:: Left Justified Mode

  {signal: [
  {name: 'BCLK',  wave: '10101|010101|01..'},
  {name: 'LRCLK', wave: '10...|..1...|....'},
  {name: 'DOUT',  wave: 'x2.2.|2.2.2.|2.x.', data: ['MSB(l)',,'LSB(l)', 'MSB(r)',,'LSB(r)']},
  {name: 'DIN',   wave: 'x2.2.|2.2.2.|2.x.', data: ['MSB(l)',,'LSB(l)', 'MSB(r)',,'LSB(r)']},]
  }

In either case the signal multiplexes two channels of data onto one
data line. When the *LRCLK* is low, the *left* channel is
transmitted. When the *LRCLK* is high, the *right* channel is
transmitted.

All data is transmitted most significant bit first. The xCORE |i2s|
library assumes 32 bits of data between *LRCLK* transitions. How the
data is aligned is expeced to be done in software by the
application.

I2S speeds and performance
~~~~~~~~~~~~~~~~~~~~~~~~~~


Connecting I2S signals to the xCORE device
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


The i2s wires need to be connected to the xCORE device as shown in
:ref:`i2s_xcore_connect`. The signals can be connected to any
one bit ports on the device provide they do not overlap any other used
ports and are all on the same tile.

.. _i2s_xcore_connect:

.. figure:: images/i2s_connect.*
   :width: 40%

   I2S connection to the xCORE device

If only one data direction is required then the *DOUT* or *DIN* lines
need not be connected.

|newpage|

TDM
...

TDM is a protocol that multiplexes several signals onto one wire.
It is a protocol between two devices where one is the *master* and
one is the *slave* . The protocol is made up of three signals shown
in :ref:`tdm_wire_table`.

.. _tdm_wire_table:

.. list-table:: TDM data wires
     :class: vertical-borders horizontal-borders

     * - *BCLK*
       - Bit clock line, driven by external oscillator.
     * - *FSYNC*
       - The frame sync line. This is driven by the master.
     * - *DATA*
       - Data line, driven by one of the slave or master depending on
         the data direction. There may be several data lines in
         differing directions.

Unlike |i2s|, the bit clock is not a divide of an underlying master
clock.

The configuration of a TDM signal depends on the parameters shown
in :ref:`tdm_signal_params`.

.. _tdm_signal_params:

.. list-table:: TDM configuration parameters
     :class: vertical-borders horizontal-borders

     * - *CHANNELS_PER_FRAME*
       - The number of channels multiplexed into a frame on the data line.
     * - *FSYNC_OFFSET*
       - The number of bits between the frame sync signal transitioning an
         data being drive on the data line.
     * - *FSYNC_LENGTH*
       - The number of bits that the frame sync signal stays high for
         when signalling frame start.

:ref:`tdm_sig_1` and :ref:`tdm_sig_2` show example waveforms for TDM
with different offset and sync length values.

.. _tdm_sig_1:

.. wavedrom:: TDM signal (sync offset 0, sync length 1)

 { signal: [
 { name: 'FSYNC', wave: '0..10...|......|......|...10..' },
   {name: 'BCLK',  wave: '01010101|010101|010101|0101010', node: '...B'},
  { name: 'DATA', wave: 'x..2.2.2|.2.2.2|.2.2.2|.2.2.2.', data: ['MSB(c0)',,,'LSB(c0)','MSB(c1)',,'LSB(c1)','MSB(c2)',,'LSB(cN)','MSB(c0)'], node: '...................'}],
 }

.. _tdm_sig_2:

.. wavedrom:: TDM signal (sync offset 1, sync length 32)

  { signal: [
  { name: 'FSYNC', wave: '01......|.0....|......|.1.....' },
    {name: 'BCLK',  wave: '01010101|010101|010101|0101010', node: '...B'},
   { name: 'DATA', wave: 'x..2.2.2|.2.2.2|.2.2.2|.2.2.2.', data: ['MSB(c0)',,,'LSB(c0)','MSB(c1)',,'LSB(c1)','MSB(c2)',,'LSB(cN)','MSB(c0)'], node: '...................'}],
  }

The master signals a frame by driving the *FSYNC* signal high. After a
delay of *FSYNC_OFFSET* bits, data is driven. Data is driven most
significant bit first. First, 32 bits of data from Channel 0 is
driven, then 32 bits from channel 1 up to channel N (when N is the
number of channels per frame). The next frame is then signalled (there
is no padding between frames).

TDM speeds and performance
~~~~~~~~~~~~~~~~~~~~~~~~~~


Connecting TDM signals to the xCORE device
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Usage
-----


Master API
----------

All |i2s| functions can be accessed via the ``i2s.h`` header::

  #include <i2s.h>

You will also have to add ``lib_i2s`` to the
``USED_MODULES`` field of your application Makefile.

|i2s| components are instantiated as parallel tasks that run in a
``par`` statement. The application can connect via an interface
connection.
.. figure:: images/i2s_master_task_diag.*

   SPI master task diagram

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
.. figure:: images/i2s_slave_task_diag.*

   SPI master task diagram

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

Then the samples wille be number as indicated below:

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

Equally:

.. figure:: images/i2s_state_machine.*
   :width: 40%

   I2S state machine


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
