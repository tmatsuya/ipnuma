`default_nettype none
`timescale 1ps/1ps
`ifdef SIMULATION
`include "../rtl/setup.v"
`else
`include "../setup.v"
`endif
// FIFO DOUT b63-00: data
//           b64:    start TLP
//           b65:    last TLP
//           b66:    b31-b0 enable
//           b67:    b63-b32 enable
//           b68:    IFG
module XGMII_TX_ENGINE (
	// FIFO
	input wire sys_rst,
	output reg req_gap = 1'b0,
	input wire [71:0] dout,
	input wire empty,
	output reg rd_en = 1'b0,
	// XGMII
	input wire xgmii_clk,
	output wire [71:0] xgmii_txd,
	// PCIe user registers
	input wire [31:0] if_v4addr,
	input wire [47:0] if_macaddr,
	input wire [31:0] dest_v4addr,
	input wire [47:0] dest_macaddr
);

//-----------------------------------
// logic
//-----------------------------------

parameter FIFO_IDLE   = 2'b00;
parameter FIFO_WAIT   = 2'b01;
parameter FIFO_DATA   = 2'b10;
parameter FIFO_FIN    = 2'b11;
reg [1:0] fifo_state = FIFO_IDLE;

always @(posedge xgmii_clk) begin
	if (sys_rst) begin
		req_gap<= 1'b0;
		rd_en <= 1'b0;
		fifo_state <= FIFO_IDLE;
	end else begin
		case (fifo_state)
			FIFO_IDLE: begin
				rd_en <= ~empty;
				if (rd_en) begin
					if (dout[64]) begin	// find next TLP bit
						rd_en <= 1'b0;
						fifo_state <= FIFO_WAIT;
					end
				end
			end
			FIFO_WAIT: begin
				if (tx_counter[15:0] == 16'h28) begin
					fifo_state <= FIFO_DATA;
				end
			end
			FIFO_DATA: begin
				rd_en <= ~empty;
				if (~rd_en) begin
					if (dout[65]) begin	// find last TLP bit
						rd_en <= 1'b0;
						fifo_state <= FIFO_FIN;
					end
				end
			end
			FIFO_FIN: begin
				fifo_state <= FIFO_IDLE;
			end
		endcase
	end
end



//-----------------------------------
// Transmitte logic
//-----------------------------------
reg [31:0] tx_counter = 32'h0000;
reg [63:0] txd, txd2;
reg [7:0] txc, txc2;

//-----------------------------------
// CRC logic
//-----------------------------------
reg crc_init = 1'b0;
wire crc_data_en;
assign crc_data_en = ~crc_init;
wire [31:0] crc64_out, crc64_outrev;
assign crc64_outrev = ~{ crc64_out[24],crc64_out[25],crc64_out[26],crc64_out[27],crc64_out[28],crc64_out[29],crc64_out[30],crc64_out[31], crc64_out[16],crc64_out[17],crc64_out[18],crc64_out[19],crc64_out[20],crc64_out[21],crc64_out[22],crc64_out[23], crc64_out[ 8],crc64_out[ 9],crc64_out[10],crc64_out[11],crc64_out[12],crc64_out[13],crc64_out[14],crc64_out[15], crc64_out[ 0],crc64_out[ 1],crc64_out[ 2],crc64_out[ 3],crc64_out[ 4],crc64_out[ 5],crc64_out[ 6],crc64_out[ 7] };

crc32_d64 crc32_d64_inst (
	.rst(crc_init),
	.clk(~xgmii_clk),
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

//-----------------------------------
// scenario parameter
//-----------------------------------
wire [31:0] magic_code     = `MAGIC_CODE;

reg [16:0] ipv4_id	   = 16'h0;
reg [7:0]  ipv4_ttl	   = 8'h40;      // IPv4: default TTL value (default: 64)
reg [23:0] ip_sum;

reg [31:0] gap_count;
parameter TX_IDLE        = 2'b00;  // IDLE
parameter TX_V4_SEND     = 2'b01;  // IPv4 Payload
parameter TX_GAP	 = 2'b10;  // Inter Frame Gap
reg [1:0] tx_state = TX_IDLE;

wire [15:0] tx0_frame_len;
assign tx0_frame_len = 16'd68;
wire [15:0] tx0_inter_frame_gap;
assign tx0_inter_frame_gap = 16'd1;

wire [31:0] ipv4_dstip = dest_v4addr;
wire [15:0] tx0_udp_len = tx0_frame_len - 16'h26;  // UDP Length
wire [15:0] tx0_ip_len  = tx0_frame_len - 16'd18;  // IP Length (Frame Len - FCS Len - EtherFrame Len


always @(posedge xgmii_clk) begin
	if ( sys_rst ) begin
		crc_init <= 1'b0;
		tx_counter <= 32'h0;
		txd <= 64'h0707070707070707;
		txc <= 8'hff;
		tx_state <= TX_IDLE;
	end else begin
		case (tx_state)
		TX_IDLE: begin
			if (fifo_state == FIFO_WAIT) begin
				tx_counter <= 32'h0;
				tx_state <= TX_V4_SEND;
			end
		end
		TX_V4_SEND: begin
			tx_counter <= tx_counter + 32'h8;
			case (tx_counter[15:0] )
				16'h00: begin
					{txc, txd} <= {8'h01, 64'hd5_55_55_55_55_55_55_fb};
					ip_sum <= 16'h4500 + {4'h0,tx0_ip_len[11:0]} + ipv4_id[15:0] + {ipv4_ttl[7:0],8'h11} + if_v4addr[31:16] + if_v4addr[15:0] + ipv4_dstip[31:16] + ipv4_dstip[15:0];
					crc_init <= 1'b1;
					req_gap <= 1'b1;
				end
				16'h08: begin
					{txc, txd} <= {8'h00, if_macaddr[39:32], if_macaddr[47:40], dest_macaddr[7:0], dest_macaddr[15:8], dest_macaddr[23:16], dest_macaddr[31:24], dest_macaddr[39:32], dest_macaddr[47:40]};
					ip_sum <= ~(ip_sum[15:0] + ip_sum[23:16]);
					crc_init <= 1'b0;
					req_gap <= 1'b0;
				end
				16'h10: {txc, txd} <= {8'h00, 32'h00_45_00_08, if_macaddr[7:0], if_macaddr[15:8], if_macaddr[23:16], if_macaddr[31:24]};
				16'h18: {txc, txd} <= {8'h00, 8'h11, ipv4_ttl[7:0], 16'h00, ipv4_id[7:0], ipv4_id[15:8], tx0_ip_len[7:0], 4'h0, tx0_ip_len[11:8]};
				16'h20: {txc, txd} <= {8'h00, ipv4_dstip[23:16], ipv4_dstip[31:24], if_v4addr[7:0], if_v4addr[15:8], if_v4addr[23:16], if_v4addr[31:24], ip_sum[7:0], ip_sum[15:8]};
				16'h28: {txc, txd} <= {8'h00, tx0_udp_len[7:0], 4'h0, tx0_udp_len[11:8], 32'h5e_0d_5e_0d, ipv4_dstip[7:0], ipv4_dstip[15:8]};
				16'h30: {txc, txd} <= {8'h00, 16'h00, magic_code[7:0], magic_code[15:8], magic_code[23:16], magic_code[31:24], 16'h00_00};
//				16'h38: {txc, txd} <= {~dout[71:64], dout[63:0]}; //{8'h00, 64'h07_06_05_04_03_02_01_00};
				16'h38: {txc, txd} <= {8'h00, 64'h07_06_05_04_03_02_01_00};
//				16'h40: begin
				16'h40: begin
					{txc, txd} <= {8'h00, 64'h0f_0e_0d_0c_0b_0a_09_08};
				end
				default: begin
					{txc, txd} <= {8'hf0, 32'h07_07_07_fd, crc64_outrev[7:0], crc64_outrev[15:8], crc64_outrev[23:16], crc64_outrev[31:24]};
					tx_counter <= 32'h0;
					if (tx0_inter_frame_gap == 32'd0) begin
						tx_state <= TX_IDLE;
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
				tx_state <= TX_IDLE;
			end
		end
		endcase
	end
end

assign xgmii_txd = {txc, txd};

endmodule // XGMII_TX_ENGINE
`default_nettype wire
