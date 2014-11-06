`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module PIO_EP_MEM_ACCESS  #(
	parameter TCQ = 1
) (

	input clk,
	input rst_n,

	// Read Access
	input  [10:0] rd_addr,     // I [10:0]  Read Address
	input   [3:0] rd_be,       // I [3:0]   Read Byte Enable
	output [31:0] rd_data,     // O [31:0]  Read Data

	// Write Access
	input  [10:0] wr_addr,     // I [10:0]  Write Address
	input   [7:0] wr_be,       // I [7:0]   Write Byte Enable
	input  [31:0] wr_data,     // I [31:0]  Write Data
	input	 wr_en,       // I	 Write Enable
	output	wr_busy,      // O	 Write Controller Busy

	// PCIe user registers
	output reg    tx0_enable,
	output reg    tx0_ipv6,
	output reg    tx0_fullroute,
	output reg    tx0_req_arp,
	output reg [15:0] tx0_frame_len,
	output reg [31:0] tx0_inter_frame_gap,
	output reg [31:0] tx0_ipv4_srcip,
	output reg [47:0] tx0_src_mac,
	output reg [31:0] tx0_ipv4_gwip,
	input      [47:0] tx0_dst_mac,
	output reg [31:0] tx0_ipv4_dstip,
	output reg [127:0] tx0_ipv6_srcip,
	output reg [127:0] tx0_ipv6_dstip,
	input [31:0]  tx0_pps,
	input [31:0]  tx0_throughput,
	input [31:0]  tx0_ipv4_ip,
	input [31:0]  rx1_pps,
	input [31:0]  rx1_throughput,
	input [23:0]  rx1_latency,
	input [31:0]  rx1_ipv4_ip,
	input [31:0]  rx2_pps,
	input [31:0]  rx2_throughput,
	input [23:0]  rx2_latency,
	input [31:0]  rx2_ipv4_ip,
	input [31:0]  rx3_pps,
	input [31:0]  rx3_throughput,
	input [23:0]  rx3_latency,
	input [31:0]  rx3_ipv4_ip

);

wire [31:0] bios_data;
biosrom biosrom_0 (
	.clk(clk),
//	.en(rd_addr[10:9] == 2'b11),
	.en(1'b1),
	.addr(rd_addr[8:0]),
	.data(bios_data)
);

reg [31:0] read_data;

always @(posedge clk) begin
	if (rst_n == 1'b0) begin
		// PCIe User Registers
		tx0_enable    <= 1'b1;
		tx0_ipv6      <= 1'b0;
		tx0_fullroute <= 1'b0;
		tx0_req_arp   <= 1'b0;
		tx0_frame_len <= 16'd64;
		tx0_inter_frame_gap <= (32'd12500000-32'd72)>>3;
//		tx0_inter_frame_gap <= 32'd1;
		tx0_src_mac   <= 48'h003776_000100;
		tx0_ipv4_gwip <= {8'd10,8'd0,8'd20,8'd1};
		tx0_ipv4_srcip<= {8'd10,8'd0,8'd20,8'd105};
		tx0_ipv4_dstip<= {8'd10,8'd0,8'd21,8'd105};
		tx0_ipv6_srcip<= 128'h3776_0000_0000_0020_0000_0000_0000_0105;
		tx0_ipv6_dstip<= 128'h3776_0000_0000_0021_0000_0000_0000_0105;
	end else begin
		case (rd_addr[5:0])
			6'h00: // tx enable bit
				read_data[31:0] <= {tx0_enable, tx0_ipv6, 5'b0, tx0_fullroute, 24'h0};
			6'h01: // tx0 frame length
				read_data[31:0] <= {16'h0, tx0_frame_len[15:0]};
			6'h02: // tx0 inter_frame_gap
				read_data[31:0] <= {tx0_inter_frame_gap[31:0]};
			6'h04: // tx0 ipv4_src_ip
				read_data[31:0] <= {tx0_ipv4_srcip[31:0]};
			6'h05: // tx0 src_mac 47-32bit
				read_data[31:0] <= {16'h00, tx0_src_mac[47:32]};
			6'h06: // tx0 src_mac 31-00bit
				read_data[31:0] <= {tx0_src_mac[31:0]};
			6'h08: // tx0 ipv4_gwip
				read_data[31:0] <= {tx0_ipv4_gwip[31:0]};
			6'h09: // tx0 dst_mac 47-32bit
				read_data[31:0] <= {16'h00, tx0_dst_mac[47:32]};
			6'h0a: // tx0 dst_mac 31-00bit
				read_data[31:0] <= {tx0_dst_mac[31:0]};
			6'h0b: // tx0 ipv4_dstip
				read_data[31:0] <= {tx0_ipv4_dstip[31:0]};
			6'h10: // tx0 pps
				read_data[31:0] <= {tx0_pps[31:0]};
			6'h11: // tx0 throughput
				read_data[31:0] <= {tx0_throughput[31:0]};
			6'h13: // tx0_ipv4_ip
				read_data[31:0] <= {tx0_ipv4_ip[31:0]};
			6'h14: // rx1 pps
				read_data[31:0] <= {rx1_pps[31:0]};
			6'h15: // rx1 throughput
				read_data[31:0] <= {rx1_throughput[31:0]};
			6'h16: // rx1_latency
				read_data[31:0] <= {8'h0, rx1_latency[23:0]};
			6'h17: // rx1_ipv4_ip
				read_data[31:0] <= {rx1_ipv4_ip[31:0]};
			6'h18: // rx2 pps
				read_data[31:0] <= {rx2_pps[31:0]};
			6'h19: // rx2 throughput
				read_data[31:0] <= {rx2_throughput[31:0]};
			6'h1a: // rx2_latency
				read_data[31:0] <= {8'h0, rx2_latency[23:0]};
			6'h1b: // rx2_ipv4_ip
				read_data[31:0] <= {rx2_ipv4_ip[31:0]};
			6'h1c: // rx3 pps
				read_data[31:0] <= {rx3_pps[31:0]};
			6'h1d: // rx3 throughput
				read_data[31:0] <= {rx3_throughput[31:0]};
			6'h1e: // rx3_latency
				read_data[31:0] <= {8'h0, rx3_latency[23:0]};
			6'h1f: // rx3_ipv4_ip
				read_data[31:0] <= {rx3_ipv4_ip[31:0]};
			6'h20: // tx0_ipv6_srcip
				read_data[31:0] <= {tx0_ipv6_srcip[127:96]};
			6'h21:  read_data[31:0] <= {tx0_ipv6_srcip[95:64]};
			6'h22:  read_data[31:0] <= {tx0_ipv6_srcip[63:32]};
			6'h23:  read_data[31:0] <= {tx0_ipv6_srcip[31: 0]};
			6'h24: // tx0_ipv6_dstip
				read_data[31:0] <= {tx0_ipv6_dstip[127:96]};
			6'h25:  read_data[31:0] <= {tx0_ipv6_dstip[95:64]};
			6'h26:  read_data[31:0] <= {tx0_ipv6_dstip[63:32]};
			6'h27:  read_data[31:0] <= {tx0_ipv6_dstip[31: 0]};
			default: read_data[31:0] <= 32'h0;
		endcase
		if (wr_en == 1'b1) begin
			case (wr_addr[5:0])
				6'h00: begin // tx enable bit
					if (wr_be[0]) begin
						tx0_enable <= wr_data[31];
						tx0_ipv6   <= wr_data[30];
						tx0_fullroute <= wr_data[24];
					end
				end
				6'h01: begin // tx0 frame length
					if (wr_be[2])
						tx0_frame_len[15:8] <= wr_data[15: 8];
					if (wr_be[3])
						tx0_frame_len[ 7:0] <= wr_data[ 7: 0];
				end
				6'h02: begin // tx0 ipv4_inter_frame_gap
					if (wr_be[0])
						tx0_inter_frame_gap[31:24] <= wr_data[31:24];
					if (wr_be[1])
						tx0_inter_frame_gap[23:16] <= wr_data[23:16];
					if (wr_be[2])
						tx0_inter_frame_gap[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						tx0_inter_frame_gap[ 7: 0] <= wr_data[7:0];
				end
				6'h03: begin // tx0 arp request command
					tx0_req_arp   <= 1'b1;
				end
				6'h04: begin // tx0 ipv4_src_ip
					if (wr_be[0])
						tx0_ipv4_srcip[31:24] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv4_srcip[23:16] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv4_srcip[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv4_srcip[ 7: 0] <= wr_data[7:0];
				end
				6'h05: begin // tx0 src_mac 47-32bit
					if (wr_be[2])
						tx0_src_mac[47:40] <= wr_data[15: 8];
					if (wr_be[3])
						tx0_src_mac[39:32] <= wr_data[ 7: 0];
				end
				6'h06: begin // tx0 src_mac 31-00bit
					if (wr_be[0])
						tx0_src_mac[31:24] <= wr_data[31:24];
					if (wr_be[1])
						tx0_src_mac[23:16] <= wr_data[23:16];
					if (wr_be[2])
						tx0_src_mac[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						tx0_src_mac[ 7: 0] <= wr_data[7:0];
				end
				6'h08: begin // tx0 ipv4_gwip
					if (wr_be[0])
						tx0_ipv4_gwip[31:24] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv4_gwip[23:16] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv4_gwip[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv4_gwip[ 7: 0] <= wr_data[7:0];
				end
				6'h0b: begin // tx0 ipv4_dstip
					if (wr_be[0])
						tx0_ipv4_dstip[31:24] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv4_dstip[23:16] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv4_dstip[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv4_dstip[ 7: 0] <= wr_data[7:0];
				end
				6'h20: begin // tx0_ipv6_srcip
					if (wr_be[0])
						tx0_ipv6_srcip[127:120] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv6_srcip[119:112] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv6_srcip[111:104] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv6_srcip[103: 96] <= wr_data[7:0];
				end
				6'h21: begin
					if (wr_be[0])
						tx0_ipv6_srcip[95:88] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv6_srcip[87:80] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv6_srcip[79:72] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv6_srcip[71:64] <= wr_data[7:0];
				end
				6'h22: begin
					if (wr_be[0])
						tx0_ipv6_srcip[63:56] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv6_srcip[55:48] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv6_srcip[47:40] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv6_srcip[39:32] <= wr_data[7:0];
				end
				6'h23: begin
					if (wr_be[0])
						tx0_ipv6_srcip[31:24] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv6_srcip[23:16] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv6_srcip[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv6_srcip[ 7: 0] <= wr_data[7:0];
				end
				6'h24: begin // tx0_ipv6_dstip
					if (wr_be[0])
						tx0_ipv6_dstip[127:120] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv6_dstip[119:112] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv6_dstip[111:104] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv6_dstip[103: 96] <= wr_data[7:0];
				end
				6'h25: begin
					if (wr_be[0])
						tx0_ipv6_dstip[95:88] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv6_dstip[87:80] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv6_dstip[79:72] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv6_dstip[71:64] <= wr_data[7:0];
				end
				6'h26: begin
					if (wr_be[0])
						tx0_ipv6_dstip[63:56] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv6_dstip[55:48] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv6_dstip[47:40] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv6_dstip[39:32] <= wr_data[7:0];
				end
				6'h27: begin
					if (wr_be[0])
						tx0_ipv6_dstip[31:24] <= wr_data[31:24];
					if (wr_be[1])
						tx0_ipv6_dstip[23:16] <= wr_data[23:16];
					if (wr_be[2])
						tx0_ipv6_dstip[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						tx0_ipv6_dstip[ 7: 0] <= wr_data[7:0];
				end
			endcase
		end
	end
end

//assign rd_data = read_data;
assign rd_data = rd_addr[10:9] == 2'b11 ? bios_data : read_data;
assign wr_busy = 1'b0;

endmodule
