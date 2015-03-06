import xmostest

class Clock(xmostest.SimThread):

    def set_rate(self, rate):
        self._half_period = float(500000000) / float(rate)
        return


    def __init__(self, port):
        rate = 1000000
        self._half_period = float(500000000) / float(rate)
        self._val = 0
        self._port = port

    def run(self):
        t = self.xsi.get_time()
        t += self._half_period
        while True:
            self.wait_until(t)
            self._val = 1 - self._val
            self.xsi.drive_port_pins(self._port, self._val)
            t += self._half_period

    def is_high(self):
        return (self._val == 1)

    def is_low(self):
        return (self._val == 0)

    def get_val(self):
        return (self._val)

    def get_rate(self):
        return self._clk

    def get_name(self):
        return self._name

class I2SSlaveChecker(xmostest.SimThread):
    """"
    This simulator thread will act as I2S slave and check any transactions
    caused by the Slave.
    """

    def get_setup_data(self, xsi, setup_strobe_port, setup_data_port):
        self.wait_for_port_pins_change([setup_strobe_port])
        self.wait_for_port_pins_change([setup_strobe_port])
        return xsi.sample_port_pins(setup_data_port)

    def __init__(self, bclk, lrclk, din, dout, setup_strobe_port, setup_data_port, setup_resp_port, c):
        self._din = din
        self._dout = dout
        self._bclk = bclk
        self._lrclk = lrclk
        self._setup_strobe_port = setup_strobe_port
        self._setup_data_port = setup_data_port
        self._setup_resp_port = setup_resp_port
        self._clk = c

    def run(self):
        
      xsi = self.xsi


      bits_per_word = 32
      num_frames = 4

      xsi.drive_port_pins(self._bclk, 1)
      print "I2S Slave Checker Started"
      while True:
        xsi.drive_port_pins(self._setup_resp_port, 0)
        strobe_val = xsi.sample_port_pins(self._setup_strobe_port)
	if strobe_val == 1:
           self.wait_for_port_pins_change([self._setup_strobe_port])

        bclk_clocking         = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        bclk_frequency_u      = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        bclk_frequency_l      = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        num_ins               = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        num_outs              = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        is_i2s_justified      = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)

        xsi.drive_port_pins(self._bclk, 1)
        xsi.drive_port_pins(self._lrclk, 1)

        bclk_frequency = (bclk_frequency_u<<16) + bclk_frequency_l
        #print "bclk:%d in:%d out:%d i2s_justified:%d"%(bclk_frequency, num_ins, num_outs, is_i2s_justified)
        clock_half_period = float(1000000000)/float(2*bclk_frequency)
        
        rx_word=[0, 0, 0, 0]
        tx_word=[0, 0, 0, 0]
        tx_data=[[  1,   2,   3,   4,   5,   6,   7,   8],
                 [101, 102, 103, 104, 105, 106, 107, 108],
                 [201, 202, 203, 204, 205, 206, 207, 208],
                 [301, 302, 303, 304, 305, 306, 307, 308],
                 [401, 402, 403, 404, 405, 406, 407, 408],
                 [501, 502, 503, 504, 505, 506, 507, 508],
                 [601, 602, 603, 604, 605, 606, 607, 608],
                 [701, 702, 703, 704, 705, 706, 707, 708]]
        rx_data=[[  1,   2,   3,   4,   5,   6,   7,   8],
                 [101, 102, 103, 104, 105, 106, 107, 108],
                 [201, 202, 203, 204, 205, 206, 207, 208],
                 [301, 302, 303, 304, 305, 306, 307, 308],
                 [401, 402, 403, 404, 405, 406, 407, 408],
                 [501, 502, 503, 504, 505, 506, 507, 508],
                 [601, 602, 603, 604, 605, 606, 607, 608],
                 [701, 702, 703, 704, 705, 706, 707, 708]]

        #there is one frame lead in for the slave to sync to
        time =float(xsi.get_time())

	lr_counter = 32+16+(is_i2s_justified)
        for i in range(0, 16):
          xsi.drive_port_pins(self._lrclk, lr_counter>=32)
          lr_counter = (lr_counter + 1)&0x3f
          xsi.drive_port_pins(self._bclk, 0)
          time = time + clock_half_period
          self.wait_until(time)
          xsi.drive_port_pins(self._bclk, 1)
          time = time + clock_half_period
          self.wait_until(time)
            
        for i in range(0, 32):
          xsi.drive_port_pins(self._lrclk, lr_counter>=32)
          lr_counter = (lr_counter + 1)&0x3f
          xsi.drive_port_pins(self._bclk, 0)
          time = time + clock_half_period
          self.wait_until(time)
          xsi.drive_port_pins(self._bclk, 1)
          time = time + clock_half_period
          self.wait_until(time)

        for i in range(0, 32):
          xsi.drive_port_pins(self._lrclk, lr_counter>=32)
          lr_counter = (lr_counter + 1)&0x3f
          xsi.drive_port_pins(self._bclk, 0)
          time = time + clock_half_period
          self.wait_until(time)
          xsi.drive_port_pins(self._bclk, 1)
          time = time + clock_half_period
          self.wait_until(time)

        error = False
        bit_count = 0

        xsi.drive_port_pins(self._setup_resp_port, 0)
        for frame_count in range(0, num_frames):
          for i in range(0, 4):
            rx_word[i] = 0
            tx_word[i] = tx_data[i*2][frame_count]

          for i in range(0, bits_per_word):
             xsi.drive_port_pins(self._lrclk, lr_counter>=32)
             lr_counter = (lr_counter + 1)&0x3f
             xsi.drive_port_pins(self._bclk, 0)

             for p in range(0, num_outs):
                xsi.drive_port_pins(self._dout[p], tx_word[p]>>31)
                tx_word[p] = tx_word[p]<<1
             time = time + clock_half_period
             self.wait_until(time)
             xsi.drive_port_pins(self._bclk, 1)

             for p in range(0, num_ins):
                val = xsi.sample_port_pins(self._din[p])
                rx_word[p] = (rx_word[p]<<1) + val

             time = time + clock_half_period
             self.wait_until(time)

          for p in range(0, num_outs):
             if rx_data[p*2][frame_count] != rx_word[p]:
                error = True

          for i in range(0, 4):
            rx_word[i] = 0
            tx_word[i] = tx_data[i*2+1][frame_count]

          for i in range(0, bits_per_word):
             xsi.drive_port_pins(self._lrclk, lr_counter>=32)
             lr_counter = (lr_counter + 1)&0x3f

             xsi.drive_port_pins(self._bclk, 0)

             for p in range(0, num_outs):
                xsi.drive_port_pins(self._dout[p], tx_word[p]>>31)
                tx_word[p] = tx_word[p]<<1  
             time = time + clock_half_period
             self.wait_until(time)
             xsi.drive_port_pins(self._bclk, 1)

             for p in range(0, num_ins):
                val = xsi.sample_port_pins(self._din[p])
                rx_word[p] = (rx_word[p]<<1) + val

             time = time + clock_half_period
             self.wait_until(time)

          for p in range(0, num_outs):
             if rx_data[p*2 + 1][frame_count] != rx_word[p]:
                error = True

        xsi.drive_port_pins(self._setup_resp_port, 1)
        #send the response
        self.wait_for_port_pins_change([self._setup_strobe_port])        
        xsi.drive_port_pins(self._setup_resp_port, error)
        #print error
        self.wait_for_port_pins_change([self._setup_strobe_port]) 


       
