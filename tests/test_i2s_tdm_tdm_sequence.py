#!/usr/bin/env python
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os
def runtest():
    resources = xmostest.request_resource("xsim")

    binary = 'test_i2s_callback_sequence/bin/i2s_tdm_tdm/test_i2s_callback_sequence_i2s_tdm_tdm.xe'

    tester = xmostest.ComparisonTester(open('tdm_sequence_check_118.expect'),                                    'lib_i2s', 'i2s_tdm_master_sim_tests',
                                     'sequence_check_tdm',
                                       {})

    xmostest.run_on_simulator(resources['xsim'], binary,
                              tester = tester)

