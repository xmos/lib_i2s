# Copyright 2015-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from i2s_master_checker import I2SMasterChecker, Clock
from pathlib import Path
import Pyxsim
import pytest
import json

DEBUG = False

with open(Path(__file__).parent / "i2s_frame_master_test/test_params.json") as f:
    params = json.load(f)
    print(params["I2S_LINES"])

num_in_out_args = {}
for item in params["I2S_LINES"]:
    num_in = item["INPUT"]
    num_out = item["OUTPUT"]
    num_in_out_args[f"{num_in}ch_in,{num_out}"] = [num_in, num_out]


mclk_family = ["mclk_fam_48", "mclk_fam_44"] # The base sampling rate needs to be configured differently for 48KHz vs 44.1KHz family

@pytest.mark.parametrize("mclk_fam", params["MCLK_FAMILIES"], ids=[f"mclk_fam_{mc}" for mc in params["MCLK_FAMILIES"]])
@pytest.mark.parametrize("bitdepth", params["BITDEPTHS"], ids=[f"{bd}b" for bd in params["BITDEPTHS"]])
@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_i2s_basic_frame_master(capfd, request, nightly, bitdepth, num_in, num_out, mclk_fam):
    testlevel = '0' if nightly else '1'
    if (num_in in (0,1,2,3) or num_out in (0,1,2,3)) and not nightly:
        pytest.skip("Only test 4ch modes if not nightly")

    # id_string += "_smoke" if testlevel == '1' else ""


    cwd = Path(request.fspath).parent
    binary = f'{cwd}/i2s_frame_master_test/bin/test_i2s_frame_master_{bitdepth}_{mclk_fam}_{num_in}_{num_out}_{testlevel}.xe'

    clk = Clock("tile[0]:XS1_PORT_1A")

    checker = I2SMasterChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_1H","tile[0]:XS1_PORT_1I","tile[0]:XS1_PORT_1J", "tile[0]:XS1_PORT_1K"],
        ["tile[0]:XS1_PORT_1D","tile[0]:XS1_PORT_1E","tile[0]:XS1_PORT_1F", "tile[0]:XS1_PORT_1G"],
        "tile[0]:XS1_PORT_1L",
        "tile[0]:XS1_PORT_16A",
        "tile[0]:XS1_PORT_1M",
         clk,
         False, # Don't check the bclk stops precisely as the hardware can't do that
         True)  # We're running the frame-based master, so can have variable data widths

    tester = Pyxsim.testers.AssertiveComparisonTester(
        f'{cwd}/expected/master_test.expect',
        regexp = True,
        ordered = True,
        suppress_multidrive_messages=True,
        ignore=["CONFIG:.*"]
    )

    if DEBUG:
        Pyxsim.run_on_simulator_(
            binary,
            tester=tester,
            do_xe_prebuild=False,
            simthreads=[clk, checker],
            simargs=[
                    "--vcd-tracing",
                    f"-o i2s_trace_{num_in}_{num_out}.vcd -tile tile[0] -cycles -ports -ports-detailed -cores -instructions -clock-blocks",
                    "--trace-to",
                    f"i2s_trace_{num_in}_{num_out}.txt",
                ],
            capfd=capfd
        )
    else:
        Pyxsim.run_on_simulator_(
            binary,
            tester=tester,
            do_xe_prebuild=False,
            simthreads=[clk, checker],
            simargs=[],
            capfd=capfd
        )
