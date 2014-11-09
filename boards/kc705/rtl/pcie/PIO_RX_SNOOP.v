`timescale 1ps/1ps

module PIO_RX_SNOOP (
	input clk,
	input sys_rst,

	//AXIS RX
	input [63:0] m_axis_rx_tdata,
	input [7:0] m_axis_rx_tkeep,
	input m_axis_rx_tlast,
	input m_axis_rx_tvalid,
	output m_axis_rx_tready,
	input [21:0] m_axis_rx_tuser,

	input [15:0] cfg_completer_id,

	// PCIe user registers
	output [31:0] if_v4addr,
	output [47:0] if_macaddr,
	output [31:0] dest_v4addr,
	output [47:0] dest_macaddr,

	// XGMII-TX FIFO
	output [71:0] din,
	input full,
	output reg wr_en
);

// Local wires

always @(posedge clk) begin
	if (sys_rst) begin
		wr_en <= 1'b0;
	end else begin
		wr_en <= 1'b1;
	end
end

assign din = {8'hff, 64'h07_07_07_07_07_07_07_07};

endmodule // PIO_RX_SNOOP
