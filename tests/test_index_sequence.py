#!/usr/bin/env python
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os

def do_test(ratio):

    resources = xmostest.request_resource("xsim")

    binary = 'index_sequence_check/bin/{r}/index_sequence_check_{r}.xe'.format(r=ratio)

    tester = xmostest.ComparisonTester(open('sequence_check.expect'),
                                     'lib_i2s', 'i2s_master_sim_tests',
                                     'seqeuence_check',
                                     {'ratio':ratio},
                                     regexp=True)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              tester = tester)

def runtest():
   do_test(2)
   do_test(8)

