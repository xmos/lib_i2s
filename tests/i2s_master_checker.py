import xmostest

class I2SMasterChecker(xmostest.SimThread):
    """"
    This simulator thread will act as I2S slave and check any transactions
    caused by the master.
    """

    def __init__(self, 
                 din_port_1, din_port_2, din_port_3, din_port_4, 
                 num_in_ports,
                 dout_port_1, dout_port_2, dout_port_3, dout_port_4,
                 num_out_ports,
                 bclk_port, lrclk_port, mode, tx_data = [],
                 trigger_port = None, test_ctrl = None):
        self._din_port_1 = din_port_1
        self._din_port_2 = din_port_2
        self._din_port_3 = din_port_3
        self._din_port_4 = din_port_4
        self._num_in_ports = num_in_ports
        self._dout_port_1 = dout_port_1
        self._dout_port_2 = dout_port_2
        self._dout_port_3 = dout_port_3
        self._dout_port_4 = dout_port_4
        self._num_out_ports = num_out_ports
        self._bclk_port = bclk_port
        self._lrclk_port = lrclk_port
        self._tx_data = tx_data
        self._trigger_port = trigger_port
        self._test_ctrl = test_ctrl
        self._mode = mode
        print "Checking I2S: BLCK=%s, LRCLK=%s" % (self._bclk_port, 
         self._lrclk_port)
        if self._trigger_port != None:
            print("Using port %s as trigger" % (self._trigger_port))

    def get_port_val(self, xsi, port):
        "Sample port, modelling the pull up"
        is_driving = xsi.is_port_driving(port)
        if not is_driving:
            return 1
        else:
            return xsi.sample_port_pins(port);

    #read I2S test data from xCORE
    def read_data(self, xsi):
        p_l_values = []
        p_r_values = []
        lrclk_val = -1
        bit_num = 0
        self.wait_for_port_pins_change([self._lrclk_port])
        lrclk_val = self.get_port_val(xsi, self._lrclk_port)
        # if LR clock is 'low', read it as Left channel audio sample
        # if LR clock is 'hi', read it as Right channel audio sample
        while True:
            for client in range(0, self._num_in_ports):
                p_l_values.append(0)
                p_r_values.append(0)
            self.wait_for_port_pins_change([self._bclk_port])
            # Read bits when bit clock changes to high
            if self.get_port_val(xsi, self._bclk_port) == 1:
                for client in range(0, self._num_in_ports):
                  if client == 0: 
                    p_data = self.get_port_val(xsi, self._din_port_1)
                  if client == 1: 
                    p_data = self.get_port_val(xsi, self._din_port_2)
                  if client == 2: 
                    p_data = self.get_port_val(xsi, self._din_port_3)
                  if client == 3: 
                    p_data = self.get_port_val(xsi, self._din_port_4)
                  #p_data = ((port_data >> client) & 1)
                  if lrclk_val == 0:
                    p_l_values[client] = p_l_values[client] | \
                      (p_data << (31 - bit_num))
                  else:
                    p_r_values[client] = p_r_values[client] | \
                      (p_data << (31 - bit_num))
                #Report the received word
                if bit_num == 31:
                  bit_num = 0
                  for client in range(0, self._num_in_ports):            
                    if  lrclk_val == 0: 
                      print("Left Sample received: client:%d, data:%x" %
                       (client, p_l_values[client]))
                    else: 
                      print("Right Sample received: client:%d, data:%x" %
                       (client, p_r_values[client]))
                else:
                  bit_num += 1
            lrclk_val = self.get_port_val(xsi, self._lrclk_port)
            trig_data = xsi.sample_port_pins(self._trigger_port)
            if trig_data == 1: break

    def get_next_data_item(self):
        if self._tx_data_index >= len(self._tx_data):
            return 0xab
        else:
            data = self._tx_data[self._tx_data_index]
            self._tx_data_index += 1
            return data
 
    #send I2S test data to xCORE
    def write_data(self, xsi):
        p_l_values = []
        p_r_values = []
        lrclk_val = -1
        bit_val = 0x0
        while True:
            trigger_port_data = xsi.sample_port_pins(self._trigger_port)
            if (trigger_port_data == 0) : break

        while True:
            self.wait_for_port_pins_change([self._lrclk_port])
            lrclk_val = self.get_port_val(xsi, self._lrclk_port)
            if lrclk_val == 1: break
            
        while True:
            self.wait_for_port_pins_change([self._bclk_port])
            if self.get_port_val(xsi, self._bclk_port) == 1:
                if self._num_out_ports > 0:
                  xsi.drive_port_pins(self._dout_port_1, bit_val)
                if self._num_out_ports > 1:
                  xsi.drive_port_pins(self._dout_port_2, bit_val)
                if self._num_out_ports > 2:
                  xsi.drive_port_pins(self._dout_port_3, bit_val)
                if self._num_out_ports > 3:
                  xsi.drive_port_pins(self._dout_port_4, bit_val)
                 
                if lrclk_val == 0:
                  #left channel data
                  bit_val = 1-bit_val
                else:
                  bit_val = 1 #-bit_val
            lrclk_val = self.get_port_val(xsi, self._lrclk_port)
            #Check if xCORE testing is complete
            trig_data = xsi.sample_port_pins(self._trigger_port)
            if trig_data == 1: break

    def run(self):
        xsi = self.xsi
        self._tx_data_index = 0
        if self._mode == 0:
            print("I2S Master simulation - read")
            self.read_data(xsi)            
        else:
            print("I2S Master simulation - write")
            self.write_data(xsi)
