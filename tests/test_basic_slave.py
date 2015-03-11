#!/usr/bin/env python
import xmostest
from i2s_slave_checker import I2SSlaveChecker
from i2s_slave_checker import Clock
import os

def do_slave_test(num_in, num_out):

    resources = xmostest.request_resource("xsim")

    binary = 'i2s_slave_test/bin/{i}{o}/i2s_slave_test_{i}{o}.xe'.format(i=num_in, o=num_out)

    clk = Clock("tile[0]:XS1_PORT_1A")
    
    checker = I2SSlaveChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_1H","tile[0]:XS1_PORT_1I","tile[0]:XS1_PORT_1J", "tile[0]:XS1_PORT_1K"],
        ["tile[0]:XS1_PORT_1D","tile[0]:XS1_PORT_1E","tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"],
        "tile[0]:XS1_PORT_1L", 
        "tile[0]:XS1_PORT_16A", 
        "tile[0]:XS1_PORT_1M",
         clk)

    tester = xmostest.ComparisonTester(open('slave_test.expect'),
                                     'lib_i2s', 'i2s_slave_sim_tests',
                                     'basic_test', 
                                     {'num_in':num_in, 'num_out':num_out},
                                     regexp=True)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [clk, checker],
                              #simargs=['--vcd-tracing', '-o ./i2s_slave_test/trace.vcd -tile tile[0] -ports-detailed'],
                              simargs=[],
                              suppress_multidrive_messages = True,
                              tester = tester)

def runtest():
    do_slave_test(4, 4)
#    for num_in in [0, 1, 2, 3, 4]:  
#      for num_out in [0, 1, 2, 3, 4]:
#        if num_in + num_out == 0:
#          continue
#        do_slave_test(num_in, num_out)

