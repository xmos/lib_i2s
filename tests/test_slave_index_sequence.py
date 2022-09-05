# Copyright 2015-2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from i2s_slave_checker import I2SSlaveChecker
from i2s_master_checker import Clock
from pathlib import Path
import Pyxsim
import pytest

num_in_out_args = {"4ch_in,4ch_out": (4, 4),
                   "1ch_in,1ch_out": (1, 1),
                   "4ch_in,0ch_out": (4, 0),
                   "0ch_in,4ch_out": (0, 4),
                   "2ch_in,2ch_out": (2, 2),
                   "3ch_in,3ch_out": (3, 3)}

@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_i2s_basic_slave(capfd, request, nightly, num_in, num_out):
    if (num_in in (1,2,3) or num_out in (1,2,3)) and not nightly:
        pytest.skip("Only test 4ch modes if not nightly")
    testlevel = '0' if nightly else '1'
    id_string = f"{num_in}_{num_out}"
    id_string += "_smoke" if testlevel == '1' else ""

    cwd = Path(request.fspath).parent
    binary = f'{cwd}/test_i2s_callback_sequence/bin/slave_{id_string}/test_i2s_callback_sequence_slave_{id_string}.xe'

    clk = Clock("tile[0]:XS1_PORT_1A")

    checker = I2SSlaveChecker(
        "tile[0]:XS1_PORT_1B",
        "tile[0]:XS1_PORT_1C",
        [],
        [],
        "tile[0]:XS1_PORT_1L",
        "tile[0]:XS1_PORT_16A",
        "tile[0]:XS1_PORT_1M",
         clk,
         no_start_msg=True
    )

    tester = Pyxsim.testers.AssertiveComparisonTester(
        f'{cwd}/expected/sequence_check_{num_out}{num_in}.expect',
        regexp = True,
        ordered = True,
        suppress_multidrive_messages=True,
        ignore=["CONFIG:.*"]
    )

    Pyxsim.run_on_simulator(
        binary,
        tester=tester,
        simthreads=[clk, checker],
        build_env = {"NUMS_IN_OUT":f'{num_in};{num_out}', "SMOKE":testlevel, "MASTER":"0"},
        simargs=[],
        capfd=capfd
    )
