// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <cstdint>
#include "../common/ad9361_driver/ad9361_client.h"
namespace uhd { namespace usrp {
class antsdr_ad9361_client_t : public ad9361_params
{
public:
    explicit antsdr_ad9361_client_t(bool e310 = false) : _e310(e310) {}
    ~antsdr_ad9361_client_t() override {}
    double get_band_edge(frequency_band_t band) override
    {
        if (_e310) {
            // app_e310 uses port B at <=3 GHz, port A above it; no port C.
            return band == AD9361_RX_BAND0 ? 0.0 : 3000000001.0;
        }
        switch (band) {
            case AD9361_RX_BAND0:
                return 0; // Set these all to
            case AD9361_RX_BAND1:
                return 0; // zero, so RF port A
            case AD9361_TX_BAND0:
                return 0; // is used all the time
            default:
                return 0; // On both Rx and Tx
        }
    }
    clocking_mode_t get_clocking_mode() override
    {
        return clocking_mode_t::AD9361_XTAL_N_CLK_PATH;
    }
    digital_interface_mode_t get_digital_interface_mode() override
    {
        return _e310 ? AD9361_DDR_FDD_LVDS : AD9361_DDR_FDD_LVCMOS;
    }
    bool get_tx_iq_swap() override { return !_e310; }
    digital_interface_delays_t get_digital_interface_timing() override
    {
        digital_interface_delays_t delays;
        delays.rx_clk_delay  = 0;
        delays.rx_data_delay = _e310 ? 4 : 0xF;
        delays.tx_clk_delay  = _e310 ? 7 : 0;
        delays.tx_data_delay = _e310 ? 0 : 0xF;
        return delays;
    }
private:
    const bool _e310;
};

}}
