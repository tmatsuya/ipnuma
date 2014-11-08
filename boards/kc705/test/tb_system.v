`timescale 1ps / 1ps
`define SIMULATION
//`include "../rtl/setup.v"
module tb_system();

/* 125, 156.25 and 250MHz clock */
reg clk156, clk125, clk250;
initial begin
	clk125 = 0;
	clk156 = 0;
	clk250 = 0;
end
always #10 clk125 = ~clk125;
always #8  clk156 = ~clk156;
always #5  clk250 = ~clk250;
reg sys_rst;

// regs
reg user_clk;
reg user_reset;
reg user_lnk_up;

reg s_axis_tx_tready;
wire [63:0] s_axis_tx_tdata;
wire [7:0] s_axis_tx_tkeep;
wire s_axis_tx_tlast;
wire s_axis_tx_tvalid;
wire tx_src_dsc;

reg [63:0] m_axis_rx_tdata;
reg [7:0] m_axis_rx_tkeep;
reg m_axis_rx_tlast;
reg m_axis_rx_tvalid;
wire m_axis_rx_tready;
reg [21:0]  m_axis_rx_tuser;

reg cfg_to_turnoff;
wire cfg_turnoff_ok;

reg[15:0] cfg_completer_id;

// PCIe user registers
wire [31:0] if_v4addr;
wire [47:0] if_macaddr;
wire [31:0] dest_v4addr;
wire [47:0] dest_macaddr;

// XGMII
reg xgmii_clk;
wire [63:0] xgmii_0_txd;
wire [ 7:0] xgmii_0_txc;
reg [63:0] xgmii_0_rxd;
reg [ 7:0] xgmii_0_rxc;

// LED and Switches
reg [7:0] dipsw;
wire [7:0] led;
wire [13:0] segled;
reg btn;

PIO PIO_insta (
	.user_clk(user_clk),
	.user_reset(user_reset),
	.user_lnk_up(user_lnk_up),

	// AXIS
	.s_axis_tx_tready(s_axis_tx_tready),
	.s_axis_tx_tdata(s_axis_tx_tdata),
	.s_axis_tx_tkeep(s_axis_tx_tkeep),
	.s_axis_tx_tlast(s_axis_tx_tlast),
	.s_axis_tx_tvalid(s_axis_tx_tvalid),
	.tx_src_dsc(tx_src_dsc),

	.m_axis_rx_tdata(m_axis_rx_tdata),
	.m_axis_rx_tkeep(m_axis_rx_tkeep),
	.m_axis_rx_tlast(m_axis_rx_tlast),
	.m_axis_rx_tvalid(m_axis_rx_tvalid),
	.m_axis_rx_tready(m_axis_rx_tready),
	.m_axis_rx_tuser(m_axis_rx_tuser),

	.cfg_to_turnoff(cfg_to_turnoff),
	.cfg_turnoff_ok(cfg_turnoff_ok),

	.cfg_completer_id(cfg_completer_id),

	// PCIe user registers
	.if_v4addr(if_v4addr),
	.if_macaddr(if_macaddr),
	.dest_v4addr(dest_v4addr),
	.dest_macaddr(dest_macaddr),

	// XGMII
	.xgmii_clk(xgmii_clk),
	.xgmii_0_txd(xgmii_0_txd),
	.xgmii_0_txc(xgmii_0_txc),
	.xgmii_0_rxd(xgmii_0_rxd),
	.xgmii_0_rxc(xgmii_0_rxc)
);

task waitclock;
begin
	@(posedge clk250);
	#1;
end
endtask

always @(posedge clk156) begin
	if (xgmii_0_txc != 8'hff)
		$display("%x", xgmii_0_txd);
end

reg [23:0] tlp_rom [0:4095];
reg [11:0] phy_rom [0:4095];
reg [11:0] tlp_counter, phy_counter;
wire [23:0] tlp_cur;
wire [23:0] phy_cur;
assign tlp_cur = tlp_rom[ tlp_counter ];
assign phy_cur = phy_rom[ phy_counter ];

always @(posedge clk250) begin
//	rx_st   <= tlp_cur[20];
//	rx_end  <= tlp_cur[16];
//	rx_data <= tlp_cur[15:0];
//	tlp_counter <= tlp_counter + 1;
end

always @(posedge clk156) begin
//	gmii_rx_dv  <= phy_cur[8];
//	gmii_rxd <= phy_cur[7:0];
//	phy_counter <= phy_counter + 1;
end

initial begin
        $dumpfile("./test.vcd");
	$dumpvars(0, tb_system); 
	$readmemh("./tlp_data.hex", tlp_rom);
	$readmemh("./phy_data.hex", phy_rom);
	/* Reset / Initialize our logic */
	sys_rst = 1'b1;

	waitclock;
	waitclock;

	sys_rst = 1'b0;

	waitclock;

//	#(500*16) mst_req_o = 1'b1;

//	#(8*2) mst_req_o = 1'b0;

	#4000;

	$finish;
end

endmodule