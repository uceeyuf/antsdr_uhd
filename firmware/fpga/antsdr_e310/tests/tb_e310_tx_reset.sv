`timescale 1ns/1ps
// Reset-duration regression with AD9361 clocks starting after FPGA configuration.
// The FIFO/IO shells do not model hardware recovery or electrical timing.
module tb_tx_reset;
reg fast_clk=0, slow_clk=0;
integer slow_reset_cycles=0;
initial begin #100; forever #5 fast_clk=~fast_clk; end
initial begin #105; forever #10 slow_clk=~slow_clk; end
e310_lvds_tx dut(.ref_clk(fast_clk), .radio_clk(slow_clk), .radio_rst(1'b0),
 .mimo(1'b0),.tx_chnl_sel(1'b0),.tx_data_i0(12'h123),.tx_data_q0(12'h456),
 .tx_data_i1(12'b0),.tx_data_q1(12'b0),.fb_clk(fast_clk));
always @(posedge slow_clk) if(dut.rst===1'b1) slow_reset_cycles=slow_reset_cycles+1;
initial begin
 wait(dut.rst===1'b1); wait(dut.rst===1'b0); #1;
 if(slow_reset_cycles<10) $fatal(1,"TX reset too short: %0d slow clock cycles",slow_reset_cycles);
 $display("PASS: TX reset held for %0d slow clock cycles after clock startup",slow_reset_cycles);
 $finish;
end
initial begin #5000; $fatal(1,"TX reset did not release"); end
endmodule
module e310_async_fifo #(parameter DSIZE=48,ASIZE=10,FALLTHROUGH="TRUE")
(input wclk,wrst_n,winc,input[DSIZE-1:0]wdata,output wfull,awfull,input rclk,rrst_n,rinc,output[DSIZE-1:0]rdata,output rempty,arempty);
assign wfull=0;assign awfull=0;assign rempty=0;assign arempty=0;assign rdata=wdata;
endmodule
module ODDR #(parameter DDR_CLK_EDGE="SAME_EDGE",INIT=0,SRTYPE="SYNC")
(input C,CE,D1,D2,R,S,output Q);assign Q=C?D1:D2;endmodule
module OBUFDS(input I,output O,OB);assign O=I;assign OB=~I;endmodule
