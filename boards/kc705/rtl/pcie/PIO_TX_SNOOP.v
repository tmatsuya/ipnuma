`default_nettype none
`timescale 1ps/1ps

module PIO_TX_SNOOP (
	input wire clk,
	input wire sys_rst,

	//AXIS TX
	output reg s_axis_tx_req = 1'b0,
	input wire s_axis_tx_ack,
	input wire s_axis_tx_tready,
	output reg [63:0] s_axis_tx_tdata,
	output reg [7:0] s_axis_tx_tkeep,
	output reg s_axis_tx_tlast,
	output reg s_axis_tx_tvalid,
	output wire tx_src_dsc,

	input wire [15:0] cfg_completer_id,

	// PCIe user registers
	input wire [31:0] if_v4addr,
	input wire [47:0] if_macaddr,
	input wire [31:0] dest_v4addr,
	input wire [47:0] dest_macaddr,

	// XGMII-RX FIFO
	output wire [71:0] dout,
	input wire empty,
	output reg rd_en,

	input wire [7:0] xgmii_pktcount,
	output reg [7:0] tlp_pktcount = 8'h00
);

// Local wires
parameter TLP_IDLE       = 2'b00;
parameter TLP_SEARCH     = 2'b01;
parameter TLP_HEADER0    = 2'b10;
parameter TLP_DATA       = 2'b11;
reg [1:0] tlp_state = TLP_IDLE;

always @(posedge clk) begin
	if (sys_rst) begin
		rd_en <= 1'b0;
		s_axis_tx_req <= 1'b0;
		tlp_pktcount <= 8'h00;
		tlp_state <= TLP_IDLE;
	end else begin
		s_axis_tx_tdata <= dout[63:0];
		s_axis_tx_tkeep <= {{4{dout[67]}}, {4{dout[66]}}}; 
		s_axis_tx_tvalid <= 1'b0;
		s_axis_tx_tlast <= 1'b0;
		case (tlp_state)
		TLP_IDLE: begin
			if (xgmii_pktcount != tlp_pktcount) begin
				s_axis_tx_req <= 1'b1;
				if (s_axis_tx_ack)
					tlp_state <= TLP_SEARCH;
			end else
				s_axis_tx_req <= 1'b0;
		end
		TLP_SEARCH: begin
			rd_en <= ~empty;
			if (rd_en && dout[64]) begin  // TLP start?
				s_axis_tx_tvalid <= 1'b1;
				tlp_state <= TLP_HEADER0;
			end
		end
		TLP_HEADER0: begin
			rd_en <= ~empty;
			if (rd_en) begin
				s_axis_tx_tvalid <= 1'b1;
				if (dout[65]) begin  // TLP endt?
					tlp_pktcount <= tlp_pktcount + 8'd1;
					s_axis_tx_tlast <= 1'b1;
					s_axis_tx_req <= 1'b0;
					tlp_state <= TLP_SEARCH;
				end
			end
		end
		endcase
	end
end

assign tx_src_dsc = 1'b0;

endmodule // PIO_TX_SNOOP
`default_nettype wire
