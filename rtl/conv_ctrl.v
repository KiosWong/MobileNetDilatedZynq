`timescale 1ns / 1ps

module conv_ctrl
#(
	parameter CONV_DATA_WIDTH = 32,
	parameter FMAP_TILE_SIZE = 32,
	parameter KERNEL_SIZE = 3,
	parameter STRIDE_SIZE = 2
)
(
	/*global control signals*/
	input  clk, 
	input  rst_n,
	input  en,
	input  clear,
	
	/* 0:stride disable(size 1); 1:stride enable(size 2)*/
	input stride_sel_i,
	/*start indicator from window field, indicates data taps are ready*/
	input  window_valid_i,				
	/*input control signal*/
	input  conv_data_valid_i,				
	/*input data*/
	input  [CONV_DATA_WIDTH-1:0]conv_datapath_data_i,
		
	/*module output interface*/
	output conv_op_valid_o,
	output conv_op_done_o,
	output [CONV_DATA_WIDTH-1:0]conv_op_data_o
);
	
function integer clogb2 (input integer bit_depth);
	for(clogb2 = 0; bit_depth > 0; clogb2 = clogb2 + 1) begin
		bit_depth = bit_depth >> 1;
	end
endfunction

reg [5:0]conv_cnt_row;
reg [5:0]conv_cnt_column;

wire s_conv_last_colum_in_row;
wire s_conv_last_row_in_fmap;
assign s_conv_last_colum_in_row = (conv_cnt_column == FMAP_TILE_SIZE - 1) ? 1 : 0;
assign s_conv_last_row_in_fmap = (conv_cnt_row == FMAP_TILE_SIZE - 1) ? 1 : 0;


always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		conv_cnt_column <= 6'd0;
	end
	else if(clear) begin
		conv_cnt_column <= 6'd0;
	end
	else if(en) begin
		if(conv_data_valid_i) begin
			if(conv_cnt_column == FMAP_TILE_SIZE - 1) begin
				conv_cnt_column <= 6'd0;
			end
			else if(conv_cnt_row < FMAP_TILE_SIZE) begin
				conv_cnt_column <= conv_cnt_column + 6'b1;
			end
		end
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		conv_cnt_row <= 6'd0;
	end
	else if(clear) begin
		conv_cnt_row <= 6'd0;
	end
	else if(en) begin
		if(s_conv_last_colum_in_row) begin
			if(conv_cnt_row < FMAP_TILE_SIZE) begin
				conv_cnt_row <= conv_cnt_row + 6'b1;
			end
		end
	end
end

wire s_slide_window_column_valid;
wire s_slide_window_row_valid;
wire s_slide_window_valid;
assign s_slide_window_column_valid = (conv_cnt_column < FMAP_TILE_SIZE - (KERNEL_SIZE - 1)) ? 1 : 0;
assign s_slide_window_row_valid = (conv_cnt_row < FMAP_TILE_SIZE - (KERNEL_SIZE - 1)) ? 1 : 0;
assign s_slide_window_valid = (s_slide_window_column_valid && s_slide_window_row_valid) ? 1 : 0;

reg stride_valid;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		stride_valid <= 1'b1;
	end
	else if(clear) begin
		stride_valid <= 1'b1;
	end
	else if(en && stride_sel_i == 1'b1) begin
		if(window_valid_i) begin
			stride_valid <= ~stride_valid;
		end
	end
end

assign conv_op_valid_o = (conv_data_valid_i && s_slide_window_valid && stride_valid) ? 1 : 0;
assign conv_op_done_o = (s_conv_last_colum_in_row && s_conv_last_row_in_fmap) ? 1 : 0;
assign conv_op_data_o = (conv_op_valid_o) ? conv_datapath_data_i : 0;

endmodule
