`default_nettype none
module requester (
	// System
	input pcie_clk,
	input sys_rst,
	// Management
	input [6:0] rx_bar_hit,
	input [7:0] bus_num,
	input [4:0] dev_num,
	input [2:0] func_num,
	// Receive
	input rx_st,
	input rx_end,
	input [15:0] rx_data,
	// Phy FIFO
	output [8:0]  phy_din,
	input phy_full,
	output reg  phy_wr_en,
	input [8:0] phy_dout,
	input phy_empty,
	output reg phy_rd_en,
	// Interface Information
	input [31:0] if_v4addr,
	input [47:0] if_macaddr,
	input [31:0] dest_v4addr,
	input [47:0] dest_macaddr,
	// Page Table
	input [47:0] mem0_paddr,
	// LED and Switches
	input [7:0] dipsw,
	output [7:0] led,
	output [13:0] segled,
	input btn
);

// FIFO
reg dataq_wr_en;
reg [17:0] dataq_din;
wire dataq_full;
reg dataq_rd_en;
wire [17:0] dataq_dout;
wire dataq_empty;

fifo fifo_dataq (
        .Data(dataq_din),
        .Clock(pcie_clk),
        .WrEn(dataq_wr_en),
        .RdEn(dataq_rd_en),
        .Reset(sys_rst),
        .Q(dataq_dout),
        .Empty(dataq_empty),
        .Full(dataq_full)
);

//-----------------------------------
// Transmitte logic
//-----------------------------------
reg [10:0] tx_count = 16'h0;
reg [7:0] tx_data;
reg tx_en = 1'b0;

//-----------------------------------
// scenario parameter
//-----------------------------------
parameter [3:0]
	TLP_IDLE     = 4'h0,
	TLP_HEAD1    = 4'h1,
	TLP_HEAD2    = 4'h2,
	TLP_HEAD3    = 4'h3,
	TLP_ADDR64   = 4'h4,
	TLP_ADDR48   = 4'h5,
	TLP_ADDR32   = 4'h6,
	TLP_ADDR16   = 4'h7,
	TLP_DATA0    = 4'h8,
	TLP_DATA1    = 4'h9,
	TLP_DATA2    = 4'ha,
	TLP_DATA3    = 4'hb,
	TLP_FIN      = 4'hf;
reg [3:0] tlp_status = TLP_IDLE;
parameter [1:0]
	PHY_IDLE     = 2'h0,
	PHY_V4_SEND  = 2'h1,
	PHY_FIN      = 2'h2,
	PHY_GAP      = 2'h3;
reg [1:0] phy_status = PHY_IDLE;
	
wire [31:0] magic_code    = 32'ha1110000;
wire [15:0] ipv4_id       = 16'h1;
wire [7:0]  ipv4_ttl      = 8'h40;      // IPv4: default TTL value (default: 64)
wire [15:0] tx_frame_len  = 16'h3d;
wire [15:0] tx_udp_len    = tx_frame_len - 16'd34;  // UDP Length
wire [15:0] tx_ip_len     = tx_frame_len - 16'd14;  // IP Length (Frame Len - EtherFrame Len)

reg [9:0] tlp_length;
reg [47:2] tlp_addr;
reg [7:0] tlp_lbefbe;
reg [31:0] tlp_data;
reg tlp_64bit;

reg [15:0] gap_count;
reg [23:0] ip_sum;

//-----------------------------------
// check TLP
//-----------------------------------
always @(posedge pcie_clk) begin
	if (sys_rst) begin
//		dataq_wr_en <= 1'b0;
//		dataq_din <= 18'h0;
		tlp_status <= TLP_IDLE;
	end else begin
		case (tlp_status)
		TLP_IDLE: begin
			// check write bit
			if (rx_bar_hit[2] == 1'b1 && rx_st == 1'b1 && rx_data[14] == 1'b1) begin
				tlp_64bit <= rx_data[13];
				tlp_status <= TLP_HEAD1;
			end
		end
		TLP_HEAD1: begin
			tlp_length <= rx_data[9:0];
			tlp_status <= TLP_HEAD2;
		end
		TLP_HEAD2: begin
			tlp_status <= TLP_HEAD3;
		end
		TLP_HEAD3: begin
//			dataq_wr_en <= 1'b1;
//			dataq_din <= {3'b10_1, tlp_64bit, tlp_length[5:0], rx_data[7:0]}; // start=1 write=1
			tlp_lbefbe <= rx_data[7:0];
			tlp_addr[47:31] <= 16'h0;
			if (tlp_64bit == 1'b0)
				tlp_status <= TLP_ADDR32;
			else
				tlp_status <= TLP_ADDR64;
		end
		TLP_ADDR64: begin
//			dataq_wr_en <= 1'b1;
//			dataq_din <= 16'h0;
			tlp_status <= TLP_ADDR48;
		end
		TLP_ADDR48: begin
//			dataq_wr_en <= 1'b1;
//			dataq_din <= {2'b00, mem0_paddr[47:32]};
			tlp_addr[47:32] <= rx_data[15:0];
			tlp_status <= TLP_ADDR32;
		end
		TLP_ADDR32: begin
//			dataq_wr_en <= 1'b1;
//			dataq_din <= {2'b00, mem0_paddr[31:16]};
			tlp_addr[31:16] <= rx_data[15:0];
			tlp_status <= TLP_ADDR16;
		end
		TLP_ADDR16: begin
//			dataq_wr_en <= 1'b1;
//			dataq_din <= {2'b00, mem0_paddr[15: 2],2'b00};
			tlp_addr[15: 2] <= rx_data[15:2];
			if ({tlp_addr[19:16],rx_data[15:2],2'b00} == 20'h37760)
				tlp_status <= TLP_DATA0;
			else
				tlp_status <= TLP_IDLE;
		end
		TLP_DATA0: begin
			tlp_status <= TLP_DATA1;
			tlp_data[31:16] <= rx_data[15:0];
//			dataq_wr_en <= 1'b1;
//			dataq_din[17] <= 1'b0;
//			dataq_din[15:0] <= rx_data[15:0];
//			if (rx_end == 1'b1) begin
//				dataq_din[16] <= 1'b1;	// end = 1
//				tlp_status <= TLP_FIN;
//			end else begin
//				dataq_din[16] <= 1'b0;	// end = 0
//			end
		end
		TLP_DATA1: begin
			tlp_status <= TLP_FIN;
			tlp_data[15: 0] <= rx_data[15:0];
		end
		TLP_FIN: begin
//			dataq_wr_en <= 1'b0;
//			dataq_din <= 18'h0;
			tlp_status <= TLP_IDLE;
		end
		endcase
	end
end


//-----------------------------------
// Phy sequence
//-----------------------------------
always @(posedge pcie_clk) begin
	if (sys_rst) begin
//		dataq_rd_en    <= 1'b0;
		tx_count       <= 11'h0;
		tx_en          <= 1'b0;
		phy_status     <= PHY_IDLE;
		gap_count      <= 16'h0;
		phy_wr_en      <= 1'b0;
	end else begin
		case (phy_status)
		PHY_IDLE: begin
			tx_count  <= 11'h0;
			phy_wr_en <= 1'b0;
//			if (dataq_empty == 1'b0) begin
			if (tlp_status == TLP_DATA0) begin
				phy_status <= PHY_V4_SEND;
			end
		end
		PHY_V4_SEND: begin
			phy_wr_en <= 1'b1;
			case (tx_count)
			11'h00: begin
				tx_data <= dest_macaddr[47:40];     // Destination MAC
				ip_sum <= 16'h4500 + {4'h0,tx_ip_len[11:0]} + ipv4_id[15:0] + {ipv4_ttl[7:0],8'h11} + if_v4addr[31:16] + if_v4addr[15:0] + dest_v4addr[31:16] + dest_v4addr[15:0];
				tx_en <= 1'b1;
			end
			11'h01: begin
				tx_data <= dest_macaddr[39:32];
				ip_sum  <= ~(ip_sum[15:0] + ip_sum[23:16]);
			end
			11'h02: tx_data <= dest_macaddr[31:24];
			11'h03: tx_data <= dest_macaddr[23:16];
			11'h04: tx_data <= dest_macaddr[15:8];
			11'h05: tx_data <= dest_macaddr[7:0];
			11'h06: tx_data <= if_macaddr[47:40];     // Source MAC
			11'h07: tx_data <= if_macaddr[39:32];
			11'h08: tx_data <= if_macaddr[31:24];
			11'h09: tx_data <= if_macaddr[23:16];
			11'h0a: tx_data <= if_macaddr[15:8];
			11'h0b: tx_data <= if_macaddr[7:0];
			11'h0c: tx_data <= 8'h08;                  // Protocol type: IPv4
			11'h0d: tx_data <= 8'h00;
			11'h0e: tx_data <= 8'h45;                  // IPv4: Version, Header length, ToS
			11'h0f: tx_data <= 8'h00;
			11'h10: tx_data <= {4'h0,tx_ip_len[11:8]};// IPv4: Total length (not fixed)
			11'h11: tx_data <= tx_ip_len[7:0];
			11'h12: tx_data <= ipv4_id[15:8];          // IPv4: Identification
			11'h13: tx_data <= ipv4_id[7:0];
			11'h14: tx_data <= 8'h00;                  // IPv4: Flag, Fragment offset
			11'h15: tx_data <= 8'h00;
			11'h16: tx_data <= ipv4_ttl[7:0];          // IPv4: TTL
			11'h17: tx_data <= 8'h11;                  // IPv4: Protocol (testing: fake UDP)
			11'h18: tx_data <= ip_sum[15:8];                  // IPv4: Checksum (not fixed)
			11'h19: tx_data <= ip_sum[7:0];
			11'h1a: tx_data <= if_v4addr[31:24];  // IPv4: Source Address
			11'h1b: tx_data <= if_v4addr[23:16];
			11'h1c: tx_data <= if_v4addr[15:8];
			11'h1d: tx_data <= if_v4addr[7:0];
			11'h1e: tx_data <= dest_v4addr[31:24];      // IPv4: Destination Address
			11'h1f: tx_data <= dest_v4addr[23:16];
			11'h20: tx_data <= dest_v4addr[15:8];
			11'h21: tx_data <= dest_v4addr[7:0];
			11'h22: tx_data <= 8'h0d;                  // Src  Port=3422 (USB over IP)
			11'h23: tx_data <= 8'h5e;
			11'h24: tx_data <= 8'h0d;                  // Dst  Port,
			11'h25: tx_data <= 8'h5e;
			11'h26: tx_data <= {4'h0,tx_udp_len[11:8]}; // UDP Length(udp header(0c)+data length)
			11'h27: tx_data <= tx_udp_len[7:0];
			11'h28: tx_data <= 8'h00;                  // Check Sum
			11'h29: tx_data <= 8'h00;
			11'h2a: tx_data <= magic_code[31:24];      // Data: Magic code (32 bit)
			11'h2b: tx_data <= magic_code[23:16];
			11'h2c: tx_data <= magic_code[15:8];
			11'h2d: tx_data <= magic_code[7:0];
			11'h2e: tx_data <= 8'hc1;         // Data
			11'h2f: tx_data <= 8'hff;
			11'h30: tx_data <= 8'h00;
			11'h31: tx_data <= 8'h00;
			11'h32: tx_data <= mem0_paddr[47:40];
			11'h33: tx_data <= mem0_paddr[39:32];
			11'h34: tx_data <= mem0_paddr[31:24];
			11'h35: tx_data <= mem0_paddr[23:16];
			11'h36: tx_data <= mem0_paddr[15: 8];
			11'h37: tx_data <= mem0_paddr[ 7: 0];
			11'h38: tx_data <= tlp_data[31:24];
			11'h39: tx_data <= tlp_data[23:16];
			11'h3a: tx_data <= tlp_data[15: 8];
			11'h3b: tx_data <= tlp_data[ 7: 0];
			default: begin
				tx_data <= 8'h00;
				phy_status <= PHY_FIN;
			end
			endcase
			tx_count <= tx_count + 11'h1;
		end
		PHY_FIN: begin
			tx_en   <= 1'b0;
			tx_data <= 8'h0;
			gap_count<= 16'd8;   // Inter Frame Gap = 14 (offset value -2)
			phy_status <= PHY_GAP;
		end
		PHY_GAP: begin
			gap_count <= gap_count - 16'h1;
			if (gap_count == 16'h0) begin
				phy_wr_en <= 1'b0;
				phy_status <= PHY_IDLE;
			end
		end
		endcase
	end
end

assign phy_din   = {tx_en, tx_data};

assign led[7:0] = 8'b11111111;

endmodule
`default_nettype wire
