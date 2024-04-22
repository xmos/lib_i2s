# Copyright 2015-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from i2s_master_checker import I2SMasterChecker, Clock
from pathlib import Path
import Pyxsim
import pytest

num_in_out_args = {"4ch_in,4ch_out": (4, 4),
                   "1ch_in,1ch_out": (1, 1),
                   "4ch_in,0ch_out": (4, 0),
                   "0ch_in,4ch_out": (0, 4)}

mclk_family = ["mclk_fam_48", "mclk_fam_44"] # The base sampling rate needs to be configured differently for 48KHz vs 44.1KHz family

@pytest.mark.parametrize("mclk_fam", mclk_family)
@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_i2s_basic_frame_master_4b(capfd, request, nightly, num_in, num_out, mclk_fam):
    if mclk_fam == "mclk_fam_48":
        mclk_fam = 48
    else:
        mclk_fam = 44

    id_string = f"{num_in}_{num_out}_{mclk_fam}"

    cwd = Path(request.fspath).parent
    binary = f'{cwd}/i2s_frame_master_4b_test/bin/{id_string}/i2s_frame_master_4b_test_{id_string}.xe'

    clk = Clock("tile[0]:XS1_PORT_1A")

    checker = I2SMasterChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        ["tile[0]:XS1_PORT_4F.3","tile[0]:XS1_PORT_4F.2","tile[0]:XS1_PORT_4F.1", "tile[0]:XS1_PORT_4F.0"],
        ["tile[0]:XS1_PORT_4E.3","tile[0]:XS1_PORT_4E.2","tile[0]:XS1_PORT_4E.1", "tile[0]:XS1_PORT_4E.0"],
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

    Pyxsim.run_on_simulator(
        binary,
        tester=tester,
        simthreads=[clk, checker],
        clean_before_build=True,
        build_env = {"NUMS_IN_OUT":f'{num_in};{num_out}', "MCLK_FAMILY":f'{mclk_fam}'},
        simargs=[],
        capfd=capfd
    )
