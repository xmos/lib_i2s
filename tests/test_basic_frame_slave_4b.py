# Copyright 2015-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import xmostest
from i2s_slave_checker import I2SSlaveChecker
from i2s_slave_checker import Clock
import os


def do_frame_slave_test(data_bits, num_in, num_out, testlevel):

    resources = xmostest.request_resource("xsim")

    id_string = "{tl}_{db}{i}{o}".format(
        db=data_bits, i=num_in, o=num_out, tl=testlevel
    )

    binary = "i2s_frame_slave_4b_test/bin/{id}/i2s_frame_slave_4b_test_{id}.xe".format(
        id=id_string
    )

    clk = Clock("tile[0]:XS1_PORT_1A")

    checker = I2SSlaveChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        [
            "tile[0]:XS1_PORT_4F.3",
            "tile[0]:XS1_PORT_4F.2",
            "tile[0]:XS1_PORT_4F.1",
            "tile[0]:XS1_PORT_4F.0",
        ],
        [
            "tile[0]:XS1_PORT_4E.3",
            "tile[0]:XS1_PORT_4E.2",
            "tile[0]:XS1_PORT_4E.1",
            "tile[0]:XS1_PORT_4E.0",
        ],
        "tile[0]:XS1_PORT_1L",
        "tile[0]:XS1_PORT_16A",
        "tile[0]:XS1_PORT_1M",
        clk,
        frame_based=True,
    )

    tester = xmostest.ComparisonTester(
        open("slave_test.expect"),
        "lib_i2s",
        "i2s_frame_slave_sim_tests",
        "basic_test_%s" % testlevel,
        {"num_in": num_in, "num_out": num_out, "data_bits": data_bits},
        regexp=True,
        ignore=["CONFIG:.*"],
    )

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(
        resources["xsim"],
        binary,
        simthreads=[clk, checker],
        # simargs=[],
        simargs=[
            "--trace-to",
            "./i2s_frame_slave_4b_test/logs/sim_{id}.log".format(id=id_string),
            "--vcd-tracing",
            "-o ./i2s_frame_slave_4b_test/traces/trace_{id}.vcd -tile tile[0] -ports-detailed -functions -cycles -clock-blocks -cores -instructions".format(
                id=id_string
            ),
        ],
        suppress_multidrive_messages=True,
        tester=tester,
    )


def runtest():
    db = 32
    do_frame_slave_test(db, 4, 4, "smoke")
    do_frame_slave_test(db, 4, 0, "smoke")
    do_frame_slave_test(db, 0, 4, "smoke")
    do_frame_slave_test(db, 4, 4, "nightly")
