# Copyright (c) 2015-2021, XMOS Ltd, All rights reserved
# This software is available under the terms provided in LICENSE.txt.
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os

def do_master_test(num_in, num_out, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'i2s_master_test/bin/{tl}_{i}{o}/i2s_master_test_{tl}_{i}{o}.xe'.format(i=num_in, o=num_out,tl=testlevel)

    clk = Clock("tile[0]:XS1_PORT_1A")


    checker = I2SMasterChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_1H","tile[0]:XS1_PORT_1I","tile[0]:XS1_PORT_1J", "tile[0]:XS1_PORT_1K"],
        ["tile[0]:XS1_PORT_1D","tile[0]:XS1_PORT_1E","tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"],
        "tile[0]:XS1_PORT_1L",
        "tile[0]:XS1_PORT_16A",
        "tile[0]:XS1_PORT_1M",
         clk)

    tester = xmostest.ComparisonTester(open('master_test.expect'),
                                       'lib_i2s', 'i2s_master_sim_tests',
                                       'basic_test_%s'%testlevel, {'num_in':num_in, 'num_out':num_out},ignore=["CONFIG:.*"])

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [clk, checker],
                              simargs=[],
                              suppress_multidrive_messages = True,
                              tester = tester)

def runtest():
   do_master_test(4, 4, "smoke")
   do_master_test(1, 1, "smoke")
   do_master_test(4, 0, "smoke")
   do_master_test(0, 4, "smoke")
   do_master_test(4, 4, "nightly")

