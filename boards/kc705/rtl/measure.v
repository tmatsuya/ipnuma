`timescale 1ns / 1ps
`include "../rtl/setup.v"
//`define DEBUG

module measure (
	input	 sys_rst,
	input	 sys_clk,
	input	 pci_clk,

	// XGMII interfaces for 4 MACs
	output [63:0] xgmii_0_txd,
	output [7:0] xgmii_0_txc,
	input [63:0] xgmii_0_rxd,
	input [7:0] xgmii_0_rxc,

	output [63:0] xgmii_1_txd,
	output [7:0] xgmii_1_txc,
	input [63:0] xgmii_1_rxd,
	input [7:0] xgmii_1_rxc,


	// PCI user registers
	input tx0_enable,
	input tx0_ipv6,
	input tx0_fullroute,
	input tx0_req_arp,
	input [15:0] tx0_frame_len,
	input [31:0] tx0_inter_frame_gap,
	input [31:0] tx0_ipv4_srcip,
	input [47:0] tx0_src_mac,
	input [31:0] tx0_ipv4_gwip,
	input [127:0] tx0_ipv6_srcip,
	input [127:0] tx0_ipv6_dstip,
	output reg [47:0] tx0_dst_mac,
	input [31:0]  tx0_ipv4_dstip,
	output reg [31:0] tx0_pps,
	output reg [31:0] tx0_throughput,
	output [31:0] tx0_ipv4_ip,

	output [31:0] rx1_pps,
	output [31:0] rx1_throughput,
	output [23:0] rx1_latency,
	output [31:0] rx1_ipv4_ip,

	output [31:0] rx2_pps,
	output [31:0] rx2_throughput,
	output [23:0] rx2_latency,
	output [31:0] rx2_ipv4_ip,

	output [31:0] rx3_pps,
	output [31:0] rx3_throughput,
	output [23:0] rx3_latency,
	output [31:0] rx3_ipv4_ip,

	output reg [31:0] global_counter
);

//-----------------------------------
// One second clock
//-----------------------------------
reg sec_oneshot;
reg [27:0] sec_counter;
always @(posedge sys_clk) begin
	if (sys_rst) begin
		sec_counter <= 28'd156250000;
		sec_oneshot <= 1'b0;
	end else begin
		if (sec_counter == 27'd0) begin
			sec_counter <= 28'd156250000;
			sec_oneshot <= 1'b1;
		end else begin
			sec_counter <= sec_counter - 28'd1;
			sec_oneshot <= 1'b0;
		end
	end
end

//-----------------------------------
// Transmitte logic
//-----------------------------------
reg [31:0] tx_counter;
reg [63:0] txd, txd2;
reg [7:0] txc, txc2;

//-----------------------------------
// CRC logic
//-----------------------------------
reg crc_init = 1'b0;
reg crc_rewrite = 1'b0;
assign crc_data_en = ~crc_init;
wire [31:0] crc64_out, crc64_outrev;
wire [31:0] crc32_out, crc32_outrev;
assign crc64_outrev = ~{ crc64_out[24],crc64_out[25],crc64_out[26],crc64_out[27],crc64_out[28],crc64_out[29],crc64_out[30],crc64_out[31], crc64_out[16],crc64_out[17],crc64_out[18],crc64_out[19],crc64_out[20],crc64_out[21],crc64_out[22],crc64_out[23], crc64_out[ 8],crc64_out[ 9],crc64_out[10],crc64_out[11],crc64_out[12],crc64_out[13],crc64_out[14],crc64_out[15], crc64_out[ 0],crc64_out[ 1],crc64_out[ 2],crc64_out[ 3],crc64_out[ 4],crc64_out[ 5],crc64_out[ 6],crc64_out[ 7] };
assign crc32_outrev = ~{ crc32_out[24],crc32_out[25],crc32_out[26],crc32_out[27],crc32_out[28],crc32_out[29],crc32_out[30],crc32_out[31], crc32_out[16],crc32_out[17],crc32_out[18],crc32_out[19],crc32_out[20],crc32_out[21],crc32_out[22],crc32_out[23], crc32_out[ 8],crc32_out[ 9],crc32_out[10],crc32_out[11],crc32_out[12],crc32_out[13],crc32_out[14],crc32_out[15], crc32_out[ 0],crc32_out[ 1],crc32_out[ 2],crc32_out[ 3],crc32_out[ 4],crc32_out[ 5],crc32_out[ 6],crc32_out[ 7] };

crc32_d64 crc32_d64_inst (
	.rst(crc_init),
	.clk(sys_clk),
	.crc_en(crc_data_en),
	.data_in({
txd[00],txd[01],txd[02],txd[03],txd[04],txd[05],txd[06],txd[07],txd[08],txd[09],
txd[10],txd[11],txd[12],txd[13],txd[14],txd[15],txd[16],txd[17],txd[18],txd[19],
txd[20],txd[21],txd[22],txd[23],txd[24],txd[25],txd[26],txd[27],txd[28],txd[29],
txd[30],txd[31],txd[32],txd[33],txd[34],txd[35],txd[36],txd[37],txd[38],txd[39],
txd[40],txd[41],txd[42],txd[43],txd[44],txd[45],txd[46],txd[47],txd[48],txd[49],
txd[50],txd[51],txd[52],txd[53],txd[54],txd[55],txd[56],txd[57],txd[58],txd[59],
txd[60],txd[61],txd[62],txd[63]
}),	// 64bit
	.crc_out(crc64_out)	// 32bit
);

crc32_d32 crc32_d32_inst (
	.data_in({
txd[00],txd[01],txd[02],txd[03],txd[04],txd[05],txd[06],txd[07],txd[08],txd[09],
txd[10],txd[11],txd[12],txd[13],txd[14],txd[15],txd[16],txd[17],txd[18],txd[19],
txd[20],txd[21],txd[22],txd[23],txd[24],txd[25],txd[26],txd[27],txd[28],txd[29],
txd[30],txd[31]
}),
	.crc_in(crc64_out),
	.crc_out(crc32_out)
);

//-----------------------------------
// Global counter
//-----------------------------------
always @(posedge sys_clk) begin
	if (sys_rst) begin
		global_counter <= 32'h0;
	end else begin
		global_counter <= global_counter + 32'h1;
	end
end

//-----------------------------------
// scenario parameter
//-----------------------------------
wire [31:0] magic_code     = `MAGIC_CODE;
wire [31:0] tv_sec         = 32'd1406028803;	// time stamp
wire [31:0] tv_usec;

reg [16:0] ipv4_id	   = 16'h0;
reg [7:0]  ipv4_ttl	   = 8'h40;      // IPv4: default TTL value (default: 64)
reg [31:0] pps;
reg [31:0] throughput;
reg [23:0] full_ipv4;
reg [23:0] ip_sum;
reg [15:0] arp_wait_count;

wire [15:0] frame_crc1_count = tx0_frame_len + 16'h4;
wire [15:0] frame_crc2_count = tx0_frame_len + 16'h5;
wire [15:0] frame_crc3_count = tx0_frame_len + 16'h6;
wire [15:0] frame_crc4_count = tx0_frame_len + 16'h7;
wire [15:0] frame_end_count  = tx0_frame_len + 16'h8;

reg [2:0] tx_state;
reg [31:0] gap_count;
parameter TX_REQ_ARP     = 3'h0;  // Send ARP request
parameter TX_WAIT_ARPREP = 3'h1;  // Wait ARP reply
parameter TX_V4_SEND     = 3'h2;  // IPv4 Payload
parameter TX_V6_SEND     = 3'h3;  // IPv6 Payload
parameter TX_GAP	 = 3'h4;  // Inter Frame Gap

wire [31:0] ipv4_dstip = (tx0_fullroute == 1'b0) ? tx0_ipv4_dstip[31:0] : {full_ipv4[23:0],8'h1};  // IPv4: Destination Address
wire [15:0] tx0_udp_len = tx0_frame_len - 16'h26;  // UDP Length
wire [15:0] tx0_ip_len  = tx0_frame_len - 16'd18;  // IP Length (Frame Len - FCS Len - EtherFrame Len

reg [15:0] tmp_counter;

always @(posedge sys_clk) begin
	if ( sys_rst ) begin
		crc_init <= 1'b0;
		crc_rewrite <= 1'b0;
		tx_counter <= 32'h0;
		tmp_counter <= 16'h0;
		txd <= 64'h0707070707070707;
		txc <= 8'hff;
  		tx0_dst_mac <= 48'hffffffffffff;
		pps            <= 32'h0;
		throughput     <= 32'h0;
		tx0_pps        <= 32'h0;
		tx0_throughput <= 32'h0;
		full_ipv4 <= 24'h0;
		tx_state <= TX_V4_SEND;
	end else begin
		crc_rewrite <= 1'b0;
		txc2 <= txc;
		if (crc_rewrite == 1'b0)
			txd2 <= txd;
		else
			txd2 <= {crc32_outrev[7:0], crc32_outrev[15:8], crc32_outrev[23:16], crc32_outrev[31:24], txd[31:0]};
		if (sec_oneshot == 1'b1) begin
			tx0_pps        <= pps;
			tx0_throughput <= throughput;
			pps            <= 32'h0;
			throughput     <= 32'h0;
		end
		case (tx_state)
		TX_V4_SEND: begin
			tx_counter <= tx_counter + 32'h8;
			case (tx_counter[15:0] )
				16'h00: begin
					if (sec_oneshot == 1'b0)
						pps <= pps + 32'h1;
					{txc, txd} <= {8'h01, 64'hd5_55_55_55_55_55_55_fb};
					ip_sum <= 16'h4500 + {4'h0,tx0_ip_len[11:0]} + ipv4_id[15:0] + {ipv4_ttl[7:0],8'h11} + tx0_ipv4_srcip[31:16] + tx0_ipv4_srcip[15:0] + ipv4_dstip[31:16] + ipv4_dstip[15:0];
					crc_init <= 1'b1;
				end
				16'h08: begin
					{txc, txd} <= {8'h00, tx0_src_mac[39:32], tx0_src_mac[47:40], tx0_dst_mac[7:0], tx0_dst_mac[15:8], tx0_dst_mac[23:16], tx0_dst_mac[31:24], tx0_dst_mac[39:32], tx0_dst_mac[47:40]};
					ip_sum <= ~(ip_sum[15:0] + ip_sum[23:16]);
					crc_init <= 1'b0;
				end
				16'h10: {txc, txd} <= {8'h00, 32'h00_45_00_08, tx0_src_mac[7:0], tx0_src_mac[15:8], tx0_src_mac[23:16], tx0_src_mac[31:24]};
				16'h18: {txc, txd} <= {8'h00, 8'h11, ipv4_ttl[7:0], 16'h00, ipv4_id[7:0], ipv4_id[15:8], tx0_ip_len[7:0], 4'h0, tx0_ip_len[11:8]};
				16'h20: {txc, txd} <= {8'h00, ipv4_dstip[23:16], ipv4_dstip[31:24], tx0_ipv4_srcip[7:0], tx0_ipv4_srcip[15:8], tx0_ipv4_srcip[23:16], tx0_ipv4_srcip[31:24], ip_sum[7:0], ip_sum[15:8]};
				16'h28: {txc, txd} <= {8'h00, tx0_udp_len[7:0], 4'h0, tx0_udp_len[11:8], 32'h09_00_09_00, ipv4_dstip[7:0], ipv4_dstip[15:8]};
				16'h30: begin
					{txc, txd} <= {8'h00, global_counter[23:16], global_counter[31:24], magic_code[7:0], magic_code[15:8], magic_code[23:16], magic_code[31:24], 16'h00_00};
					tmp_counter[15:0] <= global_counter[15:0];
				end
				16'h38: {txc, txd} <= {8'h00, tv_usec[23:16], tv_usec[31:25], tv_sec[7:0],tv_sec[15:8], tv_sec[23:16], tv_sec[31:24], tmp_counter[7:0], tmp_counter[15:8]};
				16'h40: begin
					{txc, txd} <= {8'h00, 32'he5_e5_e5_e5, 16'h_00_00, tv_usec[7:0], tv_usec[15:8]};
					crc_rewrite <= 1'b1;
				end
				default: begin
					{txc, txd} <= {8'hff, 64'h07_07_07_07_07_07_07_fd};
					tx_counter <= 32'h0;
					if (tx0_inter_frame_gap == 32'd0) begin
						if (sec_oneshot == 1'b0)
							throughput <= throughput + {32'd64};
						full_ipv4 <= full_ipv4 + 24'h1;
						tx_state <= TX_V4_SEND;
					end else begin
						gap_count <= tx0_inter_frame_gap - 32'd1;
						tx_state <= TX_GAP;
					end
				end
			endcase
		end
		TX_GAP: begin
			{txc, txd} <= {8'hff, 64'h07_07_07_07_07_07_07_07};
			gap_count <= gap_count - 32'd1;
			if (gap_count == 32'd0) begin
				if (sec_oneshot == 1'b0)
					throughput <= throughput + {32'd64};
				full_ipv4 <= full_ipv4 + 24'h1;
				tx_state <= TX_V4_SEND;
			end
		end
		endcase
	end
end

assign tv_usec[31:0] = {16'h0000, tmp_counter[15:0]};

assign xgmii_0_txd = txd2;
assign xgmii_0_txc = txc2;

//-----------------------------------
// RX#1 Recive port logic
//-----------------------------------
measure_core # (
	.Int_ipv4_addr({8'd10, 8'd0, 8'd21, 8'd105}),
	.Int_ipv6_addr(128'h3776_0000_0000_0021_0000_0000_0000_0105),
	.Int_mac_addr(48'h003776_000101)
) measure_phy1 (
	.sys_rst(sys_rst),
	.sys_clk(sys_clk),
	.pci_clk(pci_clk),
	.sec_oneshot(sec_oneshot),
	.global_counter(global_counter),

	.xgmii_txd(xgmii_1_txd),
	.xgmii_txc(xgmii_1_txc),
	.xgmii_rxd(xgmii_1_rxd),
	.xgmii_rxc(xgmii_1_rxc),

	.rx_pps(rx1_pps),
	.rx_throughput(rx1_throughput),
	.rx_latency(rx1_latency),
	.rx_ipv4_ip(rx1_ipv4_ip),
	.tx_ipv6(tx_ipv6)
);

assign tx0_ipv4_ip  = ipv4_dstip;

`ifdef DEBUG
assign xgmii_1_txd = txd2;
assign xgmii_1_txc = txc2;
//`else
//assign xgmii_1_txd = 64'h07_07_07_07_07_07_07_07;
//assign xgmii_1_txc = 8'hff;
`endif

endmodule
