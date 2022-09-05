# Copyright 2015-2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from tdm_checker import TDMMasterChecker
from pathlib import Path
import Pyxsim
import pytest

num_in_out_args = {"4ch_in,4ch_out": (4, 4),
                   "2ch_in,2ch_out": (2, 2),
                   "4ch_in,0ch_out": (4, 0),
                   "0ch_in,4ch_out": (0, 4)}

@pytest.mark.parametrize(("num_in", "num_out"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_tdm_master_cb(capfd, request, nightly, num_in, num_out):
    testlevel = '0' if nightly else '1'
    id_string = f"{num_in}_{num_out}"
    id_string += "_smoke" if testlevel == '1' else ""

    cwd = Path(request.fspath).parent
    binary = f'{cwd}/tdm_master_cb_test/bin/{id_string}/tdm_master_cb_test_{id_string}.xe'

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

    Pyxsim.run_on_simulator(
        binary,
        tester=tester,
        simthreads=[checker],
        build_env = {"NUMS_IN_OUT":f'{num_in};{num_out}', "SMOKE":testlevel},
        simargs=[],
        capfd=capfd
    )
