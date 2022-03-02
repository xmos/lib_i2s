# Copyright 2016-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import xmostest

def do_test(sample_rate, num_channels, data_bits, receive_increment, send_increment, testlevel):

    resources = xmostest.request_resource("xsim")

    id_string = "{db}_{sr}_{nc}_{ri}_{si}".format(
      db=data_bits, sr=sample_rate, nc=num_channels, ri=receive_increment, si=send_increment)

    binary = 'backpressure_test/bin/{id}/backpressure_test_{id}.xe'.format(id=id_string)

    tester = xmostest.ComparisonTester(
      open('backpressure_test.expect'),
       'lib_i2s', 'i2s_backpressure_tests', 'backpressure_%s'%testlevel,
       {'data_bits':data_bits,
        'sample_rate':sample_rate,
        'num_channels':num_channels,
        'receive_increment':receive_increment,
        'send_increment':send_increment})

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simargs=[],
                              #simargs=['--trace-to', './backpressure_test/logs/sim_{id}.log'.format(id=id_string), 
                              #         '--vcd-tracing', '-o ./backpressure_test/traces/trace_{id}.vcd -tile tile[0] -ports-detailed -functions -cycles -clock-blocks -cores -instructions'.format(id=id_string)],
                              loopback=[{'from': 'tile[0]:XS1_PORT_1G',
                                         'to': 'tile[0]:XS1_PORT_1A'}],
                              suppress_multidrive_messages=True,
                              tester=tester)

def runtest():
  for sample_rate in [768000, 384000, 192000]:
    for data_bits in [8, 16, 32]:
      for num_channels in [1, 2, 3, 4]:
        do_test(sample_rate, num_channels, data_bits, 5,  5, "smoke" if (num_channels == 4) else "nightly")
        do_test(sample_rate, num_channels, data_bits, 0, 10, "smoke" if (num_channels == 4) else "nightly")
        do_test(sample_rate, num_channels, data_bits, 10, 0, "smoke" if (num_channels == 4) else "nightly")

