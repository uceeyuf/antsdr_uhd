// SPDX-License-Identifier: LGPL-3.0-or-later
`timescale 1ns/1ps
module tb_e310_transport;
reg clk=0, regclk=0, rst=1;
always #5 clk=~clk;
always #12.5 regclk=~regclk;
reg [63:0] txdata=0;
reg [7:0] txkeep=0;
reg txlast=0, txvalid=0;
wire txready;
wire [63:0] rxdata;
wire [7:0] rxkeep;
wire rxlast,rxvalid;
reg rxready=0;
integer cycles=0, count=0;
reg done=0;
reg [7:0] request[0:59];
reg [7:0] response[0:127];
eth_internal dut (
 .bus_rst(rst), .bus_clk(clk), .s_axi_aclk(regclk), .s_axi_aresetn(~rst),
 .s_axi_awaddr(14'b0), .s_axi_awvalid(1'b0), .s_axi_awready(),
 .s_axi_wdata(32'b0), .s_axi_wstrb(4'b0), .s_axi_wvalid(1'b0), .s_axi_wready(),
 .s_axi_bresp(), .s_axi_bvalid(), .s_axi_bready(1'b1),
 .s_axi_araddr(14'b0), .s_axi_arvalid(1'b0), .s_axi_arready(),
 .s_axi_rdata(), .s_axi_rresp(), .s_axi_rvalid(), .s_axi_rready(1'b1),
 .h2e_tdata(txdata), .h2e_tkeep(txkeep), .h2e_tlast(txlast), .h2e_tvalid(txvalid), .h2e_tready(txready),
 .e2h_tdata(rxdata), .e2h_tkeep(rxkeep), .e2h_tlast(rxlast), .e2h_tvalid(rxvalid), .e2h_tready(rxready),
 .e2v_tdata(), .e2v_tuser(), .e2v_tlast(), .e2v_tvalid(), .e2v_tready(1'b1),
 .v2e_tdata(64'b0), .v2e_tuser(16'b0), .v2e_tlast(1'b0), .v2e_tvalid(1'b0), .v2e_tready(),
 .port_info(), .device_id(16'b0), .link_up(), .activity()
);
always @(negedge clk) begin
 cycles=cycles+1;
 rxready=(cycles%3)!=0; // Exercise response backpressure.
end
integer b;
always @(posedge clk) if(rxvalid && rxready) begin
 for(b=0;b<8;b=b+1) if(rxkeep[b]) begin
  if(count>=128)$fatal(1,"Oversized ARP reply");
  response[count]=rxdata[8*b+:8]; count=count+1;
 end
 if(rxlast)done=1;
end
integer i,j;
initial begin
 for(i=0;i<60;i=i+1)request[i]=0;
 for(i=0;i<6;i=i+1)request[i]=8'hff;
 {request[6],request[7],request[8],request[9],request[10],request[11]}=48'h021122334455;
 {request[12],request[13]}=16'h0806;
 {request[14],request[15]}=16'h0001;
 {request[16],request[17]}=16'h0800;
 request[18]=6;request[19]=4;request[21]=1;
 for(i=0;i<6;i=i+1)request[22+i]=request[6+i];
 {request[28],request[29],request[30],request[31]}=32'hc0a80114;
 {request[38],request[39],request[40],request[41]}=32'hc0a8010a;
 #500; @(negedge clk)rst=0;
 repeat(40)@(posedge clk);
 for(i=0;i<8;i=i+1)begin
  @(negedge clk);txdata=0;txkeep=0;
  for(j=0;j<8;j=j+1)if(i*8+j<60)begin txdata[8*j+:8]=request[i*8+j];txkeep[j]=1;end
  txlast=(i==7);txvalid=1;
  @(posedge clk);while(!txready)@(posedge clk);
 end
 @(negedge clk);txvalid=0;txlast=0;
 wait(done); #10;
 if(count<42)$fatal(1,"Short ARP reply: %d",count);
 for(i=0;i<6;i=i+1)if(response[i]!==request[6+i])$fatal(1,"Wrong destination MAC");
 if({response[6],response[7],response[8],response[9],response[10],response[11]}!==48'h00802f16c52f)$fatal(1,"Wrong sender MAC");
 if({response[12],response[13],response[20],response[21]}!==32'h08060002)$fatal(1,"Wrong ARP opcode/type");
 for(i=0;i<4;i=i+1)begin
  if(response[28+i]!==request[38+i])$fatal(1,"Wrong sender IP");
  if(response[38+i]!==request[28+i])$fatal(1,"Wrong target IP");
 end
 $display("E310 DMA ARP/backpressure test PASS (%0d bytes)",count);$finish;
end
initial begin #200000; $fatal(1,"ARP reply timeout");end
endmodule
