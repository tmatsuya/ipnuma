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
	input wire [47:12] mem0_paddr,

	// XGMII-TX FIFO
	input wire req_gap,
	output reg [71:0] din,
	input wire full,
	output reg wr_en,

	input wire [3:0] dipsw
);

// Local wires
parameter IDLE    = 2'b00;
parameter HEADER1 = 2'b01;
parameter DATA    = 2'b10;

reg [1:0] state = IDLE;
reg [1:0] fmt = 2'b00;
reg [4:0] type = 5'b00000;
reg [9:0] length = 10'b0000000000;
reg [63:0] rx_tdata2 = 64'h00;
reg [7:0] rx_tkeep2 = 8'h00;
reg rx_tvalid2 = 1'b0;
reg rx_tlast2 = 1'b0;
reg completion = 1'b0;
reg [2:0] gap = 3'd0;

always @(posedge clk) begin
	if (sys_rst) begin
		wr_en <= 1'b0;
		rx_tdata2 <= 64'h00;
		rx_tkeep2 <= 8'h00;
		rx_tvalid2 <= 1'b0;
		rx_tlast2 <= 1'b0;
		completion <= 1'b0;
		gap <= 3'd0;
		din <= {8'h00, 64'h00_00_00_00_00_00_00_00};
		state <= IDLE;
	end else begin
		rx_tdata2 <= m_axis_rx_tdata;
		rx_tkeep2 <= m_axis_rx_tkeep;
		rx_tvalid2 <= m_axis_rx_tvalid;
		rx_tlast2 <= m_axis_rx_tlast;
//		if (req_gap)
//			gap <= Gap;
		case (state)
			IDLE: begin
//				if (m_axis_rx_tvalid && m_axis_rx_tuser[4]) begin  // BAR2 only
				if (m_axis_rx_tvalid && (m_axis_rx_tuser[4]|m_axis_rx_tdata[28:24]==5'b01010)) begin  // BAR2 or completion  only
					fmt <= m_axis_rx_tdata[30:29];
					type <= m_axis_rx_tdata[28:24];
					length <= m_axis_rx_tdata[9:0];
					state <= HEADER1;
					wr_en <= 1'b1;
					if (m_axis_rx_tdata[28:24]!=5'b01010) begin // if non-comletion then request_id invert
						completion <= 1'b0;
						din <= {4'hA, m_axis_rx_tkeep[4], m_axis_rx_tkeep[0], m_axis_rx_tlast, m_axis_rx_tvalid, ~m_axis_rx_tdata[63:60], m_axis_rx_tdata[59:0]};  // request ID invert
					end else begin
						completion <= 1'b1;
						din <= {4'hA, m_axis_rx_tkeep[4], m_axis_rx_tkeep[0], m_axis_rx_tlast, m_axis_rx_tvalid, m_axis_rx_tdata};
					end
//				end else begin
//					if (gap == 3'd0) begin
//						wr_en <= 1'b0;
//					end else begin
//						gap <= gap - 3'd1;
//						wr_en <= 1'b1;
//						din <= {8'h10, 64'h00_00_00_00_00_00_00_00};	// IFG=1
//					end
				end else
					wr_en <= 1'b0;
			end
			HEADER1: begin
				wr_en <= 1'b1;
				din[71:64] <= {4'hA, m_axis_rx_tkeep[4], m_axis_rx_tkeep[0], m_axis_rx_tlast, m_axis_rx_tvalid};
				if (type[4:1] == 4'b0000) begin	// memory access request (need address translation)
					if (fmt[0] == 1'b0) begin	// 32bit address
						din[63:0] <= {m_axis_rx_tdata[63:32], mem0_paddr[31:20], m_axis_rx_tdata[19:0]};
					end else begin			// 64bit address
						din[63:0] <= {mem0_paddr[31:20], m_axis_rx_tdata[19:0], 32'h0000_0000};
					end
				end else if (completion)  // completor TLP
					din[63:0] <= {m_axis_rx_tdata[63:32], ~m_axis_rx_tdata[31:28], m_axis_rx_tdata[27:0]};  // Inver Request ID
				else
					din[63:0] <= {m_axis_rx_tdata};
				wr_en <= 1'b1;
				if (m_axis_rx_tlast)
					state <= IDLE;
				else
					state <= DATA;
			end
			DATA: begin
				din <= {4'hA, m_axis_rx_tkeep[4], m_axis_rx_tkeep[0], m_axis_rx_tlast, m_axis_rx_tvalid, m_axis_rx_tdata};
				wr_en <= 1'b1;
				if (m_axis_rx_tlast)
					state <= IDLE;
			end
		endcase
	end
end


endmodule // PIO_RX_SNOOP
`default_nettype wire
