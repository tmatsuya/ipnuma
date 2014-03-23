`default_nettype none
`include "setup.v"

module ipnuma (
	// System
	input pcie_clk,
	input sys_rst,
	// Management
	input [6:0] rx_bar_hit,
	input [7:0] bus_num,
	input [4:0] dev_num,
	input [2:0] func_num,
	// Receive
	input rx_st,
	input rx_end,
	input [15:0] rx_data,
	// Transmit
	output tx_req,
	input tx_rdy,
	output tx_st,
	output tx_end,
	output [15:0] tx_data,
	// Receive credits
	output [7:0] pd_num,
	output ph_cr,
	output pd_cr,
	output nph_cr,
	output npd_cr,
	// Phy
	input gmii_tx_clk,
	output [7:0] gmii_txd,
	output gmii_tx_en,
	input [7:0] gmii_rxd,
	input gmii_rx_dv,
	input gmii_rx_clk,
	// LED and Switches
	input [7:0] dipsw,
	output [7:0] led,
	output [13:0] segled,
	input btn
);

// FIFO
wire [17:0] wr_mstq_din, wr_mstq_dout;
wire wr_mstq_full, wr_mstq_wr_en;
wire wr_mstq_empty, wr_mstq_rd_en;

fifo fifo_wr_mstq (
	.Data(wr_mstq_din),
	.Clock(pcie_clk),
	.WrEn(wr_mstq_wr_en),
	.RdEn(wr_mstq_rd_en),
	.Reset(sys_rst),
	.Q(wr_mstq_dout),
	.Empty(wr_mstq_empty),
	.Full(wr_mstq_full)
);

wire [17:0] rd_slvq_din, rd_slvq_dout;
wire rd_slvq_full, rd_slvq_wr_en;
wire rd_slvq_empty, rd_slvq_rd_en;

fifo fifo_rd_slvq (
	.Data(rd_slvq_din),
	.Clock(pcie_clk),
	.WrEn(rd_slvq_wr_en),
	.RdEn(rd_slvq_rd_en),
	.Reset(sys_rst),
	.Q(rd_slvq_dout),
	.Empty(rd_slvq_empty),
	.Full(rd_slvq_full)
);

// AFIFO9
wire [8:0] rx_phyq_din, rx_phyq_dout;
wire rx_phyq_full, rx_phyq_wr_en;
wire rx_phyq_empty, rx_phyq_rd_en;

afifo9 afifo9_rx_phyq (
	.Data(rx_phyq_din),
	.WrClock(gmii_rx_clk),
	.RdClock(pcie_clk),
	.WrEn(rx_phyq_wr_en),
	.RdEn(rx_phyq_rd_en),
	.Reset(sys_rst),
	.RPReset(sys_rst),
	.Q(rx_phyq_dout),
	.Empty(rx_phyq_empty),
	.Full(rx_phyq_full)
);

wire [8:0] tx_phyq_din, tx_phyq_dout;
wire tx_phyq_full, tx_phyq_wr_en;
wire tx_phyq_empty, tx_phyq_rd_en;

afifo9 afifo9_tx_phyq (
	.Data(tx_phyq_din),
	.WrClock(pcie_clk),
	.RdClock(gmii_tx_clk),
	.WrEn(tx_phyq_wr_en),
	.RdEn(tx_phyq_rd_en),
	.Reset(sys_rst),
	.RPReset(sys_rst),
	.Q(tx_phyq_dout),
	.Empty(tx_phyq_empty),
	.Full(tx_phyq_full)
);

// GMII2FIFO9 module
gmii2fifo9 # (
	.Gap(4'h8)
) rx0gmii2fifo (
	.sys_rst(sys_rst),
	.gmii_rx_clk(gmii_rx_clk),
	.gmii_rx_dv(gmii_rx_dv),
	.gmii_rxd(gmii_rxd),
	.din(rx_phyq_din),
	.full(rx_phyq_full),
	.wr_en(rx_phyq_wr_en),
	.wr_clk()
);

// FIFO9TOGMII module
fifo9togmii tx0fifo2gmii (
	.sys_rst(sys_rst),
	.dout(tx_phyq_dout),
	.empty(tx_phyq_empty),
	.rd_en(tx_phyq_rd_en),
	.rd_clk(),
	.gmii_tx_clk(gmii_tx_clk),
	.gmii_tx_en(gmii_tx_en),
	.gmii_txd(gmii_txd)
);

// Slave bus
wire [6:0] slv_bar_i;
wire slv_ce_i;
wire slv_we_i;
wire [19:1] slv_adr_i;
wire [15:0] slv_dat_i;
wire [1:0] slv_sel_i;
wire [15:0] slv_dat_o, slv_dat1_o, slv_dat2_o;
reg [15:0] slv_dat0_o;

pcie_tlp inst_pcie_tlp (
	// System
	.pcie_clk(pcie_clk),
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
	//Receive credits
	.pd_num(pd_num),
	.ph_cr(ph_cr),
	.pd_cr(pd_cr),
	.nph_cr(nph_cr),
	.npd_cr(npd_cr),
	// Master FIFO
	.mst_rd_en(wr_mstq_rd_en),
	.mst_empty(wr_mstq_empty),
	.mst_dout(wr_mstq_dout),
	.mst_wr_en(),
	.mst_full(),
	.mst_din(),
	// Slave BUS
	.slv_bar_i(slv_bar_i),
	.slv_ce_i(slv_ce_i),
	.slv_we_i(slv_we_i),
	.slv_adr_i(slv_adr_i),
	.slv_dat_i(slv_dat_i),
	.slv_sel_i(slv_sel_i),
	.slv_dat_o(slv_dat_o),
	// Slave FIFO
	.slv_rd_en(),
	.slv_empty(),
	.slv_dout(),
	.slv_wr_en(),
	.slv_full(),
	.slv_din(),
	// LED and Switches
	.dipsw(dipsw),
	.led(),
	.segled(),
	.btn(btn)
);

// Regs
reg [31:0] if_v4addr = {8'd10, 8'd0, 8'd21, 8'd199};
reg [47:0] if_macaddr = 48'h003776_000001;
reg [31:0] dest_v4addr = {8'd10, 8'd0, 8'd21, 8'd255};
reg [47:0] dest_macaddr = 48'hffffff_ffffff;
reg [47:0] mem0_paddr = 48'h0000_d0000000;

reg [13:0] segledr;
always @(posedge pcie_clk) begin
	if (sys_rst == 1'b1) begin
		slv_dat0_o <= 16'h0;
		segledr[13:0] <= 14'h3fff;
		if_v4addr <= {8'd10, 8'd0, 8'd21, 8'd199};
		if_macaddr <= 48'h003776_000001;
		dest_v4addr <= {8'd10, 8'd0, 8'd21, 8'd255};
		dest_macaddr <= 48'hffffff_ffffff;
		mem0_paddr <= 48'h0000_00000000;
	end else begin
		if (slv_bar_i[0] & slv_ce_i) begin
			case (slv_adr_i[9:1])
				9'h000: begin // I/F IPV4 addr
					if (slv_we_i) begin
						if (slv_sel_i[0])
							if_v4addr[23:16] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							if_v4addr[31:24] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= if_v4addr[31:16];
				end
				9'h001: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							if_v4addr[ 7: 0] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							if_v4addr[15: 8] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= if_v4addr[15:0];
				end
				9'h002: begin // I/F MAC addr
					if (slv_we_i) begin
						if (slv_sel_i[0])
							if_macaddr[39:32] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							if_macaddr[47:40] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= if_macaddr[47:32];
				end
				9'h003: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							if_macaddr[23:16] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							if_macaddr[31:24] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= if_macaddr[31:16];
				end
				9'h004: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							if_macaddr[ 7: 0] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							if_macaddr[15: 8] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= if_macaddr[15:0];
				end
				9'h008: begin // dest IPV4 addr
					if (slv_we_i) begin
						if (slv_sel_i[0])
							dest_v4addr[23:16] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							dest_v4addr[31:24] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= dest_v4addr[31:16];
				end
				9'h009: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							dest_v4addr[ 7: 0] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							dest_v4addr[15: 8] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= dest_v4addr[15:0];
				end
				9'h00a: begin // dest MAC addr
					if (slv_we_i) begin
						if (slv_sel_i[0])
							dest_macaddr[39:32] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							dest_macaddr[47:40] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= dest_macaddr[47:32];
				end
				9'h00b: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							dest_macaddr[23:16] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							dest_macaddr[31:24] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= dest_macaddr[31:16];
				end
				9'h00c: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							dest_macaddr[ 7: 0] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							dest_macaddr[15: 8] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= dest_macaddr[15:0];
				end
				9'h014: begin // mem0 Physical addr
					if (slv_we_i) begin
						if (slv_sel_i[0])
							mem0_paddr[15: 8] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							mem0_paddr[ 7: 0] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= {mem0_paddr[7:0],mem0_paddr[15:8]};
				end
				9'h015: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							mem0_paddr[31:24] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							mem0_paddr[23:16] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= {mem0_paddr[23:16],mem0_paddr[31:24]};
				end
				9'h016: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							mem0_paddr[47:40] <= slv_dat_i[ 7: 0];
						if (slv_sel_i[1])
							mem0_paddr[39:32] <= slv_dat_i[15: 8];
					end else
						slv_dat0_o <= {mem0_paddr[39:32],mem0_paddr[47:40]};
				end
				default: begin
					slv_dat0_o <= 16'h00; // slv_adr_i[16:1];
				end
			endcase
		end
	end
end

`ifdef ENABLE_SERVER
// Server
server server_inst (
	// System
	.pcie_clk(pcie_clk),
	.sys_rst(sys_rst),
	// Phy FIFO
	.phy_din(),
	.phy_full(),
	.phy_wr_en(),
	.phy_dout(rx_phyq_dout),
	.phy_empty(rx_phyq_empty),
	.phy_rd_en(rx_phyq_rd_en),
	// Master FIFO
	.mst_din(wr_mstq_din),
	.mst_full(wr_mstq_full),
	.mst_wr_en(wr_mstq_wr_en),
	.mst_dout(),
	.mst_empty(),
	.mst_rd_en(),
	// LED and Switches
	.dipsw(dipsw),
	.led(),
	.segled(),
	.btn(btn)
);
`endif

`ifdef ENABLE_REQUESTOR
// Requester
requester requester_inst (
	// System
	.pcie_clk(pcie_clk),
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
	// Phy FIFO
	.phy_din(tx_phyq_din),
	.phy_full(tx_phyq_full),
	.phy_wr_en(tx_phyq_wr_en),
	.phy_dout(),
	.phy_empty(),
	.phy_rd_en(),
	// Interface Information
	.if_v4addr(if_v4addr),
	.if_macaddr(if_macaddr),
	.dest_v4addr(dest_v4addr),
	.dest_macaddr(dest_macaddr),
	// Page Table
	.mem0_paddr(mem0_paddr),
	// LED and Switches
	.dipsw(dipsw),
	.led(led),
	.segled(),
	.btn(btn)
);
`endif

// Simple RAM
ram_dq ram_dq_inst1 (
	.Clock(pcie_clk),
	.ClockEn(slv_ce_i & slv_bar_i[2]),
	.Reset(sys_rst),
	.ByteEn(slv_sel_i),
	.WE(slv_we_i),
	.Address(slv_adr_i[14:1]),
	.Data(slv_dat_i),
	.Q(slv_dat1_o)
);


assign slv_dat_o = ( {16{slv_bar_i[0]}} & slv_dat0_o ) | ( {16{slv_bar_i[2]}} & slv_dat1_o );
assign segled = segledr;

endmodule
`default_nettype wire
