# Board electrical profile from standalone HDL a329fa58, selected by the user.
# Preserve its LVDS_25 / LVCMOS25 pin profile for this bring-up target.
set_property  -dict {PACKAGE_PIN  T11  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_OUT[0]]
set_property  -dict {PACKAGE_PIN  T14  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_OUT[1]]
set_property  -dict {PACKAGE_PIN  T15  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_OUT[2]]
set_property  -dict {PACKAGE_PIN  T17  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_OUT[3]]
set_property  -dict {PACKAGE_PIN  T19  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_OUT[4]]
set_property  -dict {PACKAGE_PIN  T20  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_OUT[5]]
set_property  -dict {PACKAGE_PIN  U13  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_OUT[6]]
set_property  -dict {PACKAGE_PIN  V13  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_OUT[7]]
set_property  -dict {PACKAGE_PIN  T10  IOSTANDARD LVCMOS25} [get_ports CAT_CTL_IN[0]]
set_property  -dict {PACKAGE_PIN  Y12  IOSTANDARD LVCMOS33} [get_ports CAT_CTL_IN[1]]
set_property  -dict {PACKAGE_PIN  Y13  IOSTANDARD LVCMOS33} [get_ports CAT_CTL_IN[2]]
set_property  -dict {PACKAGE_PIN  V11  IOSTANDARD LVCMOS33} [get_ports CAT_CTL_IN[3]]
set_property  -dict {PACKAGE_PIN  P16  IOSTANDARD LVCMOS25} [get_ports CAT_EN_AGC]
set_property  -dict {PACKAGE_PIN  U20  IOSTANDARD LVCMOS25} [get_ports CAT_SYNC]
set_property  -dict {PACKAGE_PIN  N17  IOSTANDARD LVCMOS25} [get_ports CAT_RESETn]
set_property  -dict {PACKAGE_PIN  R18  IOSTANDARD LVCMOS25} [get_ports CAT_EN]
set_property  -dict {PACKAGE_PIN  P14  IOSTANDARD LVCMOS25} [get_ports CAT_TXnRX]

set_property  -dict {PACKAGE_PIN  P18  IOSTANDARD LVCMOS25  PULLTYPE PULLUP} [get_ports CAT_SPI_EN]
set_property  -dict {PACKAGE_PIN  R14  IOSTANDARD LVCMOS25} [get_ports CAT_SPI_CLK]
set_property  -dict {PACKAGE_PIN  P15  IOSTANDARD LVCMOS25} [get_ports CAT_SPI_DI]
set_property  -dict {PACKAGE_PIN  R19  IOSTANDARD LVCMOS25} [get_ports CAT_SPI_DO]



set_property  -dict {PACKAGE_PIN  G14  IOSTANDARD LVCMOS33} [get_ports rx1_band_sel_h]
set_property  -dict {PACKAGE_PIN  C20  IOSTANDARD LVCMOS33} [get_ports rx1_band_sel_l]
set_property  -dict {PACKAGE_PIN  B19  IOSTANDARD LVCMOS33} [get_ports tx1_band_sel_h]
set_property  -dict {PACKAGE_PIN  B20  IOSTANDARD LVCMOS33} [get_ports tx1_band_sel_l]
set_property  -dict {PACKAGE_PIN  E17  IOSTANDARD LVCMOS33} [get_ports rx2_band_sel_h]
set_property  -dict {PACKAGE_PIN  A20  IOSTANDARD LVCMOS33} [get_ports rx2_band_sel_l]
set_property  -dict {PACKAGE_PIN  D18  IOSTANDARD LVCMOS33} [get_ports tx2_band_sel_h]
set_property  -dict {PACKAGE_PIN  D19  IOSTANDARD LVCMOS33} [get_ports tx2_band_sel_l]

set_property  -dict {PACKAGE_PIN P19  IOSTANDARD LVDS_25 } [get_ports  CAT_FBCLK_N     ]
set_property  -dict {PACKAGE_PIN N18  IOSTANDARD LVDS_25 } [get_ports  CAT_FBCLK_P     ]
set_property  -dict {PACKAGE_PIN Y14  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_N[0] ]
set_property  -dict {PACKAGE_PIN W14  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_D[0] ]
set_property  -dict {PACKAGE_PIN U12  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_N[1] ]
set_property  -dict {PACKAGE_PIN T12  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_D[1] ]
set_property  -dict {PACKAGE_PIN U15  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_N[2] ]
set_property  -dict {PACKAGE_PIN U14  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_D[2] ]
set_property  -dict {PACKAGE_PIN U17  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_N[3] ]
set_property  -dict {PACKAGE_PIN T16  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_D[3] ]
set_property  -dict {PACKAGE_PIN W13  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_N[4] ]
set_property  -dict {PACKAGE_PIN V12  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_D[4] ]
set_property  -dict {PACKAGE_PIN W15  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_N[5] ]
set_property  -dict {PACKAGE_PIN V15  IOSTANDARD LVDS_25 } [get_ports  CAT_P1_D[5] ]
set_property  -dict {PACKAGE_PIN Y17  IOSTANDARD LVDS_25 } [get_ports  CAT_TX_FR_N   ]
set_property  -dict {PACKAGE_PIN Y16  IOSTANDARD LVDS_25 } [get_ports  CAT_TX_FR_P   ]
set_property  -dict {PACKAGE_PIN P20  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_DCLK_N      ]
set_property  -dict {PACKAGE_PIN N20  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_DCLK_P      ]
set_property  -dict {PACKAGE_PIN Y19  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_N[0]  ]
set_property  -dict {PACKAGE_PIN Y18  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_D[0]  ]
set_property  -dict {PACKAGE_PIN V18  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_N[1]  ]
set_property  -dict {PACKAGE_PIN V17  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_D[1]  ]
set_property  -dict {PACKAGE_PIN W20  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_N[2]  ]
set_property  -dict {PACKAGE_PIN V20  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_D[2]  ]
set_property  -dict {PACKAGE_PIN R17  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_N[3]  ]
set_property  -dict {PACKAGE_PIN R16  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_D[3]  ]
set_property  -dict {PACKAGE_PIN W19  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_N[4]  ]
set_property  -dict {PACKAGE_PIN W18  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_D[4]  ]
set_property  -dict {PACKAGE_PIN W16  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_N[5]  ]
set_property  -dict {PACKAGE_PIN V16  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_P0_D[5]  ]
set_property  -dict {PACKAGE_PIN U19  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_RX_FR_N    ]
set_property  -dict {PACKAGE_PIN U18  IOSTANDARD LVDS_25 DIFF_TERM TRUE } [get_ports  CAT_RX_FR_P    ]

# clocks

create_clock -name rx_clk       -period  8.138 [get_ports CAT_DCLK_P]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports CLK_40MHz_FPGA]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS33} [get_ports PPS_IN_EXT]
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports CLKIN_10MHz]
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS33} [get_ports CLK_40M_DAC_nSYNC]
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS33} [get_ports CLK_40M_DAC_SCLK]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports CLK_40M_DAC_DIN]
create_clock -name tcxo40 -period 25.0 [get_ports CLK_40MHz_FPGA]

# First bring-up target is fixed 1R1T: DATA_CLK <= 122.88 MHz,
# radio_clk = DATA_CLK/2 <= 61.44 MHz. Do not reuse this for 2R2T.
# PS AXI register, free-running FPGA bus and AD9361 clocks are independent.
# Data crossings use the existing UHD asynchronous FIFOs. Static mode/GPIO
# controls still require a hardware CDC/reset review before release.
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks rx_clk] \
    -group [get_clocks -include_generated_clocks tcxo40]
# PS clock-domain exceptions remain pending a CDC review. Do not add Tcl
# conditionals here: Vivado 2020.2 does not support "if" in an XDC file.
