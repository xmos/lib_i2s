import xmostest

def convert_from_bits(bits):
    data = 0
    for bit in reversed(bits):
        data = (data << 1) + bit
    return data

def convert_to_bits(data):
    bits = []
    for i in range(32):
        bit = data & 1
        data = data >> 1
        bits.append(bit)
    return [b for b in reversed(bits)]

class Clock(xmostest.SimThread):
    def __init__(self, port, rate):
        self._half_period = float(500000000) / rate
        self._val = 0
        self._port = port
        print("Driving %d master clk to xCORE" % rate)

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


class TDMMasterTxChecker(xmostest.SimThread):

    def __init__(self, fsync, data, bclk, expected,
                 samples_per_frame=8, fsync_length=1, sample_rate=48000):
        super(TDMMasterTxChecker, self).__init__()
        self._fsync = fsync
        self._data = data
        self._bclk = bclk
        self._samples_per_frame = samples_per_frame
        self._expected = expected
        self._fsync_length = fsync_length
        self._sample_rate = sample_rate
        self._bit_rate = sample_rate * samples_per_frame * 32
        self._bit_time = float(1000000000) / float(self._bit_rate)

    def run(self):
        # First wait for fsync to go low
        if self.xsi.sample_port_pins(self._fsync) != 0:
            self.wait_for_port_pins_change([self._fsync])

        prev_fsync_val = 0
        prev_bclk_val = 0
        ticks = 0
        fsync_rise_ticks = None
        bitnum = 0
        bits = None
        frame_count = 0
        prev_bclk_high_time = None

        while True:
            self.wait(lambda x:
                       self.xsi.sample_port_pins(self._fsync) != prev_fsync_val
                      or
                       self._bclk.get_val() != prev_bclk_val)
            fsync_val = self.xsi.sample_port_pins(self._fsync)
            bclk_val  = self._bclk.get_val()

            if fsync_val != prev_fsync_val and fsync_val == 1:
                print "Received frame %d" % frame_count
                frame_count += 1
                if fsync_rise_ticks != None:
                    frame_len = (ticks - fsync_rise_ticks)
                    if frame_len != self._samples_per_frame * 32:
                        print "Unexpected frame length: %d" % frame_len
                fsync_rise_ticks = ticks
                bitnum = 0
                bits = []

            if fsync_val != prev_fsync_val and fsync_val == 0:
                if fsync_rise_ticks != None:
                    fsync_len = ticks - fsync_rise_ticks
                    if fsync_len != self._fsync_length:
                        print "ERROR: Unexpected fsync length: %d" % fsync_len

            if bclk_val != prev_bclk_val and bclk_val == 1:
                ticks += 1
                if bits != None:
                    bit = self.xsi.sample_port_pins(self._data)
                    bits.append(bit)
                    bitnum += 1
                if bitnum == 32:
                    data = convert_from_bits(bits)
                    expected = self._expected.next()
                    if data != expected:
                        print "ERROR: data not as expected (%d instead of %d)" % (data, expected)
                    bits = []
                    bitnum = 0
                if prev_bclk_high_time != None:
                    bit_time = self.xsi.get_time() - prev_bclk_high_time
                    pass
                prev_bclk_high_time = self.xsi.get_time()

            prev_fsync_val = fsync_val
            prev_bclk_val = bclk_val

class TDMMasterRxChecker(xmostest.SimThread):

    def __init__(self, fsync, data, bclk, vals,
                 samples_per_frame=8, fsync_length=1, sample_rate=48000):
        super(TDMMasterRxChecker, self).__init__()
        self._fsync = fsync
        self._data = data
        self._bclk = bclk
        self._samples_per_frame = samples_per_frame
        self._vals = vals
        self._fsync_length = fsync_length
        self._sample_rate = sample_rate
        self._bit_rate = sample_rate * samples_per_frame * 32
        self._bit_time = float(1000000000) / float(self._bit_rate)

    def run(self):
        # First wait for fsync to go low
        if self.xsi.sample_port_pins(self._fsync) != 0:
            self.wait_for_port_pins_change([self._fsync])
            self.wait_for_port_pins_change([self._fsync])
            self.wait_for_port_pins_change([self._fsync])

        prev_fsync_val = 0
        prev_bclk_val = 0
        ticks = 0
        fsync_rise_ticks = None
        frame_count = 0
        prev_bclk_high_time = None
        bitnum = 0
        bits = None

        while True:
            self.wait(lambda x:
                       self.xsi.sample_port_pins(self._fsync) != prev_fsync_val
                      or
                       self._bclk.get_val() != prev_bclk_val)
            fsync_val = self.xsi.sample_port_pins(self._fsync)
            bclk_val  = self._bclk.get_val()

            if fsync_val != prev_fsync_val and fsync_val == 1:
                print "Sent frame %d" % frame_count
                frame_count += 1
                if fsync_rise_ticks != None:
                    frame_len = (ticks - fsync_rise_ticks)
                    if frame_len != self._samples_per_frame * 32:
                        print "Unexpected frame length: %d" % frame_len
                fsync_rise_ticks = ticks
                if not bits:
                    bitnum = 0
                    data = self._vals.next()
                    bits = convert_to_bits(data)

            if fsync_val != prev_fsync_val and fsync_val == 0:
                if fsync_rise_ticks != None:
                    fsync_len = ticks - fsync_rise_ticks
                    if fsync_len != self._fsync_length:
                        print "ERROR: Unexpected fsync length: %d" % fsync_len

            if bclk_val != prev_bclk_val and bclk_val == 0:
                if bits:
                    bit = bits[0]
                    bits = bits[1:]
                    self.xsi.drive_port_pins(self._data, bit)
                    bitnum += 1
                    if bitnum == 32:
                        bitnum = 0
                        data = self._vals.next()
                        bits = convert_to_bits(data)

            if bclk_val != prev_bclk_val and bclk_val == 1:
                ticks += 1
                if prev_bclk_high_time != None:
                    bit_time = self.xsi.get_time() - prev_bclk_high_time
                    pass
                prev_bclk_high_time = self.xsi.get_time()

            prev_fsync_val = fsync_val
            prev_bclk_val = bclk_val
