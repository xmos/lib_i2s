# Copyright 2015-2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from pathlib import Path
import Pyxsim
import pytest

num_in_out_args = {"1ch_in,1ch_out,8ch": (1, 1, 8),
                   "1ch_in,0ch_out,8ch": (1, 0, 8),
                   "0ch_in,1ch_out,8ch": (0, 1, 8),
                   "2ch_in,2ch_out,4ch": (2, 2, 4)}

@pytest.mark.parametrize(("num_in", "num_out", "num_chan"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_index_sequence(capfd, request, nightly, num_in, num_out, num_chan):
    if (num_chan == 4) and not nightly:
        pytest.skip("Only test non-8chan modes if nightly")

    testlevel = '0' if nightly else '1'
    id_string = f"{num_in}_{num_out}_{num_chan}"
    id_string += "_smoke" if testlevel == '1' else ""

    cwd = Path(request.fspath).parent
    binary = f'{cwd}/test_i2s_callback_sequence/bin/tdm_{id_string}/test_i2s_callback_sequence_tdm_{id_string}.xe'

    tester = Pyxsim.testers.AssertiveComparisonTester(
        f'{cwd}/expected/tdm_sequence_check_{num_out}{num_in}{num_chan}.expect',
        regexp = True,
        ordered = True,
        suppress_multidrive_messages=True,
        ignore=["CONFIG:.*"]
    )

    Pyxsim.run_on_simulator(
        binary,
        tester=tester,
        build_env = {"NUMS_IN_OUT":f'{num_in};{num_out}', "TDM_CHANS_PER_FRAME":f"{num_chan}", "SMOKE":testlevel, "TDM":"1"},
        simargs=[],
        capfd=capfd
    )
