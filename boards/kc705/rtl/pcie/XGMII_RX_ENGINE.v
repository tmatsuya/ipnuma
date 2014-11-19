`ifdef SIMULATION
`include "../rtl/setup.v"
`else
`include "../setup.v"
`endif
// FIFO DIN b63-00: data
//          b64:    Valid TLP
//          b65:    TLP last
//          b66:    b31-b0 enable
//          b67:    b63-b32 enable
module XGMII_RX_ENGINE # (
	parameter Gap = 4'h1
) (
	input wire sys_rst,
	input wire clk,
`ifndef ORF
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
`endif

	// XGMII
	input wire xgmii_clk,
	input wire [7:0] xgmii_rxc,
	input wire [63:0] xgmii_rxd,
	// PCIe user registers
	input wire [31:0] if_v4addr,
	input wire [47:0] if_macaddr,
	input wire [31:0] dest_v4addr,
	input wire [47:0] dest_macaddr,
	// XGMII-RX FIFO
	output reg [71:0] din,
	input full,
	output reg wr_en,

	output reg [7:0] xgmii_pktcount = 8'h0,

	output wire [7:0] debug
);

reg [7:0] led_r = 8'h00;

//-----------------------------------
// Recive logic
//-----------------------------------
reg [15:0] rx_count = 0;
reg [31:0] rx_magic;
reg [15:0] rx_type;	 // frame type
reg [47:0] rx_src_mac;
reg [7:0] rx_protocol;
reg [15:0] rx_dport;
reg [9:0] dwlen = 10'h0;
reg tlp_frame_end = 1'b0;
reg [3:0] gap = 4'h0;

parameter RX_IDLE  = 3'b000;
parameter RX_HEAD  = 3'b001;
parameter RX_TLP1  = 3'b010;
parameter RX_TLP2  = 3'b011;
parameter RX_GAP   = 3'b100;

reg [2:0] rx_state = RX_IDLE;
`ifndef ORF
reg [63:0] tlp1 = 64'h0, tlp2 = 64'h0;
`endif

always @(posedge xgmii_clk) begin
	if (sys_rst) begin
		rx_count <= 16'h0;
		rx_magic <= 32'b0;
		rx_type <= 16'h0;
		rx_src_mac <= 48'h0;
		rx_protocol <= 8'h0;
		rx_dport <= 16'h00;
		dwlen <= 10'h0;
		wr_en <= 1'b0;
		led_r <= 8'h00;
		tlp_frame_end <= 1'b0;
		rx_state <= RX_IDLE;
`ifndef ORF
		tlp1 <= 64'h0;
		tlp2 <= 64'h0;
`endif
	end else begin
		tlp_frame_end <= 1'b0;
		din[63:0] <= xgmii_rxd;
		din[71:68] <= 4'b0000;
		wr_en <= 1'b0;
		case (rx_state)
		RX_IDLE: begin
			rx_count <= 16'h0;
			gap <= Gap;
			if (xgmii_rxc[0] == 1'b1 && xgmii_rxd[7:0] == 8'hfb)
				rx_state <= RX_HEAD;
		end
		RX_HEAD: begin
			rx_count <= rx_count + 16'h8;
			if (xgmii_rxc[7:0] == 8'hff)
				rx_state <= RX_IDLE;
			case (rx_count)
			16'h00: begin
				rx_src_mac[47:40] <= xgmii_rxd[ 7: 0];// Ethernet hdr: Source MAC
				rx_src_mac[39:32] <= xgmii_rxd[15: 8];
				rx_src_mac[31:24] <= xgmii_rxd[23:16];
				rx_src_mac[23:16] <= xgmii_rxd[31:24];
				rx_src_mac[15: 8] <= xgmii_rxd[39:32];
				rx_src_mac[ 7: 0] <= xgmii_rxd[47:40];
			end
			16'h08: begin
				rx_type[15:8]     <= xgmii_rxd[39:32];
				rx_type[ 7:0]     <= xgmii_rxd[47:40];
			end
			16'h10: begin
				rx_protocol[7:0]  <= xgmii_rxd[63:56];
			end
			16'h20: begin
				rx_dport[15:8]    <= xgmii_rxd[39:32];
				rx_dport[ 7:0]    <= xgmii_rxd[47:40];
			end
			16'h28: begin
				rx_magic[31:24] <= xgmii_rxd[23:16];
				rx_magic[23:16] <= xgmii_rxd[31:24];
				rx_magic[15:8]  <= xgmii_rxd[39:32];
				rx_magic[7:0]   <= xgmii_rxd[47:40];
				if (rx_type == 16'h0800 && rx_protocol == 8'h11 && rx_dport == 16'd3422 && {xgmii_rxd[23:16], xgmii_rxd[31:24], xgmii_rxd[39:32], xgmii_rxd[47:40]} == `MAGIC_CODE) begin
					led_r <= led_r + 8'd1; // xgmii_rxd[7:0];
					rx_state <= RX_TLP1;
				end
			end
			endcase
		end
		RX_TLP1: begin
`ifndef ORF
			tlp1 <= xgmii_rxd[63:0];
			rx_state <= RX_TLP2;
`else
			if (xgmii_rxc[7:0] != 8'h00)
				rx_state <= RX_GAP;
			else begin
				din[67:64] <= 4'b1101; // Start TLP
				// bit64:xgmii_rxd[29]; length:xgmii_rxd[9:0]
				dwlen <= (xgmii_rxd[30] ? xgmii_rxd[9:0] : 10'd0) - 10'd1 + {9'd0, xgmii_rxd[29]}; // tlp DWlength
				wr_en <= 1'b1;
				rx_state <= RX_TLP2;
			end
`endif
		end
		RX_TLP2: begin
`ifndef ORF
			tlp2 <= xgmii_rxd[63:0];
			tlp_frame_end <= 1'b1;
			rx_state <= RX_IDLE;
`else
			wr_en <= 1'b1;
			dwlen <= dwlen - 10'd2;
			case (dwlen)
			10'd0: begin
				din[67:64] <= 4'b1111; // End TLP (2DW)
				tlp_frame_end <= 1'b1;
				rx_state <= RX_TLP1;
			end
			10'd1023: begin
				din[67:64] <= 4'b0111; // End TLP (1DW)
				tlp_frame_end <= 1'b1;
				rx_state <= RX_TLP1;
			end
			default: begin
				din[67:64] <= 4'b1101; // TLP (2DW)
			end
			endcase
`endif
		end
`ifdef ORF
		RX_GAP: begin
        		s_axis_tx_req = 1'b0;
			gap <= gap - 4'h1;
			if (gap == 4'h0)
				rx_state <= RX_IDLE;
			din <= 72'h00;
			wr_en <= 1'b1;
		end
`endif
		endcase
	end
end

//-----------------------------------
// count XGMII frame
//-----------------------------------
reg [3:0] prev_xgmii_end;
always @(posedge clk) begin
	if (sys_rst) begin
		xgmii_pktcount <= 8'h0;
		prev_xgmii_end <= 4'b0000;
	end else begin
		prev_xgmii_end <= {tlp_frame_end, prev_xgmii_end[3:1]};
		if (prev_xgmii_end == 4'b0001)
			xgmii_pktcount <= xgmii_pktcount + 8'd1;
	end
end

//-----------------------------------
// ORF Special
//-----------------------------------
parameter ORF_IDLE = 2'b00;
parameter ORF_ACK  = 2'b01;
parameter ORF_TLP1 = 2'b10;
parameter ORF_TLP2 = 2'b11;
reg [1:0] orf_state = ORF_IDLE;
always @(posedge clk) begin
	if (sys_rst) begin
		s_axis_tx_tvalid <= 1'b0;
		s_axis_tx_tlast  <= 1'b0;
		orf_state <= ORF_IDLE;
	end else begin
		case (orf_state)
		ORF_IDLE: begin
			s_axis_tx_tvalid <= 1'b0;
			s_axis_tx_tlast  <= 1'b0;
			if (prev_xgmii_end == 4'b0001) begin
				s_axis_tx_req <= 1'b1;
				orf_state <= ORF_ACK;
			end else
				s_axis_tx_req <= 1'b0;
		end
		ORF_ACK: begin
			s_axis_tx_req <= 1'b1;
			if (s_axis_tx_ack)
				orf_state <= ORF_TLP1;
		end
		ORF_TLP1: begin
        		s_axis_tx_req    <= 1'b1;
			s_axis_tx_tvalid <= 1'b1;
			s_axis_tx_tlast  <= 1'b0;
			s_axis_tx_tdata  <=  tlp1;
			s_axis_tx_tkeep  <= 8'hff;
			orf_state  <= ORF_TLP2;
		end
		ORF_TLP2: begin
        		s_axis_tx_req    <= 1'b1;
			s_axis_tx_tvalid <= 1'b1;
			s_axis_tx_tlast  <= 1'b1;
			s_axis_tx_tdata  <=  tlp2;
			s_axis_tx_tkeep  <= 8'hff;
			orf_state  <= ORF_IDLE;
		end
		endcase
	end
end

assign debug = led_r;

endmodule
