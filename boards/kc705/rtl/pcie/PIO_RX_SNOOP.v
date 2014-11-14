`default_nettype none
`timescale 1ps/1ps
// FIFO DIN b63-00: data
//          b64:    start TLP
//          b65:    last TLP
//          b66:    b31-b0 enable
//          b67:    b63-b32 enable
//          b68:    IFG
module PIO_RX_SNOOP # (
	parameter Gap = 3'd7
) (
	input wire clk,
	input wire sys_rst,

	//AXIS RX
	input wire [63:0] m_axis_rx_tdata,
	input wire [7:0] m_axis_rx_tkeep,
	input wire m_axis_rx_tlast,
	input wire m_axis_rx_tvalid,
	output wire m_axis_rx_tready,
	input wire [21:0] m_axis_rx_tuser,

	input wire [15:0] cfg_completer_id,

	// PCIe user registers
	input wire [31:0] if_v4addr,
	input wire [47:0] if_macaddr,
	input wire [31:0] dest_v4addr,
	input wire [47:0] dest_macaddr,

	// XGMII-TX FIFO
	input req_gap,
	output reg [71:0] din,
	input wire full,
	output reg wr_en
);

// Local wires
parameter RESET   = 3'b111;
parameter IDLE    = 3'b000;
parameter HEADER1 = 3'b001;
parameter DATA    = 3'b010;
parameter FIN     = 3'b011;

reg [2:0] state = RESET;
reg [1:0] fmt = 2'b00;
reg [4:0] type = 5'b00000;
reg [9:0] length = 10'b0000000000;
reg [63:0] rx_tdata2 = 64'h00;
reg [7:0] rx_tkeep2 = 8'h00;
reg rx_tlast2 = 1'b0;
reg [2:0] gap = 3'd0;

always @(posedge clk) begin
	if (sys_rst) begin
		wr_en <= 1'b0;
		rx_tdata2 <= 64'h00;
		rx_tkeep2 <= 8'h00;
		rx_tlast2 <= 1'b0;
		gap <= 3'd0;
		din <= {8'h00, 64'h00_00_00_00_00_00_00_00};
		state <= RESET;
	end else begin
		rx_tdata2 <= m_axis_rx_tdata;
		rx_tkeep2 <= m_axis_rx_tkeep;
		rx_tlast2 <= m_axis_rx_tlast;
		din <= {4'b00, rx_tkeep2[4], rx_tkeep2[0], rx_tlast2, 1'b0, rx_tdata2};
		wr_en <= 1'b0;
		if (req_gap)
			gap <= Gap;
		case (state)
			RESET: begin
				wr_en <= 1'b1;
				din <= {8'h00, 64'h00_00_00_00_00_00_00_00};	// dummy
				state <= IDLE;
			end
			IDLE: begin
				if (m_axis_rx_tvalid) begin
					fmt <= m_axis_rx_tdata[30:29];
					type <= m_axis_rx_tdata[28:24];
					length <= m_axis_rx_tdata[9:0];
					state <= HEADER1;
				end else begin
					if (gap == 3'd0) begin
						wr_en <= 1'b0;
					end else begin
						gap <= gap - 3'd1;
						wr_en <= 1'b1;
						din <= {8'h10, 64'h00_00_00_00_00_00_00_00};	// IFG=1
					end
				end
			end
			HEADER1: begin
				din[64] <= 1'b1;	// bit68: start bit
				wr_en <= 1'b1;
				if (type[4:1] == 4'b0000) begin	// memory access request (need address translation)
					if (fmt[0] == 1'b0)	// 32bit address
						;
					else				// 64bit address
						;
				end
				wr_en <= 1'b1;
				if (m_axis_rx_tlast)
					state <= FIN;
				else
					state <= DATA;
			end
			DATA: begin
				din[64] <= 1'b0;	// bit68: start bit
				wr_en <= 1'b1;
				if (m_axis_rx_tlast)
					state <= FIN;
			end
			FIN: begin
				wr_en <= 1'b1;
				state <= IDLE;
			end
		endcase
	end
end


endmodule // PIO_RX_SNOOP
`default_nettype wire
