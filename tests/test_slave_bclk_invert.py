# Copyright 2015-2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from i2s_slave_checker import I2SSlaveChecker
from i2s_master_checker import Clock
from pathlib import Path
import Pyxsim
import pytest

num_in_out_args = {"2ch_in,2ch_out": (2, 2)}

@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_i2s_basic_slave(capfd, request, nightly, num_in, num_out):
    testlevel = '0' if nightly else '1'
    id_string = f"{num_in}_{num_out}"
    id_string += "_smoke" if testlevel == '1' else ""

    cwd = Path(request.fspath).parent
    binary = f'{cwd}/i2s_slave_test/bin/{id_string}_inv/i2s_slave_test_{id_string}_inv.xe'

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
         invert_bclk=True, 
         frame_based=False) # We're not running frame-based, so assume 32b data 

    tester = Pyxsim.testers.AssertiveComparisonTester(
        f'{cwd}/expected/bclk_invert.expect',
        regexp = True,
        ordered = True,
        suppress_multidrive_messages=True,
        ignore=["CONFIG:.*"]
    )

    Pyxsim.run_on_simulator(
        binary,
        tester=tester,
        simthreads=[clk, checker],
        build_env = {"NUMS_IN_OUT":f'{num_in};{num_out}', "SMOKE":testlevel, "INVERT":"1"},
        simargs=[],
        capfd=capfd
    )
