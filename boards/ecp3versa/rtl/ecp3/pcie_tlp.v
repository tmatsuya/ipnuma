module pcie_tlp (
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
	output reg tx_req = 1'b0,
	input tx_rdy,
	output reg tx_st = 1'b0,
	output reg tx_end = 1'b0,
	output [15:0] tx_data,
	// Receive credits
	output reg [7:0] pd_num = 8'h0,
	output reg ph_cr = 1'b0,
	output reg pd_cr = 1'b0,
	output reg nph_cr = 1'b0,
	output reg npd_cr = 1'b0,
	// Slave bus
	output slv_ce_i,
	output slv_we_i,
	output [31:2] slv_adr_i,
	output [15:0] slv_dat_i,
	output [1:0] slv_sel_i,
	input  [15:0] slv_dat_o,
	// LED and Switches
	input [7:0] dipsw,
	output [7:0] led,
	output [13:0] segled,
	input btn
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

always @(posedge pcie_clk or posedge sys_rst) begin
	if (sys_rst) begin
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

always @(posedge pcie_clk or posedge sys_rst) begin
	if (sys_rst) begin
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
always @(posedge pcie_clk or posedge sys_rst) begin
	if (sys_rst) begin
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
//assign led = ~(btn ? rx_addr[31:24] : rx_addr[23:16]);
assign led = ~(btn ? rx_length[7:0] : {rx_lastbe[3:0], rx_firstbe[3:0]} );
assign segled = 14'b11111111111111;

endmodule
