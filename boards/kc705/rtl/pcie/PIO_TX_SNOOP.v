`default_nettype none
`timescale 1ps/1ps

module PIO_TX_SNOOP (
	input wire clk,
	input wire sys_rst,

	//AXIS TX
	input wire s_axis_tx_tready,
	output [63:0] s_axis_tx_tdata,
	output [7:0] s_axis_tx_tkeep,
	output wire s_axis_tx_tlast,
	output wire s_axis_tx_tvalid,
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
	output wire rd_en,

	input wire [7:0] xgmii_pktcount,
	output wire [7:0] tlp_pktcount
);

`ifdef NO
// Local wires
parameter IDLE    = 2'b00;
parameter HEADER0 = 2'b01;
parameter DATA    = 2'b10;

reg [1:0] state = IDLE;
reg [1:0] fmt;
reg [4:0] type;
reg [9:0] length;
reg [2:0] gap = 3'd0;

always @(posedge clk) begin
	if (sys_rst) begin
		gap <= 3'd0;
		wr_en <= 1'b0;
		din <= {8'h00, 64'h00_00_00_00_00_00_00_00};
		state <= IDLE;
	end else begin
		wr_en <= 1'b0;
		din <= {m_axis_rx_tkeep, m_axis_rx_tdata};
		case (state)
			IDLE: begin
				if (m_axis_rx_tvalid) begin
					fmt <= m_axis_rx_tdata[30:29];
					type <= m_axis_rx_tdata[28:24];
					length <= m_axis_rx_tdata[9:0];
					wr_en <= 1'b1;
					state <= HEADER0;
				end else begin
					if (gap == 3'd0) begin
						wr_en <= 1'b0;
					end else begin
						gap <= gap - 3'd1;
						wr_en <= 1'b1;
						din <= {8'h00, 64'h00_00_00_00_00_00_00_00};
					end
				end
			end
			HEADER0: begin
				gap <= Gap;
				wr_en <= 1'b1;
				if (m_axis_rx_tlast)
					state <= IDLE;
				else
					state <= DATA;
			end
			DATA: begin
				wr_en <= 1'b1;
				if (m_axis_rx_tlast)
					state <= IDLE;
			end
		endcase
	end
end
`endif

assign tlp_pktcount = xgmii_pktcount;
endmodule // PIO_TX_SNOOP
`default_nettype wire
