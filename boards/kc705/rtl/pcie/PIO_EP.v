//-----------------------------------------------------------------------------
//
// (c) Copyright 2010-2011 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : PIO_EP.v
// Version    : 3.0
//
// Description: Endpoint Programmed I/O module.
//              Consists of Receive and Transmit modules and a Memory Aperture
//
//------------------------------------------------------------------------------

`timescale 1ps/1ps
`ifdef SIMULATION
`include "../rtl/setup.v"
`else
`include "../setup.v"
`endif

(* DowngradeIPIdentifiedWarnings = "yes" *)
module PIO_EP #(
  parameter C_DATA_WIDTH = 64,            // RX/TX interface data width

  // Do not override parameters below this line
  parameter KEEP_WIDTH = C_DATA_WIDTH / 8,              // TSTRB width
  parameter TCQ        = 1
) (
  input                         sys_rst,

  input                         clk,
  input                         rst_n,

  // AXIS TX
  input                         s_axis_tx_tready,
  output  [C_DATA_WIDTH-1:0]    s_axis_tx_tdata,
  output  [KEEP_WIDTH-1:0]      s_axis_tx_tkeep,
  output                        s_axis_tx_tlast,
  output                        s_axis_tx_tvalid,
  output                        tx_src_dsc,

  //AXIS RX
  input   [C_DATA_WIDTH-1:0]    m_axis_rx_tdata,
  input   [KEEP_WIDTH-1:0]      m_axis_rx_tkeep,
  input                         m_axis_rx_tlast,
  input                         m_axis_rx_tvalid,
  output                        m_axis_rx_tready,
  input   [21:0]                m_axis_rx_tuser,

  output                        req_compl,
  output                        compl_done,

  input   [15:0]                cfg_completer_id,

	// PCIe user registers
	output [31:0] if_v4addr,
	output [47:0] if_macaddr,
	output [31:0] dest_v4addr,
	output [47:0] dest_macaddr,

	// XGMII
	input xgmii_clk,
	output [63:0] xgmii_0_txd,
	output [ 7:0] xgmii_0_txc,
	input  [63:0] xgmii_0_rxd,
	input  [ 7:0] xgmii_0_rxc,

	output [7:0] led

);

    // Local wires

    wire  [13:0]      rd_addr;
    wire  [3:0]       rd_be;
    wire  [31:0]      rd_data;

    wire  [13:0]      wr_addr;
    wire  [7:0]       wr_be;
    wire  [31:0]      wr_data;
    wire              wr_en;
    wire              wr_busy;

    wire              req_compl_int;
    wire              req_compl_wd;
    wire              compl_done_int;

    wire  [2:0]       req_tc;
    wire              req_td;
    wire              req_ep;
    wire  [1:0]       req_attr;
    wire  [9:0]       req_len;
    wire  [15:0]      req_rid;
    wire  [7:0]       req_tag;
    wire  [7:0]       req_be;
    wire  [15:0]      req_addr;


    //
    // ENDPOINT MEMORY : 8KB memory aperture implemented in FPGA BlockRAM(*)
    //

    PIO_EP_MEM_ACCESS  #(
       .TCQ( TCQ )
       ) EP_MEM_inst (
      
      .clk(clk),               // I
      .rst_n(rst_n),           // I
      
      // Read Port
      
      .rd_addr(rd_addr),     // I [13:0]
      .rd_be(rd_be),         // I [3:0]
      .rd_data(rd_data),     // O [31:0]
      
      // Write Port
      
      .wr_addr(wr_addr),     // I [13:0]
      .wr_be(wr_be),         // I [7:0]
      .wr_data(wr_data),     // I [31:0]
      .wr_en(wr_en),         // I
      .wr_busy(wr_busy),     // O

	// PCIe user registers
	.if_v4addr(if_v4addr),
	.if_macaddr(if_macaddr),
	.dest_v4addr(dest_v4addr),
	.dest_macaddr(dest_macaddr)
      );

    //
    // Local-Link Receive Controller
    //

  PIO_RX_ENGINE #(
    .C_DATA_WIDTH( C_DATA_WIDTH ),
    .KEEP_WIDTH( KEEP_WIDTH ),
    .TCQ( TCQ )

  ) EP_RX_inst (

    .clk(clk),                              // I
    .rst_n(rst_n),                          // I

    // AXIS RX
    .m_axis_rx_tdata( m_axis_rx_tdata ),    // I
    .m_axis_rx_tkeep( m_axis_rx_tkeep ),    // I
    .m_axis_rx_tlast( m_axis_rx_tlast ),    // I
    .m_axis_rx_tvalid( m_axis_rx_tvalid ),  // I
    .m_axis_rx_tready( m_axis_rx_tready ),  // O
    .m_axis_rx_tuser ( m_axis_rx_tuser ),   // I

    // Handshake with Tx engine
    .req_compl(req_compl_int),              // O
    .req_compl_wd(req_compl_wd),            // O
    .compl_done(compl_done_int),            // I

    .req_tc(req_tc),                        // O [2:0]
    .req_td(req_td),                        // O
    .req_ep(req_ep),                        // O
    .req_attr(req_attr),                    // O [1:0]
    .req_len(req_len),                      // O [9:0]
    .req_rid(req_rid),                      // O [15:0]
    .req_tag(req_tag),                      // O [7:0]
    .req_be(req_be),                        // O [7:0]
    .req_addr(req_addr),                    // O [15:0]
                                            
    // Memory Write Port                    
    .wr_addr(wr_addr),                      // O [13:0]
    .wr_be(wr_be),                          // O [7:0]
    .wr_data(wr_data),                      // O [31:0]
    .wr_en(wr_en),                          // O
    .wr_busy(wr_busy)                       // I
                                            
  );

    //
    // Local-Link Transmit Controller
    //

  PIO_TX_ENGINE #(
    .C_DATA_WIDTH( C_DATA_WIDTH ),
    .KEEP_WIDTH( KEEP_WIDTH ),
    .TCQ( TCQ )
  )EP_TX_inst(

    .clk(clk),                                  // I
    .rst_n(rst_n),                              // I

    // AXIS Tx
    .s_axis_tx_tready( s_axis_tx_tready ),      // I
    .s_axis_tx_tdata( s_axis_tx_tdata ),        // O
    .s_axis_tx_tkeep( s_axis_tx_tkeep ),        // O
    .s_axis_tx_tlast( s_axis_tx_tlast ),        // O
    .s_axis_tx_tvalid( s_axis_tx_tvalid ),      // O
    .tx_src_dsc( tx_src_dsc ),                  // O

    // Handshake with Rx engine
    .req_compl(req_compl_int),                // I
    .req_compl_wd(req_compl_wd),              // I
    .compl_done(compl_done_int),                // 0

    .req_tc(req_tc),                          // I [2:0]
    .req_td(req_td),                          // I
    .req_ep(req_ep),                          // I
    .req_attr(req_attr),                      // I [1:0]
    .req_len(req_len),                        // I [9:0]
    .req_rid(req_rid),                        // I [15:0]
    .req_tag(req_tag),                        // I [7:0]
    .req_be(req_be),                          // I [7:0]
    .req_addr(req_addr),                      // I [15:0]

    // Read Port

    .rd_addr(rd_addr),                        // O [13:0]
    .rd_be(rd_be),                            // O [3:0]
    .rd_data(rd_data),                        // I [31:0]

    .completer_id(cfg_completer_id)           // I [15:0]

    );

`ifdef ENABLE_REQUESTER
//
// FIFO for XGMII-TX
//
wire [71:0] tx0_phyq_din, tx0_phyq_dout;
wire tx0_phyq_full;
wire tx0_phyq_wr_en;
wire tx0_phyq_empty;
wire tx0_phyq_rd_en;
wire tx0_phyq_prog_full;

afifo72_w250_r156 afifo72_w250_r156_0 (
	.rst(sys_rst),
	.wr_clk(clk),
	.rd_clk(xgmii_clk),
	.din(tx0_phyq_din),
	.wr_en(tx0_phyq_wr_en),
	.rd_en(tx0_phyq_rd_en),
	.dout(tx0_phyq_dout),
	.full(tx0_phyq_full),
	.empty(tx0_phyq_empty)
);


//
// PCIE-RX SNOOP
//
PIO_RX_SNOOP PIO_RX_SNOOP_inst (
    .clk(clk),               // I
    .sys_rst(sys_rst),        // I
      
    // AXIS RX
    .m_axis_rx_tdata( m_axis_rx_tdata ),    // I
    .m_axis_rx_tkeep( m_axis_rx_tkeep ),    // I
    .m_axis_rx_tlast( m_axis_rx_tlast ),    // I
    .m_axis_rx_tvalid( m_axis_rx_tvalid ),  // I
    .m_axis_rx_tready( m_axis_rx_tready ),  // O
    .m_axis_rx_tuser ( m_axis_rx_tuser ),   // I

    .cfg_completer_id(cfg_completer_id),           // I [15:0]

	// PCIe user registers
	.if_v4addr(if_v4addr),
	.if_macaddr(if_macaddr),
	.dest_v4addr(dest_v4addr),
	.dest_macaddr(dest_macaddr),

	// XGMII-TX FIFO
	.din(tx0_phyq_din),
	.full(tx0_phyq_full),
	.wr_en(tx0_phyq_wr_en)
);

//
// XGMII-TX ENGINE
//
XGMII_TX_ENGINE XGMII_TX_ENGINE_inst (
	.sys_rst(sys_rst),           // I
	// XGMII-TX FIFO
	.dout(tx0_phyq_dout),
	.empty(tx0_phyq_empty),
	.rd_en(tx0_phyq_rd_en),
	// XGMII
        .xgmii_clk(xgmii_clk),
        .xgmii_txd({xgmii_0_txc,xgmii_0_txd}),
	// PCIe user registers
	.if_v4addr(if_v4addr),
	.if_macaddr(if_macaddr),
	.dest_v4addr(dest_v4addr),
	.dest_macaddr(dest_macaddr)
);
`else
assign xgmii_0_txd = 64'h07_07_07_07_07_07_07_07;
assign xgmii_0_txc = 8'hff;
`endif

`ifdef ENABLE_SERVER
//
// FIFO for XGMII-RX
//
wire [71:0] rx0_phyq_din, rx0_phyq_dout;
wire rx0_phyq_full;
wire rx0_phyq_wr_en;
wire rx0_phyq_empty;
wire rx0_phyq_rd_en;
wire rx0_phyq_prog_full;

afifo72_w156_r250 afifo72_w156_r250_0 (
	.rst(sys_rst),
	.wr_clk(xgmii_clk),
	.rd_clk(clk),
	.din(rx0_phyq_din),
	.wr_en(rx0_phyq_wr_en),
	.rd_en(rx0_phyq_rd_en),
	.dout(rx0_phyq_dout),
	.full(rx0_phyq_full),
	.empty(rx0_phyq_empty)
);

//
// XGMII-RX ENGINE
//
XGMII_RX_ENGINE XGMII_RX_ENGINE_inst (
	.sys_rst(sys_rst),           // I
	// XGMII
        .xgmii_clk(xgmii_clk),
        .xgmii_rxc(xgmii_0_rxc),
        .xgmii_rxd(xgmii_0_rxd),
	// PCIe user registers
	.if_v4addr(if_v4addr),
	.if_macaddr(if_macaddr),
	.dest_v4addr(dest_v4addr),
	.dest_macaddr(dest_macaddr),
	// XGMII-RX FIFO
	.din(rx0_phyq_din),
	.full(rx0_phyq_full),
	.wr_en(rx0_phyq_wr_en),

	.led(led)
);

//
// PCIE-TX SNOOP
PIO_TX_SNOOP PIO_TX_SNOOP_inst (
    .clk(clk),               // I
    .sys_rst(sys_rst),        // I
      
    // AXIS TX
//    s_axis_tx_tready(s_axis_tx_tready),     // I
//    s_axis_tx_tdata(s_axis_tx_tdata),       // O
//    s_axis_tx_tkeep(s_axis_tx_tkeep),       // O
//    s_axis_tx_tlast(s_axis_tx_tlast),       // O
//    s_axis_tx_tvalid(s_axis_tx_tvalid),     // O
//    tx_src_dsc(tx_src_dsc),                 // O

    .cfg_completer_id(cfg_completer_id),           // I [15:0]

	// PCIe user registers
	.if_v4addr(if_v4addr),
	.if_macaddr(if_macaddr),
	.dest_v4addr(dest_v4addr),
	.dest_macaddr(dest_macaddr),

	// XGMII-RX FIFO
	.dout(rx0_phyq_dout),
	.empty(rx0_phyq_empty),
	.rd_en(rx0_phyq_rd_en)
);
`else
`endif

assign req_compl  = req_compl_int;
assign compl_done = compl_done_int;

endmodule // PIO_EP
