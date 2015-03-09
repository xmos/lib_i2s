#!/usr/bin/env python
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os

def do_test(ratio, priority_frame_start):

    resources = xmostest.request_resource("xsim")

    if priority_frame_start:
        pf = "_pf"
    else:
        pf = ""

    binary = 'index_sequence_check/bin/{r}{pf}/index_sequence_check_{r}{pf}.xe'.format(r=ratio,pf = pf)

    tester = xmostest.ComparisonTester(open('sequence_check.expect'),
                                     'lib_i2s', 'i2s_master_sim_tests',
                                     'seqeuence_check',
                                       {'ratio':ratio,'priority_frame_start':priority_frame_start},
                                     regexp=True)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              tester = tester)

def runtest():
   do_test(2, False)
   do_test(8, False)
   do_test(2, True)
   do_test(8, True)

