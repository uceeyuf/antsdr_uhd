// SPDX-License-Identifier: GPL-3.0-or-later
// Standalone regression: old E310 must not select the V2 CMOS/port-A profile.
#include "../lib/usrp/ant/ant_ad9361_params.hpp"
#define CHECK(condition) do { if (!(condition)) return __LINE__; } while (false)
using namespace uhd::usrp;
int main() {
    antsdr_ad9361_client_t old(true), legacy;
    CHECK(old.get_digital_interface_mode()==AD9361_DDR_FDD_LVDS);
    CHECK(legacy.get_digital_interface_mode()==AD9361_DDR_FDD_LVCMOS);
    CHECK(!old.get_tx_iq_swap() && legacy.get_tx_iq_swap());
    CHECK(old.get_band_edge(AD9361_RX_BAND0)==0);
    CHECK(3e9 < old.get_band_edge(AD9361_RX_BAND1));
    CHECK(3.1e9 >= old.get_band_edge(AD9361_RX_BAND1));
    CHECK(3e9 < old.get_band_edge(AD9361_TX_BAND0));
    CHECK(legacy.get_band_edge(AD9361_RX_BAND1)==0);
    const auto t=old.get_digital_interface_timing();
    CHECK(t.rx_clk_delay==0 && t.rx_data_delay==4 && t.tx_clk_delay==7 && t.tx_data_delay==0);
    const auto v=legacy.get_digital_interface_timing();
    CHECK(v.rx_data_delay==15 && v.tx_clk_delay==0 && v.tx_data_delay==15);
}
