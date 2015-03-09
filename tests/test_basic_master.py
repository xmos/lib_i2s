#!/usr/bin/env python
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os

def do_master_test(num_in, num_out, priority_frame_start, testlevel):

    resources = xmostest.request_resource("xsim")

    binary = 'i2s_master_test/bin/{i}{o}{f}/i2s_master_test_{i}{o}{f}.xe'.format(i=num_in, o=num_out,f=priority_frame_start)

    clk = Clock("tile[0]:XS1_PORT_1A")
    
    checker = I2SMasterChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_1H","tile[0]:XS1_PORT_1I","tile[0]:XS1_PORT_1J", "tile[0]:XS1_PORT_1K"],
        ["tile[0]:XS1_PORT_1D","tile[0]:XS1_PORT_1E","tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"],
        "tile[0]:XS1_PORT_1L", 
        "tile[0]:XS1_PORT_16B", 
        "tile[0]:XS1_PORT_1M",
         clk)

    tester = xmostest.ComparisonTester(open('master_test.expect'),
                                     'lib_i2s', 'i2s_master_sim_tests',
                                     'basic_test_in{i}_out{o}'.format(i=num_in, o=num_out), 
                                       {'num_in':num_in, 'num_out':num_out,
                                        'priority_frame_start':priority_frame_start},
                                     regexp=True)

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [clk, checker],
                              #simargs=['--vcd-tracing', '-o ./i2s_master_test/trace.vcd -tile tile[0] -pads -functions -clock-blocks -ports-detailed -instructions'],
                              simargs=[],
                              suppress_multidrive_messages = True,
                              tester = tester)

def runtest():
   do_master_test(4, 4, 1, "smoke")
   do_master_test(4, 4, 0, "smoke")
   do_master_test(4, 0, 0, "nightly")
   do_master_test(0, 4, 0, "nightly")
   do_master_test(4, 0, 1, "nightly")
   do_master_test(0, 4, 1, "nightly")
   return
#    for num_in in [0, 1, 2, 3, 4]:  
#      for num_out in [0, 1, 2, 3, 4]:
#        if num_in + num_out == 0:
#          continue
#        do_master_test(num_in, num_out)

