# Copyright 2015-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
from pathlib import Path
import Pyxsim
import pytest
import json

with open(Path(__file__).parent / "test_tdm_callback_sequence/test_params.json") as f:
    params = json.load(f)

num_in_out_args = {}
for item in params["NUMS_IN_OUT"]:
    num_in = item["INPUT"]
    num_out = item["OUTPUT"]
    num_chan = item["TDM_CHANS_PER_FRAME"]
    num_in_out_args[f"{num_in}ch_in,{num_out}ch_out,{num_chan}chans"] = [num_in, num_out, num_chan]

num_in_out_args = {"1ch_in,1ch_out,8ch": (1, 1, 8),
                   "1ch_in,0ch_out,8ch": (1, 0, 8),
                   "0ch_in,1ch_out,8ch": (0, 1, 8),
                   "2ch_in,2ch_out,4ch": (2, 2, 4)}

@pytest.mark.parametrize(("num_in", "num_out", "num_chan"), num_in_out_args.values(), ids=num_in_out_args.keys())
def test_tdm_index_sequence(capfd, request, nightly, num_in, num_out, num_chan):
    testlevel = '0' if nightly else '1'
    
    if (num_chan == 4) and not nightly:
        pytest.skip("Only test non-8chan modes if nightly")

    cfg = f"{num_in}_{num_out}_{num_chan}_{testlevel}"
    cwd = Path(request.fspath).parent
    binary = f'{cwd}/test_tdm_callback_sequence/bin/{cfg}/test_tdm_callback_sequence_{cfg}.xe'
    assert Path(binary).exists(), f"Cannot find {binary}"

    tester = Pyxsim.testers.AssertiveComparisonTester(
        f'{cwd}/expected/tdm_sequence_check_{num_out}{num_in}{num_chan}.expect',
        regexp = True,
        ordered = True,
        suppress_multidrive_messages=True,
        ignore=["CONFIG:.*"]
    )

    Pyxsim.run_on_simulator_(
        binary,
        tester=tester,
        do_xe_prebuild=False,
        simargs=[],
        capfd=capfd
    )
