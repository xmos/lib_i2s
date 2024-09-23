# Copyright 2015-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from i2s_master_checker import Clock
from i2s_slave_checker import I2SSlaveChecker
from pathlib import Path
import Pyxsim
import pytest
import json

DEBUG = False

with open(Path(__file__).parent / "i2s_frame_slave_test/test_params.json") as f:
    params = json.load(f)

num_in_out_args = {}
for item in params["I2S_LINES"]:
    num_in = item["INPUT"]
    num_out = item["OUTPUT"]
    num_in_out_args[f"{num_in}ch_in,{num_out}"] = [num_in, num_out]


@pytest.mark.parametrize("bitdepth", params["BITDEPTHS"], ids=[f"{bd}b" for bd in params["BITDEPTHS"]])
@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
@pytest.mark.parametrize(("invert"), params["INVERT"], ids=[f"INVERT{i}" for i in params["INVERT"]])
def test_i2s_basic_frame_slave(capfd, request, nightly, bitdepth, num_in, num_out, invert):
    testlevel = '0' if nightly else '1'

    cwd = Path(request.fspath).parent

    cfg = f"{bitdepth}_{invert}_{num_in}_{num_out}_{testlevel}"
    binary = f'{cwd}/i2s_frame_slave_test/bin/{cfg}/test_i2s_frame_slave_{cfg}.xe'
    assert Path(binary).exists(), f"Cannot find {binary}"

    clk = Clock("tile[0]:XS1_PORT_1A")

    checker = I2SSlaveChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_1H","tile[0]:XS1_PORT_1I","tile[0]:XS1_PORT_1J", "tile[0]:XS1_PORT_1K"],
        ["tile[0]:XS1_PORT_1D","tile[0]:XS1_PORT_1E","tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"],
        "tile[0]:XS1_PORT_1L",
        "tile[0]:XS1_PORT_16A",
        "tile[0]:XS1_PORT_1M",
         clk,
         frame_based=True)  # We're running the frame-based master, so can have variable data widths

    tester = Pyxsim.testers.AssertiveComparisonTester(
        f'{cwd}/expected/slave_test.expect',
        regexp = True,
        ordered = True,
        suppress_multidrive_messages=True,
        ignore=["CONFIG:.*"]
    )

    if DEBUG:
        Pyxsim.run_on_simulator_(
            binary,
            tester=tester,
            simthreads=[clk, checker],
            do_xe_prebuild=False,
            simargs=[
                "--vcd-tracing",
                f"-o i2s_trace_{num_in}_{num_out}.vcd -tile tile[0] -cycles -ports -ports-detailed -cores -instructions",
                "--trace-to",
                f"i2s_trace_{num_in}_{num_out}.txt",
            ],
            capfd=capfd
        )
    else:
        Pyxsim.run_on_simulator_(
            binary,
            tester=tester,
            simthreads=[clk, checker],
            do_xe_prebuild=False,
            simargs=[],
            capfd=capfd
        )
