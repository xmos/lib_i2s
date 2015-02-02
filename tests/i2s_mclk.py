import xmostest
import sys
import zlib

class Clock(xmostest.SimThread):

    # Use the values that need to be presented as I2S master clock
    (CLK_24_5MHz) = (0x4)

    def __init__(self, port, clk):
        self._clk = clk
        if clk == self.CLK_24_5MHz:
            self._period = float(1000000000) / 24500000
            self._name = '24_5mhz'
        elif clk == self.CLK_25MHz:
            self._period = float(1000000000) / 25000000
            self._name = '100Mbs'
            self._bit_time = 10
        elif clk == self.CLK_2_5MHz:
            self._period = float(1000000000) / 2500000
            self._name = '10Mbs'
            self._bit_time = 100
        self._val = 0
        self._port = port
        print("Driving %s master clk to xCORE" % self._name)

    def run(self):
        while True:
            self.wait_until(self.xsi.get_time() + self._period/2)
            self._val = 1 - self._val
            self.xsi.drive_port_pins(self._port, self._val)

    def is_high(self):
        return (self._val == 1)

    def is_low(self):
        return (self._val == 0)

    def get_rate(self):
        return self._clk

    def get_name(self):
        return self._name

