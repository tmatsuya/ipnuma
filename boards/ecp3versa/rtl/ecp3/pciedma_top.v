module top (
	input rstn,
	input FLIP_LANES,
	input refclkp,
	input refclkn,
	input hdinp,
	input hdinn,
	output hdoutp,
	output hdoutn,
	input [7:0] dip_switch,
	output [7:0] led,
	output [13:0] led_out,
	output dp,
	input reset_n
);

reg  [20:0] rstn_cnt;
reg  core_rst_n;
wire [15:0] rx_data, tx_data,  tx_dout_wbm, tx_dout_ur;
wire [6:0] rx_bar_hit;
reg  [7:0] pd_num = 8'h0;
reg  ph_cr = 1'b0, pd_cr = 1'b0, nph_cr = 1'b0, npd_cr = 1'b0;
wire [7:0] bus_num ;
wire [4:0] dev_num ;
wire [2:0] func_num ;

wire [8:0] tx_ca_ph ;
wire [12:0] tx_ca_pd  ;
wire [8:0] tx_ca_nph ;
wire [12:0] tx_ca_npd ;
wire [8:0] tx_ca_cplh;
wire [12:0] tx_ca_cpld ;
wire clk_125;
wire tx_eop_wbm;
// Reset management
always @(posedge clk_125 or negedge rstn) begin
	if (!rstn) begin
		rstn_cnt <= 21'd0 ;
		core_rst_n <= 1'b0 ;
	end else begin
		if (rstn_cnt[20])		// 4ms in real hardware
			core_rst_n <= 1'b1 ;
		else
			rstn_cnt <= rstn_cnt + 1'b1 ;
	end
end

pcie_top pcie(
	.refclkp			( refclkp ),
	.refclkn			( refclkn ),
	.sys_clk_125			( clk_125 ),
	.ext_reset_n			( rstn ),
	.rstn				( core_rst_n ),
	.flip_lanes			( FLIP_LANES ),
	.hdinp0				( hdinp ),
	.hdinn0				( hdinn ),
	.hdoutp0			( hdoutp ),
	.hdoutn0			( hdoutn ),
	.msi				( 8'd0 ),
	.inta_n				( 1'b1 ),
	// This PCIe interface uses dynamic IDs.
	.vendor_id			(16'h3776),
	.device_id			(16'h8010),
	.rev_id				(8'h00),
	.class_code			(24'h000000),
	.subsys_ven_id			(16'h3776),
	.subsys_id			(16'h8010),
	.load_id			(1'b1),
	// Inputs
	.force_lsm_active		( 1'b0 ),
	.force_rec_ei			( 1'b0 ),
	.force_phy_status		( 1'b0 ),
	.force_disable_scr		( 1'b0 ),
	.hl_snd_beacon			( 1'b0 ),
	.hl_disable_scr			( 1'b0 ),
	.hl_gto_dis			( 1'b0 ),
	.hl_gto_det			( 1'b0 ),
	.hl_gto_hrst			( 1'b0 ),
	.hl_gto_l0stx			( 1'b0 ),
	.hl_gto_l1			( 1'b0 ),
	.hl_gto_l2			( 1'b0 ),
	.hl_gto_l0stxfts		( 1'b0 ),
	.hl_gto_lbk			( 1'd0 ),
	.hl_gto_rcvry			( 1'b0 ),
	.hl_gto_cfg			( 1'b0 ),
	.no_pcie_train			( 1'b0 ),
	// Power Management Interface
	.tx_dllp_val			( 2'd0 ),
	.tx_pmtype			( 3'd0 ),
	.tx_vsd_data			( 24'd0 ),
	.tx_req_vc0			( tx_req ),
	.tx_data_vc0			( tx_data ),
	.tx_st_vc0			( tx_st ),
	.tx_end_vc0			( tx_end ),
	.tx_nlfy_vc0			( 1'b0 ),
	.ph_buf_status_vc0		( 1'b0 ),
	.pd_buf_status_vc0		( 1'b0 ),
	.nph_buf_status_vc0		( 1'b0 ),
	.npd_buf_status_vc0		( 1'b0 ),
	.ph_processed_vc0		( ph_cr ),
	.pd_processed_vc0		( pd_cr ),
	.nph_processed_vc0		( nph_cr ),
	.npd_processed_vc0		( npd_cr ),
	.pd_num_vc0			( pd_num ),
	.npd_num_vc0			( 8'd1 ),
	// From User logic
	.cmpln_tout			( 1'b0 ),
	.cmpltr_abort_np		( 1'b0 ),
	.cmpltr_abort_p			( 1'b0 ),
	.unexp_cmpln			( 1'b0 ),
	.ur_np_ext			( 1'b0 ),
	.ur_p_ext			( 1'b0 ),
	.np_req_pend			( 1'b0 ),
	.pme_status			( 1'b0 ),
	.tx_rdy_vc0			( tx_rdy),
	.tx_ca_ph_vc0			( tx_ca_ph),
	.tx_ca_pd_vc0			( tx_ca_pd),
	.tx_ca_nph_vc0			( tx_ca_nph),
	.tx_ca_npd_vc0			( tx_ca_npd ),
	.tx_ca_cplh_vc0			( tx_ca_cplh ),
	.tx_ca_cpld_vc0			( tx_ca_cpld ),
	.tx_ca_p_recheck_vc0		( tx_ca_p_recheck ),
	.tx_ca_cpl_recheck_vc0		( tx_ca_cpl_recheck ),
	.rx_data_vc0			( rx_data),
	.rx_st_vc0			( rx_st),
	.rx_end_vc0			( rx_end),
	.rx_us_req_vc0			( rx_us_req ),
	.rx_malf_tlp_vc0		( rx_malf_tlp ),
	.rx_bar_hit			( rx_bar_hit ),
	// From Config Registers
	.bus_num			( bus_num  ),
	.dev_num			( dev_num  ),
	.func_num			( func_num  )
);

reg [31:0] reg_data = 32'hffffffff;

parameter [2:0]
	TLP_MR   = 3'h0,
	TLP_MRdLk= 3'h1,
	TLP_IO   = 3'h2,
	TLP_Cfg0 = 3'h3,
	TLP_Cfg1 = 3'h4,
	TLP_Msg  = 3'h5,
	TLP_Cpl  = 3'h6,
	TLP_CplLk= 3'h7;

reg [2:0] rx_comm = 3'h0;

//-----------------------------------------------------------------
// TLP receive
//-----------------------------------------------------------------
parameter [3:0]
	RX_HEAD0 = 4'h0,
	RX_HEAD1 = 4'h1,
	RX_REQ2  = 4'h2,
	RX_REQ3  = 4'h3,
	RX_REQ4  = 4'h4,
	RX_REQ5  = 4'h5,
	RX_REQ6  = 4'h6,
	RX_REQ7  = 4'h7,
	RX_REQ   = 4'h8,
	RX_COMP2 = 4'h9,
	RX_COMP3 = 4'ha,
	RX_COMP4 = 4'hb,
	RX_COMP5 = 4'hc,
	RX_COMP6 = 4'hd,
	RX_COMP7 = 4'he,
	RX_COMP  = 4'hf;
reg [3:0] rx_status = RX_HEAD0;
reg [7:0] rx_count = 8'h0;
reg [1:0] rx_fmt = 2'b00;
reg [4:0] rx_type = 5'b00000;
reg [2:0] rx_tc = 2'b00;
reg       rx_td = 1'b0, rx_ep = 1'b0;
reg [1:0] rx_attr = 2'b00;
reg [9:0] rx_length = 10'h0;
reg [15:0] rx_reqid = 16'h0;
reg [7:0]  rx_tag = 8'h0;
reg [3:0]  rx_lastbe = 4'h0, rx_firstbe = 4'h0;
reg [63:2] rx_addr = 62'h0000000000000000;
reg        rx_tlph_valid = 1'b0;

always @(posedge clk_125 or negedge core_rst_n) begin
	if (!core_rst_n) begin
		rx_status <= RX_HEAD0;
		rx_count <= 8'h0;
		rx_tlph_valid <= 1'b0;
		pd_num <= 8'h0;
		ph_cr <= 1'b0;
		pd_cr <= 1'b0;
		nph_cr <= 1'b0;
		npd_cr <= 1'b0;
	end else begin
		rx_tlph_valid <= 1'b0;
		pd_num <= 8'h0;
		ph_cr <= 1'b0;
		pd_cr <= 1'b0;
		nph_cr <= 1'b0;
		npd_cr <= 1'b0;
		if ( rx_end == 1'b1 ) begin
			case ( rx_comm )
				TLP_MR, TLP_MRdLk: begin
					if ( rx_bar_hit[0] || rx_bar_hit[1] ) begin
						if ( rx_fmt[1] == 1'b0 ) begin
							nph_cr  <= 1'b1;
						end else begin
							ph_cr <= 1'b1;
							pd_cr <= rx_fmt[1];
							pd_num <= rx_length[1:0] == 2'b00 ? rx_length[9:2] : (rx_length[9:2] + 8'h1);
						end
					end
				end
				TLP_IO, TLP_Cfg0, TLP_Cfg1: begin
					nph_cr <= 1'b1;
					npd_cr <= rx_fmt[1];
				end
				TLP_Msg: begin
					ph_cr <= 1'b1;
					if ( rx_fmt[1] == 1'b1 ) begin
						pd_cr <=  1'b1;
						pd_num <= rx_length[1:0] == 2'b00 ? rx_length[9:2] : (rx_length[9:2] + 8'h1);
					end
				end
				TLP_Cpl: begin
				end
				TLP_CplLk: begin
				end
			endcase
			rx_status <= RX_HEAD0;
		end
		case ( rx_status )
			RX_HEAD0: begin
				if ( rx_st == 1'b1 ) begin
					rx_fmt [1:0] <= rx_data[14:13];
					rx_type[4:0] <= rx_data[12: 8];
					rx_tc  [2:0] <= rx_data[ 6: 4];
					if ( rx_data[12] == 1'b1 ) begin
						rx_comm <= TLP_Msg;
					end else begin
						if ( rx_data[11] == 1'b0) begin
							case ( rx_data[10:8] )
								3'b000: rx_comm <= TLP_MR;
								3'b001: rx_comm <= TLP_MRdLk;
								3'b010: rx_comm <= TLP_IO;
								3'b100: rx_comm <= TLP_Cfg0;
								default:rx_comm <= TLP_Cfg1;
							endcase
						end else begin
							if ( rx_data[8] == 1'b0 )
								rx_comm <= TLP_Cpl;
							else
								rx_comm <= TLP_CplLk;
						end
					end
					rx_status <= RX_HEAD1;
				end
			end
			RX_HEAD1: begin
				rx_td          <= rx_data[15:15];
				rx_ep          <= rx_data[14:14];
				rx_attr[1:0]   <= rx_data[13:12];
				rx_length[9:0] <= rx_data[ 9: 0];
				if ( rx_type[3] == 1'b0 )
					rx_status <= RX_REQ2;
				else
					rx_status <= RX_COMP2;
			end
			RX_REQ2: begin
				rx_reqid[15:0] <= rx_data[15:0];
				rx_status <= RX_REQ3;
			end
			RX_REQ3: begin
				rx_tag[7:0]    <= rx_data[15:8];
				rx_lastbe[3:0]  <= rx_data[7:4];
				rx_firstbe[3:0]  <= rx_data[3:0];
				if ( rx_fmt[0] == 1'b0 ) begin	// 64 or 32bit ??
					rx_addr[63:32] <= 32'h0;
					rx_status <= RX_REQ6;
				end else
					rx_status <= RX_REQ4;
			end
			RX_REQ4: begin
				rx_addr[63:48] <= rx_data[15:0];
				rx_status <= RX_REQ5;
			end
			RX_REQ5: begin
				rx_addr[47:32] <= rx_data[15:0];
				rx_status <= RX_REQ6;
			end
			RX_REQ6: begin
				rx_addr[31:16] <= rx_data[15:0];
				rx_tlph_valid <= 1'b1;
				rx_status <= RX_REQ7;
			end
			RX_REQ7: begin
				rx_addr[15: 2] <= rx_data[15:2];
				rx_count <= 8'h0;
				if ( rx_end == 1'b0 )
					rx_status <= RX_REQ;
			end
			RX_REQ: begin
				rx_count <= rx_count + 8'h1;
			end
		endcase
	 end
end

//-----------------------------------------------------------------
// TLP transmit
//-----------------------------------------------------------------
parameter [3:0]
	TX_IDLE  = 4'h0,
	TX_WAIT  = 4'h1,
	TX_HEAD0 = 4'h2,
	TX_HEAD1 = 4'h3,
	TX_COMP2 = 4'h4,
	TX_COMP3 = 4'h5,
	TX_COMP4 = 4'h6,
	TX_COMP5 = 4'h7,
	TX_COMP6 = 4'h8,
	TX_COMP7 = 4'h9,
	TX_REQ2  = 4'ha,
	TX_COMP  = 4'hf;
reg [3:0] tx_status = TX_IDLE;
reg [7:0] tx_count = 8'h0;
reg       tx_req = 1'b0, tx_st = 1'b0, tx_end = 1'b0;
reg [1:0] tx_fmt = 2'b00;
reg [4:0] tx_type = 5'b00000;
reg [2:0] tx_tc = 2'b00;
reg       tx_td = 1'b0, tx_ep = 1'b0;
reg [1:0] tx_attr = 2'b00;
reg [9:0] tx_length = 10'h0;
reg [15:0] tx_reqid = 16'h0;
reg [7:0]  tx_tag = 8'h0;
reg [7:0]  tx_lowaddr = 8'h0;
reg [3:0]  tx_lastbe = 4'h0, tx_firstbe = 4'h0;
reg [63:2] tx_addr = 62'h0000000000000000;
reg [2:0]  tx_cplst = 3'h0;
reg tx_bcm = 1'b0;
reg [11:0] tx_bcount = 12'h0;
reg [15:0] tx_data1;
reg        tx_tlph_valid = 1'b0;

always @(posedge clk_125 or negedge core_rst_n) begin
	if (!core_rst_n) begin
		tx_status <= TX_IDLE;
		tx_req <= 1'b0;
		tx_st <= 1'b0;
		tx_end <= 1'b0;
		tx_count <= 8'h0;
	end else begin
		tx_st <= 1'b0;
		tx_end <= 1'b0;
		case ( tx_status )
			TX_IDLE: begin
				if ( tx_tlph_valid == 1'b1 ) begin
					tx_req <= 1'b1;
					tx_status <= TX_WAIT;
				end
			end
			TX_WAIT: begin
				if ( tx_rdy == 1'b1 ) begin
					tx_req <= 1'b0;
					tx_status <= TX_HEAD0;
				end
			end
			TX_HEAD0: begin
				tx_data1[15:0] <= {1'b0, tx_fmt[1:0], tx_type[4:0], 1'b0, tx_tc[2:0], 4'b000};
				tx_st <= 1'b1;
				tx_status <= TX_HEAD1;
			end
			TX_HEAD1: begin
				tx_data1[15:0] <= {tx_td, tx_ep, tx_attr[1:0], 2'b00, tx_length[9:0]};
				if ( tx_type[3] == 1'b0 )
					tx_status <= TX_REQ2;
				else
					tx_status <= TX_COMP2;
			end
			TX_COMP2: begin
				tx_data1[15:0] <= {bus_num, dev_num, func_num};	// CplID
				tx_status <= TX_COMP3;
			end
			TX_COMP3: begin
				tx_data1[15:0] <= { tx_cplst[2:0], tx_bcm, tx_bcount[11:0] };
				tx_status <= TX_COMP4;
			end
			TX_COMP4: begin
				tx_data1[15:0] <= tx_reqid[15:0];
				tx_status <= TX_COMP5;
			end
			TX_COMP5: begin
				tx_data1[15:0] <= { tx_tag[7:0], 1'b0, tx_lowaddr[6:0] };
				tx_status <= TX_COMP6;
			end
			TX_COMP6: begin
				tx_data1[15:0] <= reg_data[31:16];
				tx_status <= TX_COMP7;
			end
			TX_COMP7: begin
				tx_data1[15:0] <= reg_data[15:0];
				tx_end <= 1'b1;
				tx_status <= TX_IDLE;
tx_count <= tx_count + 8'h1;
			end
		endcase
	end
end

//-----------------------------------------------------------------
// Seaquencer
//-----------------------------------------------------------------
parameter [3:0]
	SQ_IDLE   = 3'h0,
	SQ_MREADH = 3'h1,
	SQ_MREADD = 3'h2,
	SQ_MWRITEH= 3'h3,
	SQ_COMP   = 3'h4;
reg [3:0] sq_status = SQ_IDLE;
always @(posedge clk_125 or negedge core_rst_n) begin
	if (!core_rst_n) begin
		tx_tlph_valid <= 1'b0;
		sq_status <= SQ_IDLE;
		reg_data[31:0] <= 32'hffffffff;
	end else begin
		tx_tlph_valid <= 1'b0;
		case ( sq_status )
			SQ_IDLE: begin
				if ( rx_tlph_valid == 1'b1 ) begin
					case ( rx_comm )
						TLP_MR: begin
							if ( rx_fmt[1] == 1'b0 )
								sq_status <= SQ_MREADH;
							else
								sq_status <= SQ_MWRITEH;
						end
						TLP_MRdLk: begin
						end
						TLP_IO: begin
						end
						TLP_Cfg0: begin
						end
						TLP_Cfg1: begin
						end
						TLP_Msg: begin
						end
						TLP_Cpl: begin
						end
						TLP_CplLk: begin
						end
					endcase
				end
			end
			SQ_MREADH: begin
				tx_fmt[1:0] <= 2'b10;
				tx_type[4:0] <= 5'b01010;	// Cpl with data
				tx_tc[2:0] <= 3'b000;
				tx_td <= 1'b0;
				tx_ep <= 1'b0;
				tx_attr[1:0] <= 2'b00;
				tx_length[9:0] <= rx_length;
				tx_cplst[2:0] <= 3'b000;
				tx_bcm <= 1'b0;
				tx_bcount[11:0] <= 12'h1;
				tx_reqid[15:0] <= rx_reqid[15:0];
				tx_tag[7:0] <= rx_tag[7:0];
				case (rx_firstbe[3:0])
					4'b0001: tx_lowaddr[7:0] <= {rx_addr[7:2], 2'b00};
					4'b0010: tx_lowaddr[7:0] <= {rx_addr[7:2], 2'b01};
					4'b0100: tx_lowaddr[7:0] <= {rx_addr[7:2], 2'b10};
					4'b1000: tx_lowaddr[7:0] <= {rx_addr[7:2], 2'b11};
				endcase
				tx_tlph_valid <= 1'b1;
				sq_status <= SQ_MREADD;
			end
			SQ_MREADD: begin
				sq_status <= SQ_IDLE;
			end
			SQ_MWRITEH: begin
				if ( rx_count[0] == 1'b0 ) begin
					if ( rx_firstbe[0] == 1'b1)
						reg_data[31:24] <= rx_data[15:8];
					if ( rx_firstbe[1] == 1'b1)
						reg_data[23:16] <= rx_data[7:0];
				end else begin
					if ( rx_firstbe[2] == 1'b1)
						reg_data[15: 8] <= rx_data[15:8];
					if ( rx_firstbe[3] == 1'b1)
						reg_data[ 7: 0] <= rx_data[7:0];
				end
				if ( rx_end == 1'b1 )
					sq_status <= SQ_IDLE;
			end
		endcase
	end
end

assign tx_data = tx_data1;

//assign led = 8'b11111111;
//assign led = ~(reset_n ? rx_addr[31:24] : rx_addr[23:16]);
assign led = ~(reset_n ? rx_length[7:0] : {rx_lastbe[3:0], rx_firstbe[3:0]} );
assign led_out = 14'b11111111111111;

endmodule
