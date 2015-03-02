#!/usr/bin/env python
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
     
The tests are run with transactions of varying number of bytes, 
varying number of input and output channels. The tests are 
run at different sampling rates of 44.1 KHz and 48 KHz.
""")

    # xmostest.runtests()

    xmostest.finish()
