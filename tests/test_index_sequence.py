# Copyright (c) 2015-2018, XMOS Ltd, All rights reserved
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os

def do_test(num_in, num_out, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_i2s_callback_sequence/bin/master_{o}{i}/test_i2s_callback_sequence_master_{o}{i}.xe'.format(i=num_in, o=num_out)

    tester = xmostest.ComparisonTester(open('sequence_check_{o}{i}.expect'.format(i=num_in, o=num_out)),
                                     'lib_i2s', 'i2s_master_sim_tests',
                                     'sequence_check',
                                     {'ins':num_in, 'outs':num_out})

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              tester = tester)

def runtest():
    do_test(4, 4, "smoke")
    do_test(4, 0, "smoke")
    do_test(0, 4, "smoke")
    do_test(1, 1, "nightly")
    do_test(2, 2, "nightly")
    do_test(3, 3, "nightly")

