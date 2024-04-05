# Copyright 2015-2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from i2s_master_checker import I2SMasterChecker, Clock
from pathlib import Path
import Pyxsim
import pytest

num_in_out_args = {"4ch_in,4ch_out": (4, 4),
                   "1ch_in,1ch_out": (1, 1),
                   "4ch_in,0ch_out": (4, 0),
                   "0ch_in,4ch_out": (0, 4)}

bitdepth_args = {"8b": 8,
                 "16b": 16,
                 "24b": 24,
                 "32b": 32}

mclk_family = ["mclk_fam_48", "mclk_fam_44"] # The base sampling rate needs to be configured differently for 48KHz vs 44.1KHz family

@pytest.mark.parametrize("mclk_fam", mclk_family)
@pytest.mark.parametrize("bitdepth", bitdepth_args.values(), ids=bitdepth_args.keys())
@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_i2s_basic_frame_master(capfd, request, nightly, bitdepth, num_in, num_out, mclk_fam):
    testlevel = '0' if nightly else '1'
    if (num_in in (0,1,2,3) or num_out in (0,1,2,3)) and not nightly:
        pytest.skip("Only test 4ch modes if not nightly")

    if mclk_fam == "mclk_fam_48":
        mclk_fam = 48
    else:
        mclk_fam = 44

    id_string = f"{bitdepth}_{num_in}_{num_out}_{mclk_fam}"
    id_string += "_smoke" if testlevel == '1' else ""


    cwd = Path(request.fspath).parent
    binary = f'{cwd}/i2s_frame_master_test/bin/{id_string}/i2s_frame_master_test_{id_string}.xe'

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

    Pyxsim.run_on_simulator(
        binary,
        tester=tester,
        #clean_before_build=True,
        simthreads=[clk, checker],
        build_env = {"BITDEPTHS":f"{bitdepth}", "NUMS_IN_OUT":f'{num_in};{num_out}', "SMOKE":testlevel, "MCLK_FAMILY":f'{mclk_fam}'},
        simargs=[],
        capfd=capfd
    )
