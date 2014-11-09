module XGMII_TX_ENGINE (
	// FIFO
	input sys_rst,
	input [71:0] dout,
	input empty,
	output rd_en,
	// XGMII
	input	 xgmii_clk,
	output [71:0] xgmii_txd
);

//-----------------------------------
// logic
//-----------------------------------

reg [71:0] txd;

always @(posedge xgmii_clk) begin
	if (sys_rst) begin
		txd <= 72'hff_07_07_07_07_07_07_07_07;
	end else begin
		if (empty  == 1'b0) begin
			txd <= dout[71: 0];
		end else begin
			txd <= 72'hff_07_07_07_07_07_07_07_07;
		end
	end
end

assign rd_en = ~empty;
assign xgmii_txd = txd;

endmodule
