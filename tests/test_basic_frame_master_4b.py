# Copyright 2015-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import xmostest
from i2s_master_checker import I2SMasterChecker
from i2s_master_checker import Clock
import os


def do_master_test(data_bits, num_in, num_out, testlevel):

    resources = xmostest.request_resource("xsim")

    id_string = "{tl}_{db}{i}{o}".format(
        db=data_bits, i=num_in, o=num_out, tl=testlevel
    )

    binary = (
        "i2s_frame_master_4b_test/bin/{id}/i2s_frame_master_4b_test_{id}.xe".format(
            id=id_string
        )
    )

    clk = Clock("tile[0]:XS1_PORT_1A")

    checker = I2SMasterChecker(
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
        False,  # Don't check the bclk stops precisely as the hardware can't do that
        True,  # We're running the frame-based master, so can have variable data widths
    )

    tester = xmostest.ComparisonTester(
        open("master_test.expect"),
        "lib_i2s",
        "i2s_frame_master_4b_sim_tests",
        "basic_test_%s" % testlevel,
        {"data_bits": data_bits, "num_in": num_in, "num_out": num_out},
        ignore=["CONFIG:.*"],
    )

    tester.set_min_testlevel(testlevel)

    xmostest.run_on_simulator(
        resources["xsim"],
        binary,
        simthreads=[clk, checker],
        simargs=[],
        # simargs=[
        #     "--trace-to",
        #     "./i2s_frame_master_4b_test/logs/sim_{id}.log".format(id=id_string),
        #     "--vcd-tracing",
        #     "-o ./i2s_frame_master_4b_test/traces/trace_{id}.vcd -tile tile[0] -ports-detailed -functions -cycles -clock-blocks -cores -instructions".format(
        #         id=id_string
        #     ),
        # ],
        suppress_multidrive_messages=True,
        tester=tester,
    )


def runtest():
    # for db in 32:
    do_master_test(32, 4, 4, "smoke")
    do_master_test(32, 1, 1, "smoke")
    do_master_test(32, 4, 0, "smoke")
    do_master_test(32, 0, 4, "smoke")
    do_master_test(32, 4, 4, "nightly")
