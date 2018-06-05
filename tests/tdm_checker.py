# Copyright (c) 2015-2018, XMOS Ltd, All rights reserved
import xmostest

class TDMMasterChecker(xmostest.SimThread):

    def print_setup(self, sr_frequency, sclk_frequency, num_outs, num_ins, is_i2s_justified, sclk_edge_count, channels_per_data_line, prefix=""):
        print "%ssample rate: %d\tSCLK: %d\tnum ins %d,\tnum outs:%d, is i2s justified: %d\tsclk_edge_count %d\tchannels_per_data_line: %d"%(prefix,sr_frequency, sclk_frequency, num_outs, num_ins, is_i2s_justified, sclk_edge_count, channels_per_data_line)
        return

    def get_setup_data(self, xsi, setup_strobe_port, setup_data_port):
        self.wait_for_port_pins_change([setup_strobe_port])
        self.wait_for_port_pins_change([setup_strobe_port])
        return xsi.sample_port_pins(setup_data_port)

    def __init__(self, sclk, fsync, din, dout, setup_strobe_port, setup_data_port, setup_resp_port, extra_clocks = 0):
        self._din = din
        self._dout = dout
        self._sclk = sclk
        self._fsync = fsync
        self._setup_strobe_port = setup_strobe_port
        self._setup_data_port = setup_data_port
        self._setup_resp_port = setup_resp_port
        self._extra_clocks = extra_clocks

    def run(self):
      xsi = self.xsi
      print "TDM Master Checker Started"

      while True: 
        xsi.drive_port_pins(self._setup_resp_port, 0)
        strobe_val = xsi.sample_port_pins(self._setup_strobe_port)
	if strobe_val == 1:
           self.wait_for_port_pins_change([self._setup_strobe_port])

        sr_frequency_u      = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        sr_frequency_l      = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)

        num_outs              = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        num_ins               = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        is_i2s_justified      = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        sclk_edge_count       = self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)
        channels_per_data_line= self.get_setup_data(xsi, self._setup_strobe_port, self._setup_data_port)

        sr_frequency = (sr_frequency_u<<16) + sr_frequency_l
        sclk_frequency = sr_frequency * 32 * channels_per_data_line
        self.print_setup(sr_frequency, sclk_frequency, num_outs, num_ins, is_i2s_justified, sclk_edge_count, channels_per_data_line, prefix="CONFIG: ")

        time = xsi.get_time()
        max_num_in_or_outs = 4
        num_test_frames = 4
        error = False 
        frame_count = 0
        bit_count = 0
        word_count = 0
        bits_per_word = 32

        rx_word=[0, 0, 0, 0]
        tx_word=[0, 0, 0, 0]

        #for verifing the clock stability
        clock_half_period = float(500000000) / sclk_frequency
        fsync_count = 0

        #there is one frame lead in for the slave to sync to
        time =float(xsi.get_time())

	fsync_counter = 32+16+(is_i2s_justified)

        tx_counter=0
        rx_counter=0
        waiting_for_sync_pulse = True

        error = False

        for p in range(0, num_ins):
          rx_word[p] = 0

        for p in range(0, num_outs):
          tx_word[p] = tx_counter

        if is_i2s_justified:
          bit_count = 0
          for p in range(0, num_outs):
            tx_word[p] = tx_counter
            xsi.drive_port_pins(self._dout[p], tx_counter>>31)
            tx_counter += 1
        else:
          bit_count = 1
          for p in range(0, num_outs):
            tx_word[p] = tx_counter<<1
            xsi.drive_port_pins(self._dout[p], tx_counter>>31)
            tx_counter += 1

        while waiting_for_sync_pulse:
          xsi.drive_port_pins(self._sclk, 0)
          time = time + clock_half_period
          self.wait_until(time)
          xsi.drive_port_pins(self._sclk, 1)
          if xsi.sample_port_pins(self._fsync) != 0:
            waiting_for_sync_pulse = False
          time = time + clock_half_period
          self.wait_until(time)
       
        ##TODO add fsync checking
        xsi.drive_port_pins(self._setup_resp_port, 0)
        while frame_count < num_test_frames:
         for c in range(0, channels_per_data_line):
          for i in range(bit_count, bits_per_word):
            xsi.drive_port_pins(self._sclk, 0)

            for p in range(0, num_outs):
                xsi.drive_port_pins(self._dout[p], tx_word[p]>>31)
                tx_word[p] = tx_word[p]<<1

            self.wait_until(time)
            time = time + clock_half_period
            xsi.drive_port_pins(self._sclk, 1)

            for p in range(0, num_ins):
                val = xsi.sample_port_pins(self._din[p])
                rx_word[p] = (rx_word[p]<<1) + val
            self.wait_until(time)
            time = time + clock_half_period

          
          for p in range(0, num_outs):
             if num_ins > 0:
               if rx_counter != rx_word[p]:
                  print "rx error %08x %08x"%(rx_counter, rx_word[p])
                  error = True
             rx_counter+=1
        
          bit_count = 0
          for p in range(0, num_outs):
            tx_word[p] = tx_counter
            tx_counter += 1
          for p in range(0, num_ins):
            rx_word[p] = 0
         frame_count += 1
        for x in range(0, self._extra_clocks):
            self.wait_until(time)
            time = time + clock_half_period
            xsi.drive_port_pins(self._sclk, 1)
            self.wait_until(time)
            time = time + clock_half_period
            xsi.drive_port_pins(self._sclk, 0)
        xsi.drive_port_pins(self._setup_resp_port, 1)
        #send the response
        self.wait_for_port_pins_change([self._setup_strobe_port])        
        xsi.drive_port_pins(self._setup_resp_port, error)
        #print error
        self.wait_for_port_pins_change([self._setup_strobe_port]) 


       
