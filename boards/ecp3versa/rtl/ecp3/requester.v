`default_nettype none
module requester (
	// System
	input pcie_clk,
	input sys_rst,
	// Phy FIFO
	output [8:0]  phy_din,
	input phy_full,
	output reg  phy_wr_en,
	input [8:0] phy_dout,
	input phy_empty,
	output reg phy_rd_en,
	// Slave FIFO
	output reg [17:0] slv_din,
	input slv_full,
	output reg  slv_wr_en,
	input [17:0] slv_dout,
	input slv_empty,
	output reg slv_rd_en,
	// LED and Switches
	input [7:0] dipsw,
	output [7:0] led,
	output [13:0] segled,
	input btn
);


//-----------------------------------
// Transmitte logic
//-----------------------------------
reg [10:0] tx_count = 16'h0;
reg [7:0] tx_data;
reg tx_en = 1'b0;

//-----------------------------------
// CRC
//-----------------------------------
wire crc_init, crc_data_en;
assign crc_init = (tx_count ==  11'h08);
wire [31:0] crc_out;
reg crc_rd;
assign crc_data_en = ~crc_rd;
crc_gen crc_inst (
  .Reset(sys_rst),
  .Clk(pcie_clk),
  .Init(crc_init),
  .Frame_data(tx_data),
  .Data_en(crc_data_en),
  .CRC_rd(crc_rd),
  .CRC_end(),
  .CRC_out(crc_out)
); 


//-----------------------------------
// scenario parameter
//-----------------------------------
parameter [2:0]
	REQ_IDLE     = 3'h0,
	REQ_V4_SEND  = 3'h1,
	REQ_FCS1     = 3'h2,
	REQ_FCS2     = 3'h3,
	REQ_FCS3     = 3'h4,
	REQ_FCS4     = 3'h5,
	REQ_FIN      = 3'h6,
	REQ_GAP      = 3'h7;
reg [2:0] req_status = REQ_IDLE;
	
wire [31:0] magic_code       = 32'ha1110000;
wire [15:0] ipv4_id           = 16'h1;
wire [7:0]  ipv4_ttl          = 8'h40;      // IPv4: default TTL value (default: 64)
wire [31:0] tx_ipv4_srcip     = {8'd10, 8'd0, 8'd21, 8'd101};
wire [47:0] tx_src_mac        = 48'h003776_000001;
wire [47:0] tx_dst_mac        = 48'hffffff_ffffff;
wire [31:0] ipv4_dstip = {8'd10, 8'd0, 8'd21, 8'd254};  // IPv4: Destination Address
wire [15:0] tx_frame_len = 16'd128;
wire [15:0] tx_udp_len = tx_frame_len - 16'h26;  // UDP Length
wire [15:0] tx_ip_len  = tx_frame_len - 16'd18;  // IP Length (Frame Len - FCS Len - EtherFrame Len)

reg [31:0] gap_count;
reg [23:0] ip_sum;

always @(posedge pcie_clk) begin
	if (sys_rst) begin
		tx_count       <= 11'h0;
		tx_en          <= 1'b0;
		crc_rd         <= 1'b0;
		req_status       <= REQ_IDLE;
		gap_count      <= 32'h0;
		phy_wr_en <= 1'b0;
	end else begin
		case (req_status)
		REQ_IDLE: begin
			tx_count  <= 11'h0;
			phy_wr_en <= 1'b0;
//			if ( slv_empty == 1'b0 )
				req_status <= REQ_V4_SEND;
		end
		REQ_V4_SEND: begin
			phy_wr_en <= 1'b1;
			case (tx_count)
			11'h00: begin
				tx_data <= tx_dst_mac[47:40];     // Destination MAC
				ip_sum <= 16'h4500 + {4'h0,tx_ip_len[11:0]} + ipv4_id[15:0] + {ipv4_ttl[7:0],8'h11} + tx_ipv4_srcip[31:16] + tx_ipv4_srcip[15:0] + ipv4_dstip[31:16] + ipv4_dstip[15:0];
				tx_en <= 1'b1;
			end
			11'h01: begin
				tx_data <= tx_dst_mac[39:32];
				ip_sum <= ~(ip_sum[15:0] + ip_sum[23:16]);
			end
			11'h02: tx_data <= tx_dst_mac[31:24];
			11'h03: tx_data <= tx_dst_mac[23:16];
			11'h04: tx_data <= tx_dst_mac[15:8];
			11'h05: tx_data <= tx_dst_mac[7:0];
			11'h06: tx_data <= tx_src_mac[47:40];     // Source MAC
			11'h07: tx_data <= tx_src_mac[39:32];
			11'h08: tx_data <= tx_src_mac[31:24];
			11'h09: tx_data <= tx_src_mac[23:16];
			11'h0a: tx_data <= tx_src_mac[15:8];
			11'h0b: tx_data <= tx_src_mac[7:0];
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
			11'h1a: tx_data <= tx_ipv4_srcip[31:24];  // IPv4: Source Address
			11'h1b: tx_data <= tx_ipv4_srcip[23:16];
			11'h1c: tx_data <= tx_ipv4_srcip[15:8];
			11'h1d: tx_data <= tx_ipv4_srcip[7:0];
			11'h1e: tx_data <= ipv4_dstip[31:24];      // IPv4: Destination Address
			11'h1f: tx_data <= ipv4_dstip[23:16];
			11'h20: tx_data <= ipv4_dstip[15:8];
			11'h21: tx_data <= ipv4_dstip[7:0];
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
			11'h2e: tx_data <= 8'h81;         // Data
			11'h2f: tx_data <= 8'hff;
			11'h30: tx_data <= 8'hd0;
			11'h31: tx_data <= 8'h00;
			11'h32: tx_data <= 8'h00;
			11'h33: tx_data <= 8'h00;
			11'h34: tx_data <= 8'ha1;
			11'h35: tx_data <= 8'ha2;
			11'h36: tx_data <= 8'ha3;
			11'h37: tx_data <= 8'ha4;
			default: begin
				tx_data <= 8'h00;
				req_status <= REQ_FCS1;
			end
			endcase
			tx_count <= tx_count + 11'h1;
		end
		REQ_FCS1: begin
			crc_rd  <= 1'b1;
			tx_data <= crc_out[31:24];
			req_status <= REQ_FCS2;
		end
		REQ_FCS2: begin
			tx_data <= crc_out[23:16];
			req_status <= REQ_FCS3;
		end
		REQ_FCS3: begin
			tx_data <= crc_out[15: 8];
			req_status <= REQ_FCS4;
		end
		REQ_FCS4: begin
			tx_data <= crc_out[ 7: 0];
			req_status <= REQ_FIN;
		end
		REQ_FIN: begin
			phy_wr_en <= 1'b0;
			tx_en   <= 1'b0;
			crc_rd  <= 1'b0;
			tx_data <= 8'h0;
			gap_count<= 32'd1000;   // Inter Frame Gap = 14 (offset value -2)
			req_status <= REQ_GAP;
		end
		REQ_GAP: begin
			gap_count <= gap_count - 32'h1;
			if (gap_count == 32'h0) begin
				req_status <= REQ_IDLE;
			end
		end
		endcase
	end
end

assign phy_din   = {tx_en, tx_data};

assign led[7:0] = 8'b11111111;

endmodule
`default_nettype wire
