#!/usr/bin/env python
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_mclk import Clock
import os


def do_master_test(clk_speed):
    resources = xmostest.request_resource("xsim")

    xmostest.build('i2s_master_test')

    binary = 'i2s_master_test/bin/tx_rx/i2s_master_test_tx_rx.xe'

    master_clk = Clock("tile[0]:XS1_PORT_1M", clk_speed)

    checker_read = I2SMasterChecker("tile[0]:XS1_PORT_1D", 1,
                               "tile[0]:XS1_PORT_1I", 1,
                               "tile[0]:XS1_PORT_1A",
                               "tile[0]:XS1_PORT_1C",
                               0, #0 - read; 1 - write
                               tx_data = [0x99, 0x3A, 0xff],
                               trigger_port = "tile[0]:XS1_PORT_1B")
                               
    checker_write = I2SMasterChecker("tile[0]:XS1_PORT_1D", 1,
                               "tile[0]:XS1_PORT_1I", 1,
                               "tile[0]:XS1_PORT_1A",
                               "tile[0]:XS1_PORT_1C",
                               1, #0 - read; 1 - write
                               tx_data = [0x99, 0x3A, 0xff],
                               trigger_port = "tile[0]:XS1_PORT_1B")

    tester = xmostest.ComparisonTester(open('master_test.expect'),
                                     'lib_i2s', 'i2s_master_sim_tests',
                                     'basic_test', {'speed':clk_speed},
                                     regexp=True)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [master_clk, checker_read,
                              checker_write],
                              simargs=['--weak-external-drive'],
                              suppress_multidrive_messages = True,
                              tester = tester)

def runtest():
    for clk_speed in [4]:
        do_master_test(clk_speed)

