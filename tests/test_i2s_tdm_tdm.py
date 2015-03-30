#!/usr/bin/env python
import xmostest
import os
from tdm_checker import TDMMasterChecker


def runtest():
    resources = xmostest.request_resource("xsim")

    binary = 'i2s_tdm_master_test/bin/tdm/i2s_tdm_master_test_tdm.xe'

    checker = TDMMasterChecker(
        "tile[0]:XS1_PORT_1A",
        "tile[0]:XS1_PORT_1N",
        ["tile[0]:XS1_PORT_1O"],
        ["tile[0]:XS1_PORT_1P"],
        "tile[0]:XS1_PORT_1L", 
        "tile[0]:XS1_PORT_16A", 
        "tile[0]:XS1_PORT_1M",
        extra_clocks = 16)

    tester = xmostest.ComparisonTester(open('tdm_cb_test.expect'),
                                     'lib_i2s', 'i2s_tdm_master_sim_tests',
                                     'tdm_test',
                                     {},
                                       regexp=True,
                                       ignore=["CONFIG:"])

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [checker],
                              tester = tester,
                              simargs = ['--vcd-tracing','-o ttt.vcd -tile tile[0] -ports'])

    return


