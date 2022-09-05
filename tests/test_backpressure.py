# Copyright 2016-2022 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import pytest
import Pyxsim
from Pyxsim.pyxsim import XsiLoopbackPlugin
from pathlib import Path

sample_rate_args = {"768kbps": 768000,
                    "384kbps": 384000,
                    "192kbps": 192000}

num_channels_args = {"1ch": 1,
                     "2ch": 2,
                     "3ch": 3,
                     "4ch": 4}

rx_tx_inc_args = {"rx_delay_inc_50ns,tx_delay_inc_50ns": (5, 5),
                  "rx_delay_inc_0ns,tx_delay_inc_100ns": (0, 10),
                  "rx_delay_inc_100ns,tx_delay_inc_0ns": (10, 0)}

bitdepth_args = {"8b": 8,
                 "16b": 16,
                 "32b": 32}

@pytest.mark.parametrize("bitdepth", bitdepth_args.values(), ids=bitdepth_args.keys())
@pytest.mark.parametrize("sample_rate", sample_rate_args.values(), ids=sample_rate_args.keys())
@pytest.mark.parametrize("num_channels", num_channels_args.values(), ids=num_channels_args.keys())
@pytest.mark.parametrize(("receive_increment", "send_increment"), rx_tx_inc_args.values(), ids=rx_tx_inc_args.keys())
def test_backpressure(nightly, capfd, request, sample_rate, num_channels, receive_increment, send_increment, bitdepth):
    if (num_channels != 4) and not nightly:
        pytest.skip("Only run 4 channel tests unless it is a nightly")

    id_string = f"{bitdepth}_{sample_rate}_{num_channels}_{receive_increment}_{send_increment}"

    cwd = Path(request.fspath).parent

    binary = f'{cwd}/backpressure_test/bin/{id_string}/backpressure_test_{id_string}.xe'

    loopback = XsiLoopbackPlugin(tile="tile[0]", from_port="XS1_PORT_1G", to_port="XS1_PORT_1A")

    tester = Pyxsim.testers.AssertiveComparisonTester(f'{cwd}/expected/backpressure_test.expect',
                                                    regexp = True,
                                                    ordered = True,
                                                    suppress_multidrive_messages=True,
                                                    ignore=["CONFIG:.*"])

    Pyxsim.run_on_simulator(
        binary,
        tester=tester,
        build_env = {"BITDEPTHS":bitdepth, "SAMPLE_RATES":sample_rate, "CHANS":num_channels, "RX_TX_INCS":f"{receive_increment};{send_increment}"},
        simargs=[],
        capfd=capfd,
        plugins=[loopback]
    )
