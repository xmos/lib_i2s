# Copyright 2015-2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from i2s_master_checker import Clock
from i2s_slave_checker import I2SSlaveChecker
from pathlib import Path
import Pyxsim
import pytest

num_in_out_args = {"4ch_in,4ch_out": (4, 4),
                   "1ch_in,1ch_out": (1, 1),
                   "4ch_in,0ch_out": (4, 0),
                   "0ch_in,4ch_out": (0, 4)}

@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_i2s_basic_frame_slave_4b(capfd, request, nightly, num_in, num_out):
    testlevel = '0' if nightly else '1'
    id_string = f"{num_in}_{num_out}"
    id_string += "_smoke" if testlevel == '1' else ""

    cwd = Path(request.fspath).parent
    binary = f'{cwd}/i2s_frame_slave_4b_/bin/{id_string}/i2s_frame_slave_4b_test_{id_string}.xe'

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
         False, # Don't check the bclk stops precisely as the hardware can't do that
         True)  # We're running the frame-based master, so can have variable data widths

    tester = Pyxsim.testers.AssertiveComparisonTester(
        f'{cwd}/expected/slave_test.expect',
        regexp = True,
        ordered = True,
        suppress_multidrive_messages=True,
        ignore=["CONFIG:.*"]
    )

    Pyxsim.run_on_simulator(
        binary,
        tester=tester,
        simthreads=[clk, checker],
        build_env = {"NUMS_IN_OUT":f'{num_in};{num_out}', "SMOKE":testlevel},
        simargs=[],
        capfd=capfd
    )
