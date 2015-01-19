`timescale 1ps/1ps
`include "../setup.v"

(* DowngradeIPIdentifiedWarnings = "yes" *)
module PIO_EP_MEM_ACCESS  #(
	parameter TCQ = 1
) (

	input clk,
	input sys_rst,

	// Read Access
	input  [13:0] rd_addr,     // I [13:0]  Read Address
	input   [3:0] rd_be,       // I [3:0]   Read Byte Enable
	output [31:0] rd_data,     // O [31:0]  Read Data

	// Write Access
	input  [13:0] wr_addr,     // I [10:0]  Write Address
	input   [7:0] wr_be,       // I [7:0]   Write Byte Enable
	input  [31:0] wr_data,     // I [31:0]  Write Data
	input	 wr_en,       // I	 Write Enable
	output	wr_busy,      // O	 Write Controller Busy

	// PCIe user registers
	output reg [31:0] if_v4addr = {8'd10, 8'd0, 8'd21, 8'd199},
	output reg [47:0] if_macaddr = 48'h003776_000001,
	output reg [31:0] dest_v4addr = {8'd10, 8'd0, 8'd21, 8'd255},
	output reg [47:0] dest_macaddr = 48'hffffff_ffffff,
	output reg [47:12] mem0_paddr = (48'hd000_0000>>12),

	input [7:0] debug
);

wire [31:0] bios_data;
biosrom biosrom_0 (
	.clk(clk),
//	.en(rd_addr[13:2] == 2'b11),
	.en(1'b1),
	.addr(rd_addr[11:0]),
	.data(bios_data)
);

reg [31:0] read_data;

always @(posedge clk) begin
	if (sys_rst) begin
		// PCIe User Registers
		if_v4addr <= {8'd10, 8'd0, 8'd21, 8'd199};
		if_macaddr <= 48'h003776_000001;
		dest_v4addr <= {8'd10, 8'd0, 8'd21, 8'd255};
		dest_macaddr <= 48'hffffff_ffffff;
		mem0_paddr <= (48'hd000_0000>>12);
	end else begin
		if (rd_addr[13:12] == 2'b01) begin // BAR0
		case (rd_addr[5:0])
			6'h00: // if ipv4_addr
				read_data[31:0] <= {if_v4addr[31:0]};
			6'h02: // if mac 47-16bit
				read_data[31:0] <= {if_macaddr[47:16]};
			6'h03: // if mac 15-00bit
				read_data[31:0] <= {if_macaddr[15:0],8'h00,debug[7:0]};
			6'h04: // dest ipv4_addr
				read_data[31:0] <= {dest_v4addr[31:0]};
			6'h06: // dest dst_mac 47-16bit
				read_data[31:0] <= {dest_macaddr[47:16]};
			6'h07: // dest dst_mac 15-00bit
				read_data[31:0] <= {dest_macaddr[15:0],16'h00};
			6'h0A: // mem0 remote physical address
				read_data[31:0] <= {8'h00, mem0_paddr[15:12],4'b0, mem0_paddr[23:16], mem0_paddr[31:24]};
			6'h0B: // 
				read_data[31:0] <= {mem0_paddr[39:32], mem0_paddr[47:40], 16'h00};
			default: read_data[31:0] <= 32'h0;
		endcase
		end
		if (wr_addr[13:12] == 2'b01 && wr_en == 1'b1) begin // BAR0
			case (wr_addr[5:0])
				6'h00: begin // if ipv4_addr
					if (wr_be[0])
						if_v4addr[31:24] <= wr_data[31:24];
					if (wr_be[1])
						if_v4addr[23:16] <= wr_data[23:16];
					if (wr_be[2])
						if_v4addr[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						if_v4addr[ 7: 0] <= wr_data[7:0];
				end
				6'h02: begin // if mac 47-16bit
					if (wr_be[0])
						if_macaddr[47:40] <= wr_data[31:24];
					if (wr_be[1])
						if_macaddr[39:32] <= wr_data[23:16];
					if (wr_be[2])
						if_macaddr[31:23] <= wr_data[15: 8];
					if (wr_be[3])
						if_macaddr[23:16] <= wr_data[ 7: 0];
				end
				6'h03: begin // if mac 15-00bit
					if (wr_be[0])
						if_macaddr[15: 8] <= wr_data[31:24];
					if (wr_be[1])
						if_macaddr[ 7: 0] <= wr_data[23:16];
				end
				6'h04: begin // dest ipv4_addr
					if (wr_be[0])
						dest_v4addr[31:24] <= wr_data[31:24];
					if (wr_be[1])
						dest_v4addr[23:16] <= wr_data[23:16];
					if (wr_be[2])
						dest_v4addr[15: 8] <= wr_data[15:8];
					if (wr_be[3])
						dest_v4addr[ 7: 0] <= wr_data[7:0];
				end
				6'h06: begin // dest mac 47-16bit
					if (wr_be[0])
						dest_macaddr[47:40] <= wr_data[31:24];
					if (wr_be[1])
						dest_macaddr[39:32] <= wr_data[23:16];
					if (wr_be[2])
						dest_macaddr[31:24] <= wr_data[15:8];
					if (wr_be[3])
						dest_macaddr[23:16] <= wr_data[7:0];
				end
				6'h07: begin // dest mac 15-00bit
					if (wr_be[0])
						dest_macaddr[15: 8] <= wr_data[31:24];
					if (wr_be[1])
						dest_macaddr[ 7: 0] <= wr_data[23:16];
				end
				6'h0A: begin // mem0 remote physical address
					if (wr_be[1])
						mem0_paddr[15:12] <= wr_data[23:20];
					if (wr_be[2])
						mem0_paddr[23:16] <= wr_data[15:8];
					if (wr_be[3])
						mem0_paddr[31:24] <= wr_data[7:0];
				end
				6'h0b: begin
					if (wr_be[0])
						mem0_paddr[39:32] <= wr_data[31:24];
					if (wr_be[1])
						mem0_paddr[47:40] <= wr_data[23:16];
				end
			endcase
		end
	end
end

//assign rd_data = read_data;
function [31:0] dec_data;
	input [1:0] sel;
	input [31:0] bar0;
	input [31:0] bar2;
	input [31:0] bios;
	case (sel)
		2'b00: dec_data = 32'h0;
		2'b01: dec_data = bar0;
		2'b10: dec_data = bar2;
		2'b11: dec_data = bios;
	endcase
endfunction
//assign rd_data = rd_addr[13:12] == 2'b11 ? bios_data : read_data;
`ifdef PCIE_X8
assign rd_data = dec_data(rd_addr[13:12], read_data, 32'h0, 32'h00);
`else
assign rd_data = dec_data(rd_addr[13:12], read_data, 32'h0, bios_data);
`endif
assign wr_busy = 1'b0;

endmodule
