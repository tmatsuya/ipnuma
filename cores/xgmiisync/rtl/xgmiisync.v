module xgmiisync # (
	parameter Gap = 4'h0
) (
	input         sys_rst,
	input         xgmii_rx_clk,
	input  [63:0] xgmii_rxd_i,
	input  [ 7:0] xgmii_rxc_i,
	output reg [63:0] xgmii_rxd_o,
	output reg [ 7:0] xgmii_rxc_o
);

`ifdef NO
//-----------------------------------
// logic
//-----------------------------------
reg [63:0] rxd = 64'h00;
reg [7:0] rxc = 8'h00;
reg start = 1'b0;
reg quad_shift = 1'b0;
always @(posedge xgmii_rx_clk) begin
	if (sys_rst) begin
		rxd <= 64'h00;
		rxc <= 8'h00;
		xgmii_rxd_o <= 32'h00;
		xgmii_rxc_o <= 8'h00;
		start <= 1'b0;
		quad_shift <= 1'b0;
	end else begin
		rxc <= xgmii_rxc;
		rxd <= xgmii_rxd;
		if (xgmii_rxc[4] == 1'b1 && xgmii_rxd[39:32] == 8'hfb) begin
			quadshift <= 1'b1;
		end else if (xgmii_rxc[0] == 1'b1 && xgmii_rxd[7:0] == 8'hfb) begin
			quadshift <= 1'b0;
		end
		if (quadshift == 1'b0) begin
			xgmii_rxd_o <= rxd;
			xgmii_rxc_o <= rxc;
		end else begin
			xgmii_rxd_o <= {xgmii_rxd[31:0], rxd[63:32]};
			xgmii_rxc_o <= {xgmii_rxc[3:0], rxc[7:4]};
		end
	end
end
`endif

endmodule
