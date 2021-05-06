# Copyright 2015-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import xmostest
from i2s_slave_checker import I2SSlaveChecker
from i2s_slave_checker import Clock
import os

def do_slave_test(num_in, num_out, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'test_i2s_callback_sequence/bin/slave_{o}{i}/test_i2s_callback_sequence_slave_{o}{i}.xe'.format(i=num_in, o=num_out)

    clk = Clock("tile[0]:XS1_PORT_1A")
    
    checker = I2SSlaveChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        [],
#"tile[0]:XS1_PORT_1H","tile[0]:XS1_PORT_1I","tile[0]:XS1_PORT_1J", "tile[0]:XS1_PORT_1K"],
        [],
#["tile[0]:XS1_PORT_1D","tile[0]:XS1_PORT_1E","tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"],
        "tile[0]:XS1_PORT_1L", 
        "tile[0]:XS1_PORT_16A", 
        "tile[0]:XS1_PORT_1M",
         clk,
        no_start_msg = True)

    tester = xmostest.ComparisonTester(open('sequence_check_{o}{i}.expect'.format(i=num_in, o=num_out)),
                                     'lib_i2s', 'i2s_slave_sim_tests',
                                     'sequence_check',
                                       {'ins':num_in, 'outs':num_out},
                                       ignore=['CONFIG:.*'])

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
              simthreads = [clk, checker],
              #simargs=['--vcd-tracing', '-o ./test_i2s_callback_sequence/trace.vcd -tile tile[0] -ports'],
              tester = tester)

def runtest():
    do_slave_test(4, 4, "smoke")
    do_slave_test(4, 0, "smoke")
    do_slave_test(0, 4, "smoke")
    do_slave_test(1, 1, "nightly")
    do_slave_test(2, 2, "nightly")
    do_slave_test(3, 3, "nightly")
