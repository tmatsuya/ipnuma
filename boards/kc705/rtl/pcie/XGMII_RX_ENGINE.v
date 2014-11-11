`ifdef SIMULATION
`include "../rtl/setup.v"
`else
`include "../setup.v"
`endif
module XGMII_RX_ENGINE (
	input sys_rst,
	// XGMII
        input xgmii_clk,
        input [7:0] xgmii_rxc,
        input [63:0] xgmii_rxd,
        // PCIe user registers
        input [31:0] if_v4addr,
        input [47:0] if_macaddr,
        input [31:0] dest_v4addr,
        input [47:0] dest_macaddr,
        // XGMII-RX FIFO
        output [71:0] din,
        input full,
        output wr_en
);

//-----------------------------------
// Recive logic
//-----------------------------------
reg [15:0] rx_count = 0;
reg [31:0] rx_magic;
reg [15:0] rx_type;         // frame type
reg [47:0] rx_src_mac;
reg [47:0] tx_dst_mac;
reg [7:0] rx_protocol;
reg [15:0] rx_dport;

always @(posedge xgmii_clk) begin
	if (sys_rst) begin
		rx_count <= 16'h0;
		rx_magic <= 32'b0;
		rx_type <= 16'h0;
		rx_src_mac <= 48'h0;
		tx_dst_mac <= 48'h0;
		rx_protocol <= 8'h0;
		rx_dport <= 16'h00;
	end else begin
		if (xgmii_rxc[7:0] != 8'hff) begin
			rx_count <= rx_count + 16'h8;
			case (rx_count)
			16'h00: ;
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
			end

			16'h38: begin
				if (rx_magic[31:0] == `MAGIC_CODE) begin
				end
			end
			endcase
		end else begin
			rx_count <= 16'h0;
		end
	end
end

endmodule
