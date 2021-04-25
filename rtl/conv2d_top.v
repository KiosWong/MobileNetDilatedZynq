`timescale 1ns / 1ps

module conv2d_top
#(
	parameter IFMAP_DATA_WIDTH = 8,
	parameter OFMAP_DATA_WIDTH = 32,
	parameter KERNEL_SIZE = 3
)
(
	input  clk,
	input  rst_n,
	input  en,
	input  clear,
	
	input  kernel_data_reorder_i,
	
	input  ifmap_fifo_wr_en_i,
	input  [IFMAP_DATA_WIDTH-1:0]ifmap_fifo_data_i,
	input  [KERNEL_SIZE*KERNEL_SIZE*IFMAP_DATA_WIDTH-1:0]filter_data_i,
	input  ofmap_fifo_rd_en_i,
	output ofmap_fifo_data_valid,
	output [OFMAP_DATA_WIDTH-1:0]ofmap_fifo_data_o
);

localparam  FIFO_SIZE = 1024;
			
wire w_ifmap_fifo_data_req;
wire s_ifmap_empty;
wire [IFMAP_DATA_WIDTH-1:0]ifmap_fifo_data_out;

sync_bram_fifo
#(
	.DATA_WIDTH(IFMAP_DATA_WIDTH),
	.BUF_SIZE(FIFO_SIZE)
)
u_ifmap_fifo
( 	
	.clk(clk),
	.rst_n(rst_n),
	.clear(clear),
	.fifo_din(ifmap_fifo_data_i),
	.fifo_wr_en(ifmap_fifo_wr_en_i),
	.fifo_rd_en(w_ifmap_fifo_data_req),
	.fifo_rd_rewind(0),
	.fifo_empty(s_ifmap_empty),
	.fifo_full(),
	.fifo_out(ifmap_fifo_data_out)
);

wire w_ifmap_fifo_data_valid;
wire w_tap_data_valid;
wire [KERNEL_SIZE*IFMAP_DATA_WIDTH-1:0]w_tap_data_out;

assign w_ifmap_fifo_data_valid = ~s_ifmap_empty;

shift_ram 
#(
	.DATA_WIDTH(IFMAP_DATA_WIDTH)
)
u_shift_ram
(
	.clk(clk),
	.rst_n(rst_n),
	.en(en),
	.clear(clear),
	
	.ifmap_fifo_data_req_o(w_ifmap_fifo_data_req),
	.ifmap_fifo_data_valid_i(w_ifmap_fifo_data_valid),

	.shift_data_in_i(ifmap_fifo_data_out),
	.tap_data_valid_o(w_tap_data_valid),
	.tap_data_o(w_tap_data_out)
);

wire w_window_data_valid;
wire [KERNEL_SIZE*KERNEL_SIZE*IFMAP_DATA_WIDTH-1:0]w_window_data_out;

win_gen 
#(
	.DATA_WIDTH(IFMAP_DATA_WIDTH)
)
u_win_gen
(
	.clk(clk),
	.rst_n(rst_n),
	.en(w_tap_data_valid),
	.clear(clear),

	.vector_data_i(w_tap_data_out),
	.window_data_valid_o(w_window_data_valid),
	.window_data_o(w_window_data_out)
);

wire w_conv_datapath_data_valid;
wire [OFMAP_DATA_WIDTH-1:0]w_conv_datapath_data_out;

conv_datapath 
#(
	.KERNEL_DATA_WIDTH(IFMAP_DATA_WIDTH)
)
u_conv_datapath
(
	.clk(clk), 
	.rst_n(rst_n),

	.pipe_flush_i(clear),
	.kernel_data_valid_i(w_window_data_valid),
	.kernel_data_reorder_i(kernel_data_reorder_i),

	.kernel_data_i(w_window_data_out),
	.filter_data_i(filter_data_i),

	.conv_data_valid_o(w_conv_datapath_data_valid),
	.conv_data_o(w_conv_datapath_data_out)
);

wire w_conv_op_valid;
wire w_conv_op_done;
wire [OFMAP_DATA_WIDTH-1:0]w_conv_op_data;

conv_ctrl u_conv_ctrl
(
	/*global control signals*/
	.clk(clk), 
	.rst_n(rst_n),
	.en(en),
	.clear(clear),

	.stride_sel_i(0),

	.window_valid_i(w_window_data_valid),

	.conv_data_valid_i(w_conv_datapath_data_valid),				//start indicator from window field, indicates data taps are ready

	.conv_datapath_data_i(w_conv_datapath_data_out),

	.conv_op_valid_o(w_conv_op_valid),
	.conv_op_done_o(w_conv_op_done),
	.conv_op_data_o(w_conv_op_data)
);

wire s_ofmap_fifo_empty;

sync_bram_fifo
#(
	.DATA_WIDTH(OFMAP_DATA_WIDTH),
	.BUF_SIZE(FIFO_SIZE)
)
u_ofmap_fifo
( 	
	.clk(clk),
	.rst_n(rst_n),
	.clear(clear),
	.fifo_din(w_conv_op_data),
	.fifo_wr_en(w_conv_op_valid),
	.fifo_rd_en(ofmap_fifo_rd_en_i),
	.fifo_rd_rewind(0),
	.fifo_empty(s_ofmap_fifo_empty),
	.fifo_full(),
	.fifo_out(ofmap_fifo_data_o)
);

assign ofmap_fifo_data_valid = ~s_ofmap_fifo_empty;

endmodule
