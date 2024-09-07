# Copyright 2016-2024 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import pytest
import Pyxsim
from Pyxsim.pyxsim import XsiLoopbackPlugin
from pathlib import Path
import json

with open(Path(__file__).parent / "backpressure_test/test_params.json") as f:
    params = json.load(f)

rx_tx_inc_args = {}
for item in params["RX_TX_INCS"]:
    rx = item["RX"]
    tx = item["TX"]
    rx_tx_inc_args[f"rx_delay_inc_{rx*10}ns,tx_delay_inc_{tx*10}ns"] = [rx, tx]

# 384000, num_channels 4, bitdepths 8 and 16 have zero backpressure so skip the test
def uncollect_if(bitdepth, sample_rate, num_channels, receive_increment, send_increment):
    if sample_rate == 384000 and num_channels == 4 and bitdepth != 32:
        return True

@pytest.mark.uncollect_if(func=uncollect_if)
@pytest.mark.parametrize("bitdepth", params["BITDEPTHS"], ids=[f"{bd}b" for bd in params["BITDEPTHS"]])
@pytest.mark.parametrize("sample_rate", params["SAMPLE_RATES"], ids=[f"{sr}Hz" for sr in params["SAMPLE_RATES"]])
@pytest.mark.parametrize("num_channels", params["I2S_LINES"])
@pytest.mark.parametrize(("receive_increment", "send_increment"), rx_tx_inc_args.values(), ids=rx_tx_inc_args.keys())
def test_backpressure(nightly, capfd, request, sample_rate, num_channels, receive_increment, send_increment, bitdepth):
    id_string = f"{bitdepth}_{sample_rate}_{num_channels}_{receive_increment}_{send_increment}"

    cwd = Path(request.fspath).parent

    binary = f'{cwd}/backpressure_test/bin/test_i2s_backpressure_{bitdepth}_{sample_rate}_{num_channels}_{receive_increment}_{send_increment}.xe'

    loopback = XsiLoopbackPlugin(tile="tile[0]", from_port="XS1_PORT_1G", to_port="XS1_PORT_1A")

    tester = Pyxsim.testers.AssertiveComparisonTester(f'{cwd}/expected/backpressure_test.expect',
                                                    regexp = True,
                                                    ordered = True,
                                                    suppress_multidrive_messages=True,
                                                    ignore=["CONFIG:.*"])

    Pyxsim.run_on_simulator_(
        binary,
        tester=tester,
        do_xe_prebuild=False,
        simargs=[],
        capfd=capfd,
        plugins=[loopback]
    )
