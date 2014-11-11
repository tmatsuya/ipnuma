`timescale 1ps/1ps

module TX_MUX (
	input clk,
	input sys_rst,
	// AXIS Output
	input s_axis_tx_tready,
	output [63:0] s_axis_tx_tdata,
	output [7:0] s_axis_tx_tkeep,
	output s_axis_tx_tlast,
	output s_axis_tx_tvalid,
	output tx_src_dsc,
	// AXIS Input 1
	output s_axis_tx1_req,
	output s_axis_tx1_ack,
	output s_axis_tx1_tready,
	input [63:0] s_axis_tx1_tdata,
	input [7:0] s_axis_tx1_tkeep,
	input s_axis_tx1_tlast,
	input s_axis_tx1_tvalid,
	input tx1_src_dsc,
	// AXIS Input 2
	output s_axis_tx2_req,
	output s_axis_tx2_ack,
	output s_axis_tx2_tready,
	input [63:0] s_axis_tx2_tdata,
	input [7:0] s_axis_tx2_tkeep,
	input s_axis_tx2_tlast,
	input s_axis_tx2_tvalid,
	input tx2_src_dsc
);

reg sel = 1'b0;

assign s_axis_tx1_tready= sel ? 1'b1: s_axis_tx_tready;
assign s_axis_tx2_tready= ~sel? 1'b1: s_axis_tx_tready;
assign s_axis_tx_tdata  = sel ? s_axis_tx2_tdata:  s_axis_tx1_tdata;
assign s_axis_tx_tkeep  = sel ? s_axis_tx2_tkeep:  s_axis_tx1_tkeep;
assign s_axis_tx_tlast  = sel ? s_axis_tx2_tlast:  s_axis_tx1_tlast;
assign s_axis_tx_tvalid = sel ? s_axis_tx2_tvalid: s_axis_tx1_tvalid;
assign tx_src_dsc       = sel ? tx2_src_dsc:       tx1_src_dsc;

endmodule // TX_MUX
