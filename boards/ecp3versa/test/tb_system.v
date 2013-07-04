`timescale 1ps / 1ps
`define SIMULATION
//`include "../rtl/setup.v"
module tb_system();

/* 125MHz system clock */
reg sys_clk;
initial sys_clk = 1'b0;
always #8 sys_clk = ~sys_clk;

// System
reg sys_rst;
// Management
reg [6:0] rx_bar_hit = 6'b000011;
reg [7:0] bus_num = 8'h12;
reg [4:0] dev_num = 5'h1;
reg [2:0] func_num = 3'h1;
// Receive
reg rx_st;
reg rx_end;
reg [15:0] rx_data;
// Transmit
wire tx_req;
reg tx_rdy=1'b1;
wire tx_st;
wire tx_end;
wire [15:0] tx_data;
// Receive credits
wire [7:0] pd_num;
wire ph_cr;
wire pd_cr;
wire nph_cr;
wire npd_cr;
// Master bus
reg  mst_req_o;
wire mst_rdy_i;
reg  [15:0] mst_dat_o;
wire mst_st_i;
wire mst_ce_i;
wire [15:0] mst_dat_i;
wire [1:0] mst_sel_i;
// Slave bus
wire slv_ce_i;
wire slv_we_i;
wire [31:2] slv_adr_i;
wire [15:0] slv_dat_i;
wire [1:0] slv_sel_i;
reg  [15:0] slv_dat_o;
// LED and Switches
reg [7:0] dipsw;
wire [7:0] led;
wire [13:0] segled;
reg btn;

pcie_tlp pcie_tlp_inst (
	.pcie_clk(sys_clk),
	.sys_rst(sys_rst),
	// Management
	.rx_bar_hit(rx_bar_hit),
	.bus_num(bus_num),
	.dev_num(dev_num),
	.func_num(func_num),
	// Receive
	.rx_st(rx_st),
	.rx_end(rx_end),
	.rx_data(rx_data),
	// Transmit
	.tx_req(tx_req),
	.tx_rdy(tx_rdy),
	.tx_st(tx_st),
	.tx_end(tx_end),
	.tx_data(tx_data),
	// Receive credits
	.pd_num(),
	.ph_cr(),
	.pd_cr(),
	.nph_cr(),
	.npd_cr(),
	// Master bus
	.mst_req_o(mst_req_o),
	.mst_rdy_i(mst_rdy_i),
	.mst_dat_o(mst_dat_o),
	.mst_st_i(mst_st_i),
	.mst_ce_i(mst_ce_i),
	.mst_dat_i(mst_dat_i),
	.mst_sel_i(mst_sel_i),
	// Slave bus
	.slv_ce_i(),
	.slv_we_i(),
	.slv_adr_i(),
	.slv_dat_i(),
	.slv_sel_i(),
	.slv_dat_o(),
	// LED and Switches
	.dipsw(),
	.led(),
	.segled(),
	.btn()
);

task waitclock;
begin
	@(posedge sys_clk);
	#1;
end
endtask

/*
always @(posedge Wclk) begin
	if (WriteEn_in == 1'b1)
		$display("Data_in: %x", Data_in);
end
*/

reg [23:0] rom [0:4095];
reg [11:0] counter;

always @(posedge sys_clk) begin
	rx_st   <= rom[ counter ][20];
	rx_end  <= rom[ counter ][16];
	rx_data <= rom[ counter ][15:0];
	counter <= counter + 1;
end

initial begin
        $dumpfile("./test.vcd");
	$dumpvars(0, tb_system); 
	$readmemh("./tlp_data.hex", rom);
	/* Reset / Initialize our logic */
	sys_rst = 1'b1;
	counter = 0;
	mst_req_o = 1'b0;

	waitclock;
	waitclock;

	sys_rst = 1'b0;

	waitclock;

	#(500*16) mst_req_o = 1'b1;

	#(8*2) mst_req_o = 1'b0;

	#30000;

	$finish;
end

endmodule
