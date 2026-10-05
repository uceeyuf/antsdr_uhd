`timescale 1ns/1ps
// Post-IDDR regression only: checks the board-specific half-word alignment.
module tb;
reg clk=0, rst=1; always #5 clk=~clk;
reg [5:0] p=0,n=0; reg [1:0] frame=0;
reg [11:0] iw=12'h123,qw=12'h456; integer cycle=0,good=0;
e310_lvds_rx dut(.ref_clk(clk),.rst(rst),.rx_clk_in_p(clk),.rx_clk_in_n(~clk),
 .rx_frame_in_p(1'b0),.rx_frame_in_n(1'b1),.rx_data_in_p(6'b0),.rx_data_in_n(6'b111111),
 .mimo(1'b0),.delay_value(5'd8),.delay_load_en(1'b1),.data_clk_ce(1'b1));
initial begin
 force dut.rx_data_i=p; force dut.rx_data_q=n; force dut.rx_frame=frame;
 repeat(5) @(negedge clk); rst=0;
 repeat(100) @(negedge clk);
 if(good<30) $fatal(1,"No valid aligned samples: %0d",good);
 $display("PASS: %0d aligned samples; I=123 Q=456, no I/Q swap",good); $finish;
end
always @(negedge clk) begin
 cycle=cycle+1;
 if(cycle%2==0) begin p=iw[11:6];n=qw[5:0];frame=2'b10;end
 else begin p=iw[5:0];n=qw[11:6];frame=2'b01;end
end
always @(posedge clk) if(!rst && cycle>15 && dut.adc_valid_r) begin
 if(dut.adc_data_i0_r!==iw || dut.adc_data_q0_r!==qw)
  $fatal(1,"I/Q mismatch: I=%03x Q=%03x",dut.adc_data_i0_r,dut.adc_data_q0_r);
 good=good+1;
end
endmodule
module IBUFDS(input I,IB,output O); assign O=I; endmodule
module BUFGCE(input I,CE,output O);assign O=I&CE;endmodule
module BUFR #(parameter BUFR_DIVIDE="2",SIM_DEVICE="7SERIES")(input I,CE,CLR,output O);assign O=I;endmodule
module BUFGCTRL(input I0,I1,S0,S1,CE0,CE1,IGNORE0,IGNORE1,output O);assign O=S0?I0:I1;endmodule
module IDELAYCTRL(input REFCLK,RST,output RDY);assign RDY=~RST;endmodule
module IDELAYE2 #(parameter CINVCTRL_SEL="FALSE",DELAY_SRC="IDATAIN",HIGH_PERFORMANCE_MODE="FALSE",IDELAY_TYPE="VAR_LOAD",IDELAY_VALUE=0,PIPE_SEL="FALSE",REFCLK_FREQUENCY=200.0,SIGNAL_PATTERN="DATA")
(input C,CE,CINVCTRL,DATAIN,IDATAIN,INC,LD,LDPIPEEN,REGRST,input [4:0] CNTVALUEIN,output [4:0] CNTVALUEOUT,output DATAOUT);
assign DATAOUT=IDATAIN;assign CNTVALUEOUT=CNTVALUEIN;endmodule
module IDDR #(parameter DDR_CLK_EDGE="SAME_EDGE_PIPELINED",INIT_Q1=0,INIT_Q2=0,SRTYPE="SYNC")(input C,CE,D,R,S,output Q1,Q2);assign Q1=D;assign Q2=D;endmodule
module reset_sync(input clk,reset_in,output reg reset_out=1);always @(posedge clk)reset_out<=reset_in;endmodule
module e310_async_fifo #(parameter DSIZE=48,ASIZE=10,FALLTHROUGH="TRUE")
(input wclk,wrst_n,winc,input[DSIZE-1:0]wdata,output wfull,awfull,input rclk,rrst_n,rinc,output[DSIZE-1:0]rdata,output rempty,arempty);
assign wfull=0;assign awfull=0;assign rempty=0;assign arempty=0;assign rdata=wdata;endmodule
