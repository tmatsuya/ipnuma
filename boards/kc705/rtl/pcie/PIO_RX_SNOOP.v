`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module PIO_RX_SNOOP #(
  parameter C_DATA_WIDTH = 64,            // RX/TX interface data width

  // Do not override parameters below this line
  parameter KEEP_WIDTH = C_DATA_WIDTH / 8,              // TSTRB width
  parameter TCQ        = 1
) (

  input                         clk,
  input                         rst_n,

  //AXIS RX
  input   [C_DATA_WIDTH-1:0]    m_axis_rx_tdata,
  input   [KEEP_WIDTH-1:0]      m_axis_rx_tkeep,
  input                         m_axis_rx_tlast,
  input                         m_axis_rx_tvalid,
  output                        m_axis_rx_tready,
  input   [21:0]                m_axis_rx_tuser,

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
	input  [ 7:0] xgmii_0_rxc
);

    // Local wires

assign xgmii_0_txd = 64'h07_07_07_07_07_07_07_07;
assign xgmii_0_txc = 8'hff;

endmodule // PIO_RX_SNOOP

