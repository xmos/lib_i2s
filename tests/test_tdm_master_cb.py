#!/usr/bin/env python
import xmostest
import os
from tdm_checker import TDMMasterChecker

def do_test(num_in, num_out, testlevel):
    resources = xmostest.request_resource("xsim")

    binary = 'tdm_master_cb_test/bin/{t}_{i}{o}/tdm_master_cb_test_{t}_{i}{o}.xe'.format(i=num_in, o=num_out, t = testlevel)

   
    checker = TDMMasterChecker(
        "tile[0]:XS1_PORT_1A",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_1H","tile[0]:XS1_PORT_1I","tile[0]:XS1_PORT_1J", "tile[0]:XS1_PORT_1K"],
        ["tile[0]:XS1_PORT_1D","tile[0]:XS1_PORT_1E","tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"],
        "tile[0]:XS1_PORT_1L", 
        "tile[0]:XS1_PORT_16A", 
        "tile[0]:XS1_PORT_1M")

    tester = xmostest.ComparisonTester(open('tdm_cb_test.expect'),
                                     'lib_i2s', 'tdm_master_sim_tests',
                                     'basic_test_%s'%testlevel,
                                     {'num_in':num_in, 'num_out':num_out},
                                       regexp=True,
                                       ignore=["CONFIG:"])

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [checker],
                              #simargs=[],
                              simargs=['--vcd-tracing', '-o ./tdm_master_cb_test/trace.vcd -tile tile[0] -ports-detailed'],
                              suppress_multidrive_messages = True,
                              tester = tester)


def runtest():
    do_test(2, 2, "smoke")
    do_test(4, 4, "smoke")
    do_test(0, 4, "smoke")
    do_test(4, 0, "smoke")
    do_test(4, 4, "nightly")
    return


