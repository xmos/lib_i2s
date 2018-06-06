# Copyright (c) 2015-2018, XMOS Ltd, All rights reserved
#!/usr/bin/env python2.7
import xmostest
from i2s_master_checker import I2SMasterChecker

if __name__ == "__main__":
    xmostest.init()

    xmostest.register_group("lib_i2s",
                            "i2s_master_sim_tests",
                            "I2S master simulator tests",
    """
Tests are performed by running the I2S library connected to a
simulator model (written as a python plugin to xsim). The simulator
model checks that the signals comply to the I2S specification.
Tests are run to test the following features:

    * Transmission of packets
    * Reception of packets
    * Interface protocol

The tests are run with transactions of varying number of bytes,
varying number of input and output channels. The tests are
run at different sampling rates of 192 KHz to 22.1 KHz.
""")

    xmostest.register_group("lib_i2s",
                            "i2s_frame_master_sim_tests",
                            "I2S frame-based master simulator tests",
    """
Tests are performed by running the I2S library connected to a
simulator model (written as a python plugin to xsim). The simulator
model checks that the signals comply to the I2S specification.
Tests are run to test the following features:

    * Transmission of packets
    * Reception of packets
    * Interface protocol

The tests are run with transactions of varying number of bytes,
varying number of input and output channels. The tests are
run at different sampling rates of 192 KHz to 22.1 KHz.
""")

    xmostest.register_group("lib_i2s",
                            "tdm_master_sim_tests",
                            "TDM master simulator tests",
    """
Tests are performed by running the I2S library connected to a
simulator model (written as a python plugin to xsim). The simulator
model checks that the signals are producing a TDM signal
""")

    xmostest.register_group("lib_i2s",
                            "i2s_slave_sim_tests",
                            "I2S slave simulator tests",
    """
Tests are performed by running the I2S library connected to a
simulator model (written as a python plugin to xsim). The simulator
model checks that the signals comply to the I2S specification.
Tests are run to test the following features:

    * Transmission of packets
    * Reception of packets
    * Interface protocol

The tests are run with transactions of varying number of bytes,
varying number of input and output channels. The tests are
run at different sampling rates of 384 KHz to 22.1 KHz.
""")

    xmostest.register_group("lib_i2s",
                            "i2s_frame_slave_sim_tests",
                            "I2S slave simulator tests",
    """
Tests are performed by running the I2S library connected to a
simulator model (written as a python plugin to xsim). The simulator
model checks that the signals comply to the I2S specification.
Tests are run to test the following features:

    * Transmission of packets
    * Reception of packets
    * Interface protocol

The tests are run with transactions of varying number of bytes,
varying number of input and output channels. The tests are
run at different sampling rates of 384 KHz to 22.1 KHz.
""")


    xmostest.register_group("lib_i2s",
                            "i2s_backpressure_tests",
                            "I2S backpressure tests",
    """
Tests that ensure that an acceptable level of backpressure can be asserted by
the user of the i2s frame based master.
""")

    xmostest.runtests()

    xmostest.finish()
