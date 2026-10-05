# Implementation-only: PS7 generated clocks do not exist in top OOC synthesis.
# AXI-Lite crosses through axil_regport_master clock-domain FIFOs. DMA uses
# Xilinx's asynchronous AXI-Lite interface; its data path stays on bus_clk.
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks clk_fpga_0] \
    -group [get_clocks -include_generated_clocks tcxo40] \
    -group [get_clocks -include_generated_clocks rx_clk]
