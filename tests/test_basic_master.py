#!/usr/bin/env python
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_mclk import Clock
import os


def do_master_test(clk_speed, num_ports):
    resources = xmostest.request_resource("xsim")

    xmostest.build('i2s_master_test')

    if (clk_speed == 0x4):
      binary = 'i2s_master_test/bin/clk_48_%d/i2s_master_test_clk_48_%d.xe'%\
        (num_ports,num_ports)
    elif (clk_speed == 0x2):
      binary = 'i2s_master_test/bin/clk_441_%d/i2s_master_test_clk_441_%d.xe'%\
        (num_ports,num_ports)

    master_clk = Clock("tile[0]:XS1_PORT_1M", clk_speed)
    
    test_in = ["tile[0]:XS1_PORT_1D", "tile[0]:XS1_PORT_1E", 
               "tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"]
    
    checker_read = I2SMasterChecker("tile[0]:XS1_PORT_1D", 
                               "tile[0]:XS1_PORT_1E", 
                               "tile[0]:XS1_PORT_1F", 
                               "tile[0]:XS1_PORT_1G", 
                               num_ports,
                               "tile[0]:XS1_PORT_1I", 
                               "tile[0]:XS1_PORT_1K", 
                               "tile[0]:XS1_PORT_1L", 
                               "tile[0]:XS1_PORT_1N", 
                               num_ports,
                               "tile[0]:XS1_PORT_1A",
                               "tile[0]:XS1_PORT_1C",
                               0, #0 - read; 1 - write
                               tx_data = [0x99, 0x3A, 0xff],
                               trigger_port = "tile[0]:XS1_PORT_1B")
                               
    checker_write = I2SMasterChecker("tile[0]:XS1_PORT_1D", 
                               "tile[0]:XS1_PORT_1E", 
                               "tile[0]:XS1_PORT_1F", 
                               "tile[0]:XS1_PORT_1G", 
                               num_ports,
                               "tile[0]:XS1_PORT_1I", 
                               "tile[0]:XS1_PORT_1K", 
                               "tile[0]:XS1_PORT_1L", 
                               "tile[0]:XS1_PORT_1N", 
                               num_ports,
                               "tile[0]:XS1_PORT_1A",
                               "tile[0]:XS1_PORT_1C",
                               1, #0 - read; 1 - write
                               tx_data = [0x99, 0x3A, 0xff],
                               trigger_port = "tile[0]:XS1_PORT_1B")

    tester = xmostest.ComparisonTester(open('master_test.expect'),
                                     'lib_i2s', 'i2s_master_sim_tests',
                                     'basic_test', 
                                     {'speed':clk_speed,'num_ports':num_ports},
                                     regexp=True)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [master_clk, checker_read,
                              checker_write],
                              simargs=['--weak-external-drive'],
                              suppress_multidrive_messages = True,
                              tester = tester)

def runtest():
    for num_ports in [4]:
        for clk_speed in [2]:
            do_master_test(clk_speed, num_ports)

