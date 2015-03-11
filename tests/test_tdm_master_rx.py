#!/usr/bin/env python
import xmostest
import os
from tdm_checker import TDMMasterRxChecker, Clock

def vals():
    i = 0
    while True:
        for j in range(8):
            yield j  +  (1 << i)
        i += 1

expected_output = "\n".join(["Sent frame %d" % x for x in range(11)])

def do_test(config):
    resources = xmostest.request_resource("xsim")

    binary = 'tdm_master_rx_test/bin/tdm_master_rx_test.xe'

    tester = xmostest.ComparisonTester(expected_output,
                                     'lib_i2s', 'tdm_master_sim_tests',
                                     'rx_test',
                                     config,)

    clk = Clock("tile[0]:XS1_PORT_1E", config['mclk'])

    sample_rate = config['mclk'] / 32 / config['samples_per_frame']

    tdm_checker = TDMMasterRxChecker("tile[0]:XS1_PORT_1A",
                                     "tile[0]:XS1_PORT_1B",
                                     clk,
                                     vals(),
                                     samples_per_frame = config['samples_per_frame'],
                                     fsync_length=config['fsync_len'],
                                     sample_rate=sample_rate)


    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [clk, tdm_checker],
                              tester = tester,
                              simargs=['--vcd-tracing','-o ttt.vcd -tile tile[0] -ports'])


def runtest():
    return
    config = {}
    config['mclk'] = 12288000
    config['fsync_len'] = 1
    config['samples_per_frame'] = 8
    do_test(config)


