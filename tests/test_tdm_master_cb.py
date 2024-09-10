# Copyright 2015-2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from tdm_checker import TDMMasterChecker
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
def test_tdm_master_cb(capfd, request, nightly, num_in, num_out):
    testlevel = '0' if nightly else '1'

    cwd = Path(request.fspath).parent

    cfg = f"{num_in}_{num_out}_{testlevel}"
    binary = f'{cwd}/tdm_master_cb_test/bin/{cfg}/test_tdm_master_cb_{cfg}.xe'
    assert Path(binary).exists(), f"Cannot find {binary}"

    checker = TDMMasterChecker(
        "tile[0]:XS1_PORT_1A",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_1H","tile[0]:XS1_PORT_1I","tile[0]:XS1_PORT_1J", "tile[0]:XS1_PORT_1K"],
        ["tile[0]:XS1_PORT_1D","tile[0]:XS1_PORT_1E","tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"],
        "tile[0]:XS1_PORT_1L",
        "tile[0]:XS1_PORT_16A",
        "tile[0]:XS1_PORT_1M")

    tester = Pyxsim.testers.AssertiveComparisonTester(
        f'{cwd}/expected/tdm_cb_test.expect',
        regexp = True,
        ordered = True,
        suppress_multidrive_messages=True,
        ignore=["CONFIG:.*"]
    )

    Pyxsim.run_on_simulator_(
        binary,
        tester=tester,
        simthreads=[checker],
        do_xe_prebuild=False,
        simargs=[],
        capfd=capfd
    )
