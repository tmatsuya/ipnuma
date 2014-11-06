`include "../rtl/setup.v"

module measure_core # ( parameter
	Int_ipv4_addr = {8'd10, 8'd0, 8'd21, 8'd105},
	Int_ipv6_addr = 128'h3776_0000_0000_0021_0000_0000_0000_0105,
	Int_mac_addr = 48'h003776_000101
) (
	input sys_rst,
	input sys_clk,
	input pci_clk,
	input sec_oneshot,
	input [31:0] global_counter,

	// XGMII interfaces for 4 MACs
	output [63:0] xgmii_txd,
	output [7:0] xgmii_txc,
	input [63:0] xgmii_rxd,
	input [7:0] xgmii_rxc,

	// PCI user registers
	output reg [31:0] rx_pps,
	output reg [31:0] rx_throughput,
	output reg [23:0] rx_latency,
	output reg [31:0] rx_ipv4_ip,

	// mode
	input tx_ipv6
);

reg [31:0] rx_pps1, rx_pps2;
reg [31:0] rx_throughput1, rx_throughput2;
reg [23:0] rx_latency1, rx_latency2;

always @(posedge pci_clk) begin
	rx_pps2 <= rx_pps1;
	rx_throughput2 <= rx_throughput1;
	rx_latency2 <= rx_latency1;
	rx_pps <= rx_pps2;
	rx_throughput <= rx_throughput2;
	rx_latency <= rx_latency2;
end


//-----------------------------------
// Recive logic
//-----------------------------------
reg [15:0] rx_count = 0;
reg [31:0] rx_magic;
reg [31:0] counter_start;
reg [31:0] counter_end;
reg [31:0] pps;
reg [31:0] throughput;
reg [15:0] rx_type;         // frame type
reg [47:0] rx_src_mac;
reg [47:0] tx_dst_mac;
reg [7:0] rx_protocol;
reg [15:0] rx_dport;

always @(posedge sys_clk) begin
	if (sys_rst) begin
		rx_count <= 16'h0;
		rx_magic <= 32'b0;
		counter_start <= 32'h0;
		counter_end <= 32'h0;
		pps <= 32'h0;
		throughput <= 32'h0;
		rx_pps1 <= 32'h0;
		rx_throughput1 <= 32'h0;
		rx_type <= 16'h0;
		rx_src_mac <= 48'h0;
		tx_dst_mac <= 48'h0;
		rx_protocol <= 8'h0;
		rx_dport <= 16'h00;
	end else begin
		if (sec_oneshot == 1'b1) begin
			rx_pps1 <= pps;
			rx_throughput1 <= throughput;
			pps <= 32'h0;
			throughput <= 32'h0;
		end

		if (xgmii_rxc[7:0] != 8'hff) begin
			rx_count <= rx_count + 16'h8;
			case (rx_count)
			16'h00: if (sec_oneshot == 1'b0)
				pps <= pps + 32'h1;
			16'h08: begin
				rx_src_mac[47:40] <= xgmii_rxd[ 7: 0];// Ethernet hdr: Source MAC
				rx_src_mac[39:32] <= xgmii_rxd[15: 8];
				rx_src_mac[31:24] <= xgmii_rxd[23:16];
				rx_src_mac[23:16] <= xgmii_rxd[31:24];
				rx_src_mac[15: 8] <= xgmii_rxd[39:32];
				rx_src_mac[ 7: 0] <= xgmii_rxd[47:40];
			end
			16'h10: begin
				rx_type[15:8]     <= xgmii_rxd[39:32];
				rx_type[ 7:0]     <= xgmii_rxd[47:40];
			end
			16'h18: begin
				rx_protocol[7:0]  <= xgmii_rxd[63:56];
			end
			16'h28: begin
				rx_dport[15:8]    <= xgmii_rxd[39:32];
				rx_dport[ 7:0]    <= xgmii_rxd[47:40];
			end
			16'h30: begin
				rx_magic[31:24] <= xgmii_rxd[23:16];
				rx_magic[23:16] <= xgmii_rxd[31:24];
				rx_magic[15:8]  <= xgmii_rxd[39:32];
				rx_magic[7:0]   <= xgmii_rxd[47:40];
				counter_start[31:24] <= xgmii_rxd[55:48];
				counter_start[23:16] <= xgmii_rxd[63:56];
			end

			16'h38: begin
				counter_start[15:8]  <= xgmii_rxd[ 7: 0];
				counter_start[7:0]   <= xgmii_rxd[16: 8];
				if (rx_magic[31:0] == `MAGIC_CODE) begin
					rx_latency1 <= global_counter - counter_start;
				end
			end
			endcase
		end else begin
			if (rx_count != 16'h0 && sec_oneshot == 1'b0) begin
				throughput <= throughput + {16'h0, rx_count};
			end
			rx_count <= 16'h0;
		end
	end
end

assign xgmii_txd = 64'h07_07_07_07_07_07_07_07;
assign xgmii_txc = 8'hff;

endmodule
