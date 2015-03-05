#!/usr/bin/env python
import xmostest
import os
from tdm_checker import TDMMasterTxChecker, Clock

def expected_vals():
    i = 1
    while True:
        for j in range(8):
            yield j  +  (1 << i)
        i += 1

expected_output = "\n".join(["Received frame %d" % x for x in range(31)])

def runtest():
    resources = xmostest.request_resource("xsim")

    xmostest.build('tdm_master_tx_test')

    binary = 'tdm_master_tx_test/bin/tdm_master_tx_test.xe'

    tester = xmostest.ComparisonTester(expected_output,
                                     'lib_i2s', 'tdm_master_sim_tests',
                                     'tx_test',
                                     {},
                                     regexp=True)

    clk = Clock("tile[0]:XS1_PORT_1E", 12288000)
    tdm_checker = TDMMasterTxChecker("tile[0]:XS1_PORT_1A",
                                     "tile[0]:XS1_PORT_1B",
                                     clk,
                                     expected_vals(),
                                     samples_per_frame = 8,
                                     fsync_length=1,
                                     sample_rate=48000)


    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [clk, tdm_checker],
                              tester = tester)


