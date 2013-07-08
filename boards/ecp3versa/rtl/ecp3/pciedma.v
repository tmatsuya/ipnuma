`default_nettype none
module pciedma (
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
	// LED and Switches
	input [7:0] dipsw,
	output [7:0] led,
	output [13:0] segled,
	input btn
);

// Master bus
wire mst_rd_en;
wire mst_empty;
wire [17:0] mst_dout;
wire mst_wr_en;
wire mst_full;
wire [17:0] mst_din;
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
	// Master bus
	.mst_rd_en(mst_rd_en),
	.mst_empty(mst_empty),
	.mst_dout(mst_dout),
	.mst_wr_en(mst_wr_en),
	.mst_full(mst_full),
	.mst_din(mst_din),
	// Slave bus
	.slv_bar_i(slv_bar_i),
	.slv_ce_i(slv_ce_i),
	.slv_we_i(slv_we_i),
	.slv_adr_i(slv_adr_i),
	.slv_dat_i(slv_dat_i),
	.slv_sel_i(slv_sel_i),
	.slv_dat_o(slv_dat_o),
	// LED and Switches
	.dipsw(dipsw),
	.led(led),
	.segled(),
	.btn(btn)
);

reg [13:0] segled;
always @(posedge pcie_clk) begin
	if (sys_rst == 1'b1) begin
		slv_dat0_o <= 16'h0;
		segled[13:0] <= 14'h3fff;
	end else begin
		if (slv_bar_i[0] & slv_ce_i) begin
			case (slv_adr_i[9:1])
				9'h000: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							segled[7:0] <= slv_dat_i[7:0];
						if (slv_sel_i[1])
							segled[13:8] <= slv_dat_i[13:8];
					end else
						slv_dat0_o <= {2'b0, segled[13:0]};
				end
				default: begin
					slv_dat0_o <= slv_adr_i[16:1];
				end
			endcase
		end
	end
end

// Dual port RAM
`ifndef SIMULATION
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
`endif

// FIFO
`ifndef SIMULATION
fifo fifo_inst1 (
	.Data( ),
	.Clock(pcie_clk),
	.WrEn( ),
	.RdEn( ),
	.Reset(sys_rst),
	.Q( ),
	.Empty( ),
	.Full( )
);
`endif

assign slv_dat_o = ( {16{slv_bar_i[0]}} & slv_dat0_o ) | ( {16{slv_bar_i[2]}} & slv_dat1_o );

endmodule
`default_nettype wire
