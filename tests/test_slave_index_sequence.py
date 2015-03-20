#!/usr/bin/env python
import xmostest
from i2s_slave_checker import I2SSlaveChecker
from i2s_slave_checker import Clock
import os

def do_slave_test(num_in, num_out):

    resources = xmostest.request_resource("xsim")

    #xmostest.build('slave_index_sequence_check', build_config="{i}{o}".format(i=num_in, o=num_out))

    binary = 'slave_index_sequence_check/bin/{i}{o}/slave_index_sequence_check_{i}{o}.xe'.format(i=num_in, o=num_out)

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
    tester = xmostest.ComparisonTester(open('slave_sequence_check_{i}{o}.expect'.format(i=num_in, o=num_out)),
                                     'lib_i2s', 'i2s_master_sim_tests',
                                     'seqeuence_check',
                                     {'ins':num_in, 'outs':num_out},
                                     regexp=True)

    xmostest.run_on_simulator(resources['xsim'], binary,
              simthreads = [clk, checker],
              #simargs=['--vcd-tracing', '-o ./i2s_slave_test/trace.vcd -tile tile[0] -ports'],
              tester = tester)

def runtest():
    do_slave_test(1, 1)
    do_slave_test(2, 2)
    do_slave_test(3, 3)
    do_slave_test(4, 4)
