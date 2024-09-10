# Copyright 2015-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from i2s_master_checker import Clock
from i2s_slave_checker import I2SSlaveChecker
from pathlib import Path
import Pyxsim
import pytest
import json

with open(Path(__file__).parent / "i2s_frame_slave_test/test_params.json") as f:
    params = json.load(f)

num_in_out_args = {}
for item in params["I2S_LINES"]:
    num_in = item["INPUT"]
    num_out = item["OUTPUT"]
    num_in_out_args[f"{num_in}ch_in,{num_out}"] = [num_in, num_out]


@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
@pytest.mark.parametrize(("invert"), params["INVERT"], ids=[f"INVERT{i}" for i in params["INVERT"]])
def test_i2s_basic_frame_slave_4b(capfd, request, nightly, invert, num_in, num_out):
    testlevel = '0' if nightly else '1'

    cfg = f"{invert}_{num_in}_{num_out}_{testlevel}"
    cwd = Path(request.fspath).parent
    binary = f'{cwd}/i2s_frame_slave_4b_test/bin/{cfg}/test_i2s_frame_slave_4b_{cfg}.xe'
    assert Path(binary).exists(), f"Cannot find {binary}"

    clk = Clock("tile[0]:XS1_PORT_1A")

    checker = I2SSlaveChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_4F.3","tile[0]:XS1_PORT_4F.2","tile[0]:XS1_PORT_4F.1", "tile[0]:XS1_PORT_4F.0"],
        ["tile[0]:XS1_PORT_4E.3","tile[0]:XS1_PORT_4E.2","tile[0]:XS1_PORT_4E.1", "tile[0]:XS1_PORT_4E.0"],
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

    Pyxsim.run_on_simulator_(
        binary,
        tester=tester,
        simthreads=[clk, checker],
        do_xe_prebuild=False,
        simargs=[],
        capfd=capfd
    )
