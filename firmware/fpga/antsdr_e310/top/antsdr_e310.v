// --------------------------------------------------------------------------------
// Copyright (c) 2019 ~ 2022 by MicroPhase Technologies Inc.
// --------------------------------------------------------------------------------
//
// Disclaimer:
//
//  This VHDL/Verilog or C/C++ source code is intended as a design reference
//  which illustrates how these types of functions can be implemented.
//  It is the user's responsibility to verify their design for
//  consistency and functionality through the use of formal
//  verification methods.  MicroPhase provides no warranty regarding the use
//  or functionality of this code.
//
/// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
//
//                     MicroPhase Technologies Inc
//                     Shanghai, China
//
//                     web: http://www.microphase.cn/
//                     email: support@microphase.cn
//
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
//
// Major Functions:
//  This is the old ANTSDR E310 Micro-USB bring-up top level, which is
//  compatible to usrp b210.
//
//
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
//
// License: LGPL-3.0-or-later
//
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
//
// Revision History:
// Date          By            Revision    Change Description
//---------------------------------------------------------------------
// 2022-11-21     Chaochen Wei  1.0         Original
//
//
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

`default_nettype none
module antsdr_e310 (
        // AD936x - SPI Interface:
        output wire 	 		CAT_SPI_EN      ,  // Enable
        input  wire	 			CAT_SPI_DO      ,  // MISO
        output wire 	 		CAT_SPI_DI      ,  // MOSI
        output wire 	 		CAT_SPI_CLK     ,  // SPI Clk

        // AD936x - Control:
        output wire  	     	CAT_EN          ,
        output wire  	     	CAT_EN_AGC      ,
        output wire  	     	CAT_RESETn      ,
        output wire  	     	CAT_TXnRX       ,
        output wire             CAT_SYNC        ,
        output wire [3:0] 		CAT_CTL_IN      , // These should be outputs
        input  wire [7:0]	 	CAT_CTL_OUT     , // MUST BE INPUT

        // AD936x - Data:
        input  wire	 			CAT_DCLK_P      , // Clock from AD936x (RX)
        output wire 	 		CAT_FBCLK_P     , // Clock to AD936x (TX)
        output wire    			CAT_FBCLK_N     ,
        input  wire [5:0]   	CAT_P0_D        , // RX data is on Port 0
        output wire [5:0]  		CAT_P1_D        , // TX data is on Port 1
        input  wire	 			CAT_RX_FR_P     ,
        output wire 	 		CAT_TX_FR_P     ,
        output wire    			CAT_TX_FR_N     ,

        input wire CAT_DCLK_N,
        input wire CAT_RX_FR_N,
        input wire [5:0] CAT_P0_N,
        output wire [5:0] CAT_P1_N,
        // AD936x - Always on 40MHz clock:
        input  wire	 			CLK_40MHz_FPGA  ,

        // PPS or 10 MHz

        input  wire             PPS_IN_EXT      ,
        input  wire             CLKIN_10MHz     ,

        // Old E310 has an LTC2630, no onboard GPS receiver.
        output wire CLK_40M_DAC_nSYNC,
        output wire CLK_40M_DAC_SCLK,
        output wire CLK_40M_DAC_DIN,
        output wire rx1_band_sel_h, rx1_band_sel_l,
        output wire rx2_band_sel_h, rx2_band_sel_l,
        output wire tx1_band_sel_h, tx1_band_sel_l,
        output wire tx2_band_sel_h, tx2_band_sel_l,
        // PS Connections
        inout   wire    [14:0]  PS_DDR3_addr    ,
        inout   wire    [2:0]   PS_DDR3_ba      ,
        inout   wire            PS_DDR3_cas_n   ,
        inout   wire            PS_DDR3_ck_n    ,
        inout   wire            PS_DDR3_ck_p    ,
        inout   wire            PS_DDR3_cke     ,
        inout   wire            PS_DDR3_cs_n    ,
        inout   wire    [3:0]   PS_DDR3_dm      ,
        inout   wire    [31:0]  PS_DDR3_dq      ,
        inout   wire    [3:0]   PS_DDR3_dqs_n   ,
        inout   wire    [3:0]   PS_DDR3_dqs_p   ,
        inout   wire            PS_DDR3_odt     ,
        inout   wire            PS_DDR3_ras_n   ,
        inout   wire            PS_DDR3_reset_n ,
        inout   wire            PS_DDR3_we_n    ,
        inout   wire            PS_MIO_ddr_vrn  ,
        inout   wire            PS_MIO_ddr_vrp  ,
        inout   wire    [53:0]  PS_MIO_mio      ,
        inout   wire            PS_MIO_ps_clk   ,
        inout   wire            PS_MIO_ps_porb  ,
        inout   wire            PS_MIO_ps_srstb

    );


    parameter PROTOCOL = "1GbE";
    parameter RGMII = 1;
    parameter MDIO_EN = 1'b1;
    parameter MDIO_PHYADDR = 5'd1;


    // Constants
    localparam REG_AWIDTH = 14; // log2(0x4000)
    localparam REG_DWIDTH = 32;
    localparam SFP_PORTNUM = 8'b0; // Only one SFP port

    // Clocks
    wire bus_clk;
    wire radio_clk;
    wire reg_clk;
    wire clk40;
    wire clk200;
    wire FCLK_CLK0;
    wire FCLK_CLK1;
    wire FCLK_CLK2;

    // Resets
    wire global_rst;
    wire bus_rst;
    wire reg_rstn;
    wire clk40_rst;
    wire clk40_rstn;
    wire FCLK_RESET0_N;
    wire FCLK_RESET1_N;

    // Regport for SFP
    wire        m_axi_net_arvalid;
    wire        m_axi_net_awvalid;
    wire        m_axi_net_bready;
    wire        m_axi_net_rready;
    wire        m_axi_net_wvalid;
    wire [11:0] m_axi_net_arid;
    wire [11:0] m_axi_net_awid;
    wire [11:0] m_axi_net_wid;
    wire [31:0] m_axi_net_araddr;
    wire [31:0] m_axi_net_awaddr;
    wire [31:0] m_axi_net_wdata;
    wire [3:0]  m_axi_net_wstrb;
    wire        m_axi_net_arready;
    wire        m_axi_net_awready;
    wire        m_axi_net_bvalid;
    wire        m_axi_net_rlast;
    wire        m_axi_net_rvalid;
    wire        m_axi_net_wready;
    wire [1:0]  m_axi_net_bresp;
    wire [1:0]  m_axi_net_rresp;
    wire [31:0] m_axi_net_rdata;


    // ETH DMA


    // Internal Ethernet xport adapter to PS
    wire [63:0] h2e_tdata;
    wire [7:0]  h2e_tkeep;
    wire        h2e_tlast;
    wire        h2e_tready;
    wire        h2e_tvalid;

    wire [63:0] e2h_tdata;
    wire [7:0]  e2h_tkeep;
    wire        e2h_tlast;
    wire        e2h_tready;
    wire        e2h_tvalid;

    wire [63:0] m_axis_dma_tdata;
    wire        m_axis_dma_tlast;
    wire        m_axis_dma_tready;
    wire        m_axis_dma_tvalid;

    wire [63:0] s_axis_dma_tdata;
    wire        s_axis_dma_tlast;
    wire        s_axis_dma_tready;
    wire        s_axis_dma_tvalid;


    // ARM ethernet dma clock crossing
    wire [63:0] arm_eth_tx_tdata;
    wire        arm_eth_tx_tvalid;
    wire        arm_eth_tx_tlast;
    wire        arm_eth_tx_tready;
    wire [3:0]  arm_eth_tx_tuser;
    wire [7:0]  arm_eth_tx_tkeep;

    wire [63:0] arm_eth_tx_tdata_b;
    wire        arm_eth_tx_tvalid_b;
    wire        arm_eth_tx_tlast_b;
    wire        arm_eth_tx_tready_b;
    wire [3:0]  arm_eth_tx_tuser_b;
    wire [7:0]  arm_eth_tx_tkeep_b;

    wire [63:0] arm_eth_rx_tdata;
    wire        arm_eth_rx_tvalid;
    wire        arm_eth_rx_tlast;
    wire        arm_eth_rx_tready;
    wire [3:0]  arm_eth_rx_tuser;
    wire [7:0]  arm_eth_rx_tkeep;

    wire [63:0] arm_eth_rx_tdata_b;
    wire        arm_eth_rx_tvalid_b;
    wire        arm_eth_rx_tlast_b;
    wire        arm_eth_rx_tready_b;
    wire [3:0]  arm_eth_rx_tuser_b;
    wire [7:0]  arm_eth_rx_tkeep_b;

    wire        arm_eth_rx_irq;
    wire        arm_eth_tx_irq;

    // Vita to Ethernet
    wire [63:0] v2e_tdata;
    wire [15:0] v2e_tuser;
    wire        v2e_tlast;
    wire        v2e_tvalid;
    wire        v2e_tready;

    // Ethernet to Vita
    wire [63:0] e2v_tdata;
    wire [15:0] e2v_tuser;
    wire        e2v_tlast;
    wire        e2v_tvalid;
    wire        e2v_tready;

    // Misc
    wire [31:0] port_info;
    wire        link_up;
    wire [15:0] device_id;

    ///////////////////////////////////////////////////////////////////////
    // generate clocks from always on codec main clk
    ///////////////////////////////////////////////////////////////////////
    wire locked;
    wire pll_fb_raw, pll_fb, pll_bus_raw, pll_200_raw;
    BUFG bus_clock_buffer (.I(pll_bus_raw), .O(bus_clk));
    BUFG delay_clock_buffer (.I(pll_200_raw), .O(clk200));
    BUFG pll_feedback (.I(pll_fb_raw), .O(pll_fb));


    wire    [63:0]  h2c_fifo_post_tdata     ;
    wire            h2c_fifo_post_tready    ;
    wire            h2c_fifo_post_tvalid    ;
    wire    [8:0]   h2c_fifo_post_rd_count  ;

    wire    [63:0]  h2c_fifo_pre_tdata      ;
    wire            h2c_fifo_pre_tready     ;
    wire            h2c_fifo_pre_tvalid     ;
    wire    [8:0]   h2c_fifo_pre_wr_count   ;


    wire [8:0]  c2h_fifo_post_rd_count  ;
    wire [63:0] c2h_fifo_post_tdata     ;
    wire        c2h_fifo_post_tready    ;
    wire        c2h_fifo_post_tvalid    ;
    wire [63:0] c2h_fifo_pre_tdata      ;
    wire        c2h_fifo_pre_tready     ;
    wire        c2h_fifo_pre_tvalid     ;
    wire [8:0]  c2h_fifo_pre_wr_count   ;

    // Synchronous reset for the bus_clk domain
    reset_sync bus_reset_gen (
        .clk(bus_clk),
        .reset_in(~locked),
        .reset_out(bus_rst)
    );

    assign global_rst = bus_rst;

    reset_sync clk40_reset_gen (
        .clk(clk40),
        .reset_in(~FCLK_RESET0_N),
        .reset_out(clk40_rst)
    );
    // Invert for various modules.
    assign clk40_rstn = ~clk40_rst;
    assign reg_rstn = clk40_rstn;

    /////////////////////////////////////////////////////////////////////
    //
    // Clocks and PPS
    //
    /////////////////////////////////////////////////////////////////////
    wire clk_int40;
    wire [1:0] pps_select;
    wire pps_fpga_int;

    assign clk40   = FCLK_CLK0;   // 40 MHz
    assign reg_clk = clk40;

    reg [15:0] clocks_ready_count;
    reg clocks_ready;
    always @(posedge bus_clk or posedge global_rst or negedge locked) begin
        if (global_rst | !locked) begin
            clocks_ready_count <= 16'b0;
            clocks_ready <= 1'b0;
        end
        else if (!clocks_ready) begin
            clocks_ready_count <= clocks_ready_count + 1'b1;
            clocks_ready <= (clocks_ready_count == 16'hffff);
        end
    end

    ///////////////////////////////////////////////////////////////////////
    // Create sync reset signals
    ///////////////////////////////////////////////////////////////////////

    wire   radio_rst;
    reset_sync radio_sync(.clk(radio_clk), .reset_in(!clocks_ready), .reset_out(radio_rst));

    wire ref_sel;
    wire ext_ref;
    wire ref_pll_clk;
    wire ext_ref_locked;
    wire lpps;

    wire [15:0] dac_stable;
    wire int_40mhz;
    wire is10meg;
    wire ispps;
    wire pps_ref;
    wire pps_radio;
    reg pps_registered = 1'b0;
    always @(posedge bus_clk) pps_registered <= global_rst ? 1'b0 : pps_fpga_int;
    synchronizer #(.INITIAL_VAL(1'b0)) pps_radio_sync (
        .clk(radio_clk), .rst(radio_rst), .in(pps_registered), .out(pps_radio)
    );

    // Internal TCXO is the only supported clock source in this bring-up target.
    assign ext_ref_locked = 1'b0;
    assign pps_ref = (pps_select == 2'b01) ? PPS_IN_EXT : pps_fpga_int;
    assign CLK_40M_DAC_nSYNC = 1'b1;
    assign CLK_40M_DAC_SCLK = 1'b0;
    assign CLK_40M_DAC_DIN = 1'b0;

    PLLE2_ADV #(.BANDWIDTH("OPTIMIZED"), .COMPENSATION("ZHOLD"),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT(30),
        .CLKOUT0_DIVIDE(6),
        .CLKOUT1_DIVIDE(30),
        .CLKOUT2_DIVIDE(12),
        .CLKOUT3_DIVIDE(6),
        .CLKIN1_PERIOD(25.0)
    )
    clkgen (
        .PWRDWN(1'b0), .RST(1'b0),
        .CLKFBOUT(pll_fb_raw), .CLKFBIN(pll_fb),
        .CLKIN1(CLK_40MHz_FPGA), .CLKINSEL(1'b1),
        .CLKIN2(1'b0), .DADDR(7'b0), .DCLK(1'b0),
        .DEN(1'b0), .DI(16'b0), .DWE(1'b0),
        .CLKOUT0(ref_pll_clk),
        .CLKOUT1(int_40mhz),
        .CLKOUT2(pll_bus_raw),
        .CLKOUT3(pll_200_raw),
        .LOCKED(locked)
    );


    ///////////////////////////////////////////////////////////////////////
    // AD936x I/O
    ///////////////////////////////////////////////////////////////////////
    wire [9:0] lvds_debug_rx;
    wire [47:0] lvds_debug_tx;
    wire [31:0] rx_data0, rx_data1;
    wire [31:0] tx_data0, tx_data1;
    wire mimo;

    e310_lvds io_radio (
        .debug_rx(lvds_debug_rx), .debug_tx(lvds_debug_tx), .ref_clk(clk200), .radio_rst(global_rst | misc_outs_r[9]), .mimo(1'b0),
        .rx_clk_in_p(CAT_DCLK_P), .rx_clk_in_n(CAT_DCLK_N),
        .rx_frame_in_p(CAT_RX_FR_P), .rx_frame_in_n(CAT_RX_FR_N),
        .rx_data_in_p(CAT_P0_D), .rx_data_in_n(CAT_P0_N),
        .tx_clk_out_p(CAT_FBCLK_P), .tx_clk_out_n(CAT_FBCLK_N),
        .tx_frame_out_p(CAT_TX_FR_P), .tx_frame_out_n(CAT_TX_FR_N),
        .tx_data_out_p(CAT_P1_D), .tx_data_out_n(CAT_P1_N),
        .adc_data_i0(rx_data0[31:20]), .adc_data_q0(rx_data0[15:4]),
        .adc_data_i1(rx_data1[31:20]), .adc_data_q1(rx_data1[15:4]),
        .dac_data_i0(tx_data0[31:20]), .dac_data_q0(tx_data0[15:4]),
        .dac_data_i1(tx_data1[31:20]), .dac_data_q1(tx_data1[15:4]),
        .radio_clk(radio_clk), .delay_value(5'd8), .delay_load_en(1'b1),
        .data_clk_ce(1'b1)
    );
    assign {rx_data0[19:16],rx_data0[3:0],rx_data1[19:16],rx_data1[3:0]} = 16'h0;

    ///////////////////////////////////////////////////////////////////////
    // SPI connections
    ///////////////////////////////////////////////////////////////////////
    wire mosi,  miso, sclk;
    wire [7:0]  sen;

    // AD936x Slave (it's the only slave for B205)
    assign CAT_SPI_EN   =  sen[0];
    assign CAT_SPI_DI   = ~sen[0] & mosi;
    assign CAT_SPI_CLK  = ~sen[0] & sclk;
    assign miso         = CAT_SPI_DO;


    ///////////////////////////////////////////////////////////////////////
    // bus signals
    ///////////////////////////////////////////////////////////////////////
    wire [63:0] ctrl_tdata, resp_tdata, rx_tdata, tx_tdata;
    wire ctrl_tlast, resp_tlast, rx_tlast, tx_tlast;
    wire ctrl_tvalid, resp_tvalid, rx_tvalid, tx_tvalid;
    wire ctrl_tready, resp_tready, rx_tready, tx_tready;

    ///////////////////////////////////////////////////////////////////////
    // frontend assignments
    ///////////////////////////////////////////////////////////////////////



    wire swap_atr_n;
    wire [7:0] radio0_gpio, radio1_gpio;
    reg [7:0] fe0_gpio, fe1_gpio;

    always @(posedge radio_clk) begin //Registers in the IOB
       fe0_gpio <= swap_atr_n ? radio1_gpio : radio0_gpio;
       fe1_gpio <= swap_atr_n ? radio0_gpio : radio1_gpio;
    end

    // Standalone app_e310 switches both channels at 3 GHz: B below, A above.
    assign rx1_band_sel_h = rx_bandsel_a;
    assign rx2_band_sel_h = rx_bandsel_a;
    assign rx1_band_sel_l = ~rx_bandsel_a;
    assign rx2_band_sel_l = ~rx_bandsel_a;
    assign tx1_band_sel_h = tx_bandsel_a;
    assign tx2_band_sel_h = tx_bandsel_a;
    assign tx1_band_sel_l = ~tx_bandsel_a;
    assign tx2_band_sel_l = ~tx_bandsel_a;
    wire [31:0] misc_outs; reg [31:0] misc_outs_r;

    always @(posedge bus_clk) misc_outs_r <= misc_outs; //register misc ios to ease routing to flop

    wire codec_arst;
    wire tx_bandsel_a, tx_bandsel_b, rx_bandsel_a, rx_bandsel_b, rx_bandsel_c;

    assign { swap_atr_n, tx_bandsel_a, tx_bandsel_b, rx_bandsel_a, rx_bandsel_b, rx_bandsel_c, codec_arst, mimo, ref_sel } = misc_outs_r[8:0];

    assign CAT_CTL_IN = 4'b1;
    assign CAT_EN_AGC = 1'b1;
    assign CAT_TXnRX = 1'b1;
    assign CAT_EN = 1'b1;
    assign CAT_RESETn = ~codec_arst;   // Codec Reset // RESETB // Operates active-low
    assign CAT_SYNC = 1'b0;

    ///////////////////////////////////////////////////////////////////////
    // b200 core
    ///////////////////////////////////////////////////////////////////////
    wire [9:0] fp_gpio_in, fp_gpio_out, fp_gpio_ddr;
    // Internal diagnostic pages only; no external GPIO pins are driven.
    assign fp_gpio_in = fp_gpio_out[2:0] == 1 ? {2'b0,lvds_debug_tx[7:0]} :
                        fp_gpio_out[2:0] == 2 ? {2'b0,lvds_debug_tx[15:8]} :
                        fp_gpio_out[2:0] == 3 ? {2'b0,lvds_debug_tx[23:16]} :
                        fp_gpio_out[2:0] == 4 ? {2'b0,lvds_debug_tx[31:24]} :
                        fp_gpio_out[2:0] == 5 ? {2'b0,lvds_debug_tx[39:32]} :
                        fp_gpio_out[2:0] == 6 ? {2'b0,lvds_debug_tx[47:40]} : lvds_debug_rx;
    assign device_id = 16'd0;

    b200_core #(.EXTRA_BUFF_SIZE(12)) b200_core
    (
        .bus_clk(bus_clk), .bus_rst(bus_rst),
        .tx_tdata(tx_tdata), .tx_tlast(tx_tlast), .tx_tvalid(tx_tvalid), .tx_tready(tx_tready),
        .rx_tdata(rx_tdata), .rx_tlast(rx_tlast),  .rx_tvalid(rx_tvalid), .rx_tready(rx_tready),
        .ctrl_tdata(ctrl_tdata), .ctrl_tlast(ctrl_tlast),  .ctrl_tvalid(ctrl_tvalid), .ctrl_tready(ctrl_tready),
        .resp_tdata(resp_tdata), .resp_tlast(resp_tlast),  .resp_tvalid(resp_tvalid), .resp_tready(resp_tready),

        .radio_clk(radio_clk), .radio_rst(radio_rst),
        .rx0(rx_data0), .rx1(rx_data1),
        .tx0(tx_data0), .tx1(tx_data1),
        .fe0_gpio_out(radio0_gpio), .fe1_gpio_out(radio1_gpio),
        .fp_gpio_in(fp_gpio_in), .fp_gpio_out(fp_gpio_out), .fp_gpio_ddr(fp_gpio_ddr),

        .pps_ref(pps_radio),
        .pps_fpga_int(pps_fpga_int),
        .pps_select(pps_select),
        .rxd(1'b1),
        .txd(),

        .sclk(sclk), .sen(sen), .mosi(mosi), .miso(miso),
        .rb_misc({31'b0, ext_ref_locked}), .misc_outs(misc_outs),
        .lock_signals(CAT_CTL_OUT[7:6]),
        .debug()
    );


    eth_radio_stream_control#(
        .CHDR_W                  ( 64 ),
        .USER_W                  ( 16 ),
        .BYPASS_RX_DEEP_FIFO     ( 1  )
    )u_eth_radio_stream_control(
        .clk                     ( bus_clk                     ),
        .rst                     ( bus_rst                     ),
        .e2v_tdata               ( e2v_tdata               ),
        .e2v_tuser               ( e2v_tuser               ),
        .e2v_tlast               ( e2v_tlast               ),
        .e2v_tvalid              ( e2v_tvalid              ),
        .e2v_tready              ( e2v_tready              ),
        .ctrl_tdata              ( ctrl_tdata              ),
        .ctrl_tlast              ( ctrl_tlast              ),
        .ctrl_tvalid             ( ctrl_tvalid             ),
        .ctrl_tready             ( ctrl_tready             ),
        .h2c_fifo_pre_tdata      ( h2c_fifo_pre_tdata      ),
        .h2c_fifo_pre_tvalid     ( h2c_fifo_pre_tvalid     ),
        .h2c_fifo_pre_tready     ( h2c_fifo_pre_tready     ),
        .h2c_fifo_pre_wr_count   ( h2c_fifo_pre_wr_count   ),
        .h2c_fifo_post_tdata     ( h2c_fifo_post_tdata     ),
        .h2c_fifo_post_tvalid    ( h2c_fifo_post_tvalid    ),
        .h2c_fifo_post_tready    ( h2c_fifo_post_tready    ),
        .h2c_fifo_post_rd_count  ( h2c_fifo_post_rd_count  ),

        .tx_tdata                ( tx_tdata                ),
        .tx_tlast                ( tx_tlast                ),
        .tx_tvalid               ( tx_tvalid               ),
        .tx_tready               ( tx_tready               ),
        .resp_tdata              ( resp_tdata              ),
        .resp_tlast              ( resp_tlast              ),
        .resp_tvalid             ( resp_tvalid             ),
        .resp_tready             ( resp_tready             ),
        .rx_tdata                ( rx_tdata                ),
        .rx_tlast                ( rx_tlast                ),
        .rx_tvalid               ( rx_tvalid               ),
        .rx_tready               ( rx_tready               ),
        .v2e_tdata               ( v2e_tdata               ),
        .v2e_tuser               ( v2e_tuser               ),
        .v2e_tlast               ( v2e_tlast               ),
        .v2e_tvalid              ( v2e_tvalid              ),
        .v2e_tready              ( v2e_tready              )
    );


    eth_internal #(.DWIDTH(REG_DWIDTH), .AWIDTH(REG_AWIDTH),
        .PORTNUM(SFP_PORTNUM)) net_internal (
        .bus_rst(bus_rst), .bus_clk(bus_clk),
        // Clock and reset
        .s_axi_aclk(reg_clk),
        .s_axi_aresetn(reg_rstn),
        // AXI4-Lite: Write address port (domain: s_axi_aclk)
        .s_axi_awaddr(m_axi_net_awaddr[REG_AWIDTH-1:0]),
        .s_axi_awvalid(m_axi_net_awvalid),
        .s_axi_awready(m_axi_net_awready),
        // AXI4-Lite: Write data port (domain: s_axi_aclk)
        .s_axi_wdata(m_axi_net_wdata),
        .s_axi_wstrb(m_axi_net_wstrb),
        .s_axi_wvalid(m_axi_net_wvalid),
        .s_axi_wready(m_axi_net_wready),
        // AXI4-Lite: Write response port (domain: s_axi_aclk)
        .s_axi_bresp(m_axi_net_bresp),
        .s_axi_bvalid(m_axi_net_bvalid),
        .s_axi_bready(m_axi_net_bready),
        // AXI4-Lite: Read address port (domain: s_axi_aclk)
        .s_axi_araddr(m_axi_net_araddr[REG_AWIDTH-1:0]),
        .s_axi_arvalid(m_axi_net_arvalid),
        .s_axi_arready(m_axi_net_arready),
        // AXI4-Lite: Read data port (domain: s_axi_aclk)
        .s_axi_rdata(m_axi_net_rdata),
        .s_axi_rresp(m_axi_net_rresp),
        .s_axi_rvalid(m_axi_net_rvalid),
        .s_axi_rready(m_axi_net_rready),

        // Ethernet to Vita
        .e2v_tdata(e2v_tdata),
        .e2v_tuser(e2v_tuser),
        .e2v_tlast(e2v_tlast),
        .e2v_tvalid(e2v_tvalid),
        .e2v_tready(e2v_tready),

        // Vita to Ethernet
        .v2e_tdata(v2e_tdata),
        .v2e_tuser(v2e_tuser),
        .v2e_tlast(v2e_tlast),
        .v2e_tvalid(v2e_tvalid),
        .v2e_tready(v2e_tready),


        // Ethernet to CPU
        .e2h_tdata(arm_eth_rx_tdata_b),
        .e2h_tkeep(arm_eth_rx_tkeep_b),
        .e2h_tlast(arm_eth_rx_tlast_b),
        .e2h_tvalid(arm_eth_rx_tvalid_b),
        .e2h_tready(arm_eth_rx_tready_b),

        // CPU to Ethernet
        .h2e_tdata(arm_eth_tx_tdata_b),
        .h2e_tkeep(arm_eth_tx_tkeep_b),
        .h2e_tlast(arm_eth_tx_tlast_b),
        .h2e_tvalid(arm_eth_tx_tvalid_b),
        .h2e_tready(arm_eth_tx_tready_b),

        // Misc
        .port_info(port_info),
        .device_id(device_id),

        // LED
        .link_up(link_up),
        .activity()
    );

    // assign ps_gpio_in[60] = ps_gpio_tri[60] ? link_up : ps_gpio_out[60];

    // assign LED_LINK1 = link_up;


    axi_fifo #(.WIDTH(1+8+64), .SIZE(5)) eth_tx_fifo_2clk_i (
        .reset(bus_rst), .clear(1'b0), .clk(bus_clk),
        .i_tdata({arm_eth_tx_tlast, arm_eth_tx_tkeep, arm_eth_tx_tdata}),
        .i_tvalid(arm_eth_tx_tvalid),
        .i_tready(arm_eth_tx_tready),
        .o_tdata({arm_eth_tx_tlast_b, arm_eth_tx_tkeep_b, arm_eth_tx_tdata_b}),
        .o_tvalid(arm_eth_tx_tvalid_b),
        .o_tready(arm_eth_tx_tready_b)
    );


    axi_fifo #(.WIDTH(1+8+64), .SIZE(5)) eth_rx_fifo_2clk_i (
        .reset(bus_rst), .clear(1'b0), .clk(bus_clk),
        .i_tdata({arm_eth_rx_tlast_b, arm_eth_rx_tkeep_b, arm_eth_rx_tdata_b}),
        .i_tvalid(arm_eth_rx_tvalid_b),
        .i_tready(arm_eth_rx_tready_b),
        .o_tdata({arm_eth_rx_tlast, arm_eth_rx_tkeep, arm_eth_rx_tdata}),
        .o_tvalid(arm_eth_rx_tvalid),
        .o_tready(arm_eth_rx_tready)
    );

    /////////////////////////////////////////////////////////////////////
    //
    // PS Connections
    //
    //////////////////////////////////////////////////////////////////////

    wire [63:0] gpio_i;
    wire [63:0] gpio_o;
    wire [63:0] gpio_t;


    assign gpio_i = {3'b0, link_up, 60'b0};

    e310_ps_bd_wrapper u_e310_ps_bd_wrapper(
        .FCLK_CLK0                  ( FCLK_CLK0                  ),
        .FCLK_CLK1                  ( FCLK_CLK1                  ),
        .FCLK_CLK2                  ( FCLK_CLK2                  ),
        .FCLK_RESET0_N              ( FCLK_RESET0_N              ),
        .FCLK_RESET1_N              ( FCLK_RESET1_N              ),
        .PS_DDR3_addr               ( PS_DDR3_addr               ),
        .PS_DDR3_ba                 ( PS_DDR3_ba                 ),
        .PS_DDR3_cas_n              ( PS_DDR3_cas_n              ),
        .PS_DDR3_ck_n               ( PS_DDR3_ck_n               ),
        .PS_DDR3_ck_p               ( PS_DDR3_ck_p               ),
        .PS_DDR3_cke                ( PS_DDR3_cke                ),
        .PS_DDR3_cs_n               ( PS_DDR3_cs_n               ),
        .PS_DDR3_dm                 ( PS_DDR3_dm                 ),
        .PS_DDR3_dq                 ( PS_DDR3_dq                 ),
        .PS_DDR3_dqs_n              ( PS_DDR3_dqs_n              ),
        .PS_DDR3_dqs_p              ( PS_DDR3_dqs_p              ),
        .PS_DDR3_odt                ( PS_DDR3_odt                ),
        .PS_DDR3_ras_n              ( PS_DDR3_ras_n              ),
        .PS_DDR3_reset_n            ( PS_DDR3_reset_n            ),
        .PS_DDR3_we_n               ( PS_DDR3_we_n               ),
        .PS_MIO_ddr_vrn             ( PS_MIO_ddr_vrn             ),
        .PS_MIO_ddr_vrp             ( PS_MIO_ddr_vrp             ),
        .PS_MIO_mio                 ( PS_MIO_mio                 ),
        .PS_MIO_ps_clk              ( PS_MIO_ps_clk              ),
        .PS_MIO_ps_porb             ( PS_MIO_ps_porb             ),
        .PS_MIO_ps_srstb            ( PS_MIO_ps_srstb            ),

        .arm_eth_rx_tdata           ( arm_eth_rx_tdata           ),
        .arm_eth_rx_tkeep           ( arm_eth_rx_tkeep           ),
        .arm_eth_rx_tlast           ( arm_eth_rx_tlast           ),
        .arm_eth_rx_tready          ( arm_eth_rx_tready          ),
        .arm_eth_rx_tvalid          ( arm_eth_rx_tvalid          ),

        .arm_eth_tx_tdata           ( arm_eth_tx_tdata           ),
        .arm_eth_tx_tkeep           ( arm_eth_tx_tkeep           ),
        .arm_eth_tx_tlast           ( arm_eth_tx_tlast           ),
        .arm_eth_tx_tready          ( arm_eth_tx_tready          ),
        .arm_eth_tx_tvalid          ( arm_eth_tx_tvalid          ),
        .bus_clk                    ( bus_clk                    ),
        .bus_rstn                   ( ~bus_rst                   ),
        .clk40                      ( clk40                      ),
        .clk40_rstn                 ( clk40_rstn                 ),

        .gpio_i                     ( gpio_i                     ),
        .gpio_o                     ( gpio_o                     ),
        .gpio_t                     ( gpio_t                     ),

        .h2c_fifo_post_tdata        (  h2c_fifo_post_tdata       ),
        .h2c_fifo_post_tready       (  h2c_fifo_post_tready      ),
        .h2c_fifo_post_tvalid       (  h2c_fifo_post_tvalid      ),
        .h2c_fifo_post_rd_count     (  h2c_fifo_post_rd_count   ),

        .h2c_fifo_pre_tdata         ( h2c_fifo_pre_tdata         ),
        .h2c_fifo_pre_tready        ( h2c_fifo_pre_tready        ),
        .h2c_fifo_pre_tvalid        ( h2c_fifo_pre_tvalid        ),
        .h2c_fifo_pre_wr_count      ( h2c_fifo_pre_wr_count ),


        .m_axi_net_araddr           ( m_axi_net_araddr           ),
        .m_axi_net_arready          ( m_axi_net_arready          ),
        .m_axi_net_arvalid          ( m_axi_net_arvalid          ),
        .m_axi_net_awaddr           ( m_axi_net_awaddr           ),
        .m_axi_net_awready          ( m_axi_net_awready          ),
        .m_axi_net_awvalid          ( m_axi_net_awvalid          ),
        .m_axi_net_bready           ( m_axi_net_bready           ),
        .m_axi_net_bresp            ( m_axi_net_bresp            ),
        .m_axi_net_bvalid           ( m_axi_net_bvalid           ),
        .m_axi_net_rdata            ( m_axi_net_rdata            ),
        .m_axi_net_rready           ( m_axi_net_rready           ),
        .m_axi_net_rresp            ( m_axi_net_rresp            ),
        .m_axi_net_rvalid           ( m_axi_net_rvalid           ),
        .m_axi_net_wdata            ( m_axi_net_wdata            ),
        .m_axi_net_wready           ( m_axi_net_wready           ),
        .m_axi_net_wstrb            ( m_axi_net_wstrb            ),
        .m_axi_net_wvalid           ( m_axi_net_wvalid           )

    );


endmodule
`default_nettype wire
