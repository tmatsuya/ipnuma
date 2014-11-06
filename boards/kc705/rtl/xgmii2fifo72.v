module xgmii2fifo72 # (
	parameter Gap = 4'h0
) (
	input         sys_rst,
	input         xgmii_rx_clk,
	input  [71:0] xgmii_rxd,
	output [71:0] din
);


//-----------------------------------
// logic
//-----------------------------------
reg [71:0] rxd = 72'h00;
reg [35:0] rxd2 = 36'h00;
reg [3:0] gap_count = 4'h0;
reg start = 1'b0;
reg quad_shift = 1'b0;
always @(posedge xgmii_rx_clk) begin
	if (sys_rst) begin
		rxd <= 72'h00;
		rxd2 <= 36'h00;
		gap_count <= 4'h0;
		start <= 1'b0;
		quad_shift <= 1'b0;
	end else begin
		if (xgmii_rxd[71:64] != 8'hff || xgmii_rxd[7:0] != 8'h07) begin
			if (start == 1'b1) begin
				if (xgmii_rxd[68] == 1'b0) begin
					quad_shift <= 1'b0;
					rxd[71:0] <= xgmii_rxd[71:0];
				end else begin
					rxd2[35:0] <= {xgmii_rxd[71:68],xgmii_rxd[63:32]};
					quad_shift <= 1'b1;
				end
			end else begin
				if (quad_shift == 1'b0) begin
					rxd[71:0] <= xgmii_rxd[71:0];
				end else begin
					rxd[71:0] <= {xgmii_rxd[67:64], rxd2[35:32], xgmii_rxd[31:0], rxd2[31:0]};
					rxd2[35:0] <= {xgmii_rxd[71:68],xgmii_rxd[63:32]};
				end
			end
			gap_count <= Gap;
			start <= 1'b0;
		end else begin
			start <= 1'b1;
			if (gap_count != 4'h0) begin
				if (quad_shift == 1'b1)
					rxd[71:0] <= {4'hf, rxd2[35:32], 32'h07_07_07_07, rxd2[31:0]};
				else begin
					rxd[71:0] <= 72'hff_07_07_07_07_07_07_07_07;
					gap_count <= gap_count - 4'h1;
				end
				quad_shift <= 1'b0;
			end
		end
	end
end

assign din[71:0] = rxd[71:0];

endmodule
