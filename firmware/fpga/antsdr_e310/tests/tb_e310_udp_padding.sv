// SPDX-License-Identifier: LGPL-3.0-or-later
`timescale 1ns/1ps
module tb_e310_udp_padding;
parameter PAD = 1;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [63:0] din=0;
reg valid=0,last=0;
wire ready;
wire [63:0] dout;
wire [3:0] user;
wire outvalid,outlast;
reg outready=0;
integer cycle=0,count=0,packets=0;
reg [7:0] bytes[0:2047];
uoe_packet_gen #(.PAD_CHDR_TO_32BIT(PAD)) dut(
 .clk(clk),.rst(rst),.my_eth_addr(48'h001122334455),.my_ipv4_addr(32'hc0a80a03),
 .x2e_tdata(din),.x2e_tuser({16'd49154,16'd40000,32'hc0a80a01,48'h020304050607}),
 .x2e_tvalid(valid),.x2e_tlast(last),.x2e_tready(ready),
 .x2e_framed_tdata(dout),.x2e_framed_tuser(user),.x2e_framed_tvalid(outvalid),
 .x2e_framed_tlast(outlast),.x2e_framed_tready(outready));
always @(negedge clk) begin
 cycle=cycle+1; outready=(cycle%4!=0 && cycle%7!=0);
end
integer b,nvalid;
always @(posedge clk) if(outvalid && outready) begin
 nvalid=(outlast && user[2:0]!=0)?user[2:0]:8;
 for(b=0;b<nvalid;b=b+1)begin bytes[count]=dout[8*b+:8];count=count+1;end
 if(outlast)packets=packets+1;
end
task send(input [63:0] data,input final_word);
 begin
  @(negedge clk);din=data;last=final_word;valid=1;
  @(posedge clk);while(!ready)@(posedge clk);
  @(negedge clk);valid=0;last=0;
 end
endtask
function [15:0] sample(input integer i);
 sample={8'(i+1),8'(127-i)};
endfunction
task check_packet(input integer nsamp);
 integer chdrlen,padded,i,j,base,sum,expected_packets;
 reg [63:0] payload;
 begin
 count=0;expected_packets=packets+1;
 chdrlen=16+2*nsamp;padded=(chdrlen+3)&~3;
 send({16'h3000,16'(chdrlen),32'h000000a0},0);
 send(64'h0123456789abcdef,0);
 for(i=0;i<nsamp;i=i+4)begin
  payload=0;
  for(j=0;j<4;j=j+1)if(i+j<nsamp)payload[63-j*16-:16]=sample(i+j);
  send(payload,i+4>=nsamp);
 end
 wait(packets==expected_packets);#1;
 if(count!=48+padded)$fatal(1,"UDP padding missing: samples=%0d bytes=%0d expected=%0d",nsamp,count,48+padded);
 if({bytes[22],bytes[23]}!=padded+28)$fatal(1,"Wrong IP length");
 if({bytes[44],bytes[45]}!=padded+8)$fatal(1,"Wrong UDP length");
 if({bytes[49],bytes[48]}!=chdrlen)$fatal(1,"CHDR sample length changed");
 sum=0;for(i=20;i<40;i=i+2)sum=sum+{bytes[i],bytes[i+1]};
 sum=(sum&65535)+(sum>>16);
 if(sum!=65535)$fatal(1,"Invalid IP checksum");
 for(i=0;i<nsamp;i=i+1)begin
  base=64+4*(i/2)+((i%2==0)?2:0);
  if({bytes[base+1],bytes[base]}!==sample(i))$fatal(1,"Sample lost/reordered: %0d/%0d",i,nsamp);
 end
 $display("PASS sc8 samples=%0d CHDR=%0d UDP payload=%0d",nsamp,chdrlen,padded);
 end
endtask
initial begin
 repeat(5)@(negedge clk);rst=0;
 check_packet(1);check_packet(2);check_packet(3);check_packet(4);
 check_packet(5);check_packet(7);check_packet(11);check_packet(183);
 check_packet(287);check_packet(509);check_packet(716);
 $display("E310 UDP padding/checksum/sample/backpressure regression PASS");$finish;
end
initial begin #200000; $fatal(1,"Timeout");end
endmodule
