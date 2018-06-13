# Copyright (c) 2015-2018, XMOS Ltd, All rights reserved
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os

def do_test(num_in, num_out, chans_per_frame, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_i2s_callback_sequence/bin/tdm_{o}{i}{C}/test_i2s_callback_sequence_tdm_{o}{i}{C}.xe'.format(i=num_in, o=num_out, C=chans_per_frame)

    tester = xmostest.ComparisonTester(open('tdm_sequence_check_{o}{i}{C}.expect'.format(i=num_in, o=num_out, C=chans_per_frame)),
                                     'lib_i2s', 'tdm_master_sim_tests',
                                     'sequence_check',
                                       {'ins':num_in, 'outs':num_out, 'chans_per_frame':chans_per_frame})

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              tester = tester)

def runtest():
    do_test(1, 1, 8, "smoke")
    do_test(1, 0, 8, "smoke")
    do_test(0, 1, 8, "smoke")
    do_test(2, 2, 4, "nightly")

