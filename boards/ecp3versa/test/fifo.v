`default_nettype none
module fifo (
	input [17:0] Data,
	input Clock,
	input WrEn,
	input RdEn,
	input Reset,
	output [17:0] Q,
	output Empty,
	output Full
);

sfifo # (
	.DATA_WIDTH(18),
	.ADDR_WIDTH(10)
) sfifo_inst (
	.clk(Clock) , // Clock input
	.rst(1'b0)  , // Active high reset
	.wr_cs(WrEn), // Write chip select
	.rd_cs(RdEn), // Read chipe select
	.din(Data)  , // Data input
	.rd_en(RdEn), // Read enable
	.wr_en(WrEn), // Write Enable
	.dout(Q)    , // Data Output
	.empty(Empty),// FIFO empty
	.full(Full) , // FIFO full
	.data_count() // DATA count
);

endmodule
`default_nettype wire
