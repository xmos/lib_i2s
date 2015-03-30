#!/usr/bin/env python
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os

def runtest():

    resources = xmostest.request_resource("xsim")

    binary = 'test_i2s_callback_sequence/bin/i2s_tdm_i2s/test_i2s_callback_sequence_i2s_tdm_i2s.xe'

    tester = xmostest.ComparisonTester(open('sequence_check_44.expect'),
                                     'lib_i2s', 'i2s_tdm_master_sim_tests',
                                     'sequence_check_i2s',
                                     {})

    xmostest.run_on_simulator(resources['xsim'], binary,
                              tester = tester)

