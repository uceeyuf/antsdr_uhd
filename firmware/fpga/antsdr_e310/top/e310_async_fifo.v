// SPDX-License-Identifier: LGPL-3.0-or-later
// Adapt the existing UHD FWFT clock-domain crossing to the LVDS core.
module e310_async_fifo #(parameter DSIZE=48, ASIZE=10, FALLTHROUGH="TRUE") (
    input wire wclk, wrst_n, winc,
    input wire [DSIZE-1:0] wdata,
    output wire wfull, awfull,
    input wire rclk, rrst_n, rinc,
    output wire [DSIZE-1:0] rdata,
    output wire rempty, arempty
);
    wire ready, valid;
    assign wfull = ~ready;
    assign awfull = ~ready;
    assign rempty = ~valid;
    assign arempty = ~valid;
    axi_fifo_2clk #(.WIDTH(DSIZE), .SIZE(ASIZE)) fifo (
        .reset(~wrst_n | ~rrst_n),
        .i_aclk(wclk), .i_tdata(wdata), .i_tvalid(winc), .i_tready(ready),
        .o_aclk(rclk), .o_tdata(rdata), .o_tvalid(valid), .o_tready(rinc)
    );
endmodule
