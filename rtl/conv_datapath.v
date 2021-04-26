`timescale 1ns / 1ps

module conv_datapath
#(
	parameter KERNEL_SIZE = 3,
	parameter KERNEL_DATA_WIDTH = 8,
	parameter PRODUCT_DATA_WIDTH = 32
)
(
	input  clk, 
	input  rst_n,
	
	input  pipe_flush_i,
	input  kernel_data_valid_i,
	
	input  [KERNEL_SIZE*KERNEL_SIZE*KERNEL_DATA_WIDTH-1:0]kernel_data_i,
	input  [KERNEL_SIZE*KERNEL_SIZE*KERNEL_DATA_WIDTH-1:0]filter_data_i,
	
	output conv_data_valid_o,
	output [PRODUCT_DATA_WIDTH-1:0]conv_data_o
);

integer i;
reg [KERNEL_DATA_WIDTH-1:0]w_kerne_data[KERNEL_SIZE*KERNEL_SIZE-1:0];
always @(kernel_data_i) begin
	w_kerne_data[0] = kernel_data_i[(0+1)*KERNEL_DATA_WIDTH-1:0*KERNEL_DATA_WIDTH];
	w_kerne_data[1] = kernel_data_i[(1+1)*KERNEL_DATA_WIDTH-1:1*KERNEL_DATA_WIDTH];
	w_kerne_data[2] = kernel_data_i[(2+1)*KERNEL_DATA_WIDTH-1:2*KERNEL_DATA_WIDTH];
	w_kerne_data[3] = kernel_data_i[(3+1)*KERNEL_DATA_WIDTH-1:3*KERNEL_DATA_WIDTH];
	w_kerne_data[4] = kernel_data_i[(4+1)*KERNEL_DATA_WIDTH-1:4*KERNEL_DATA_WIDTH];
	w_kerne_data[5] = kernel_data_i[(5+1)*KERNEL_DATA_WIDTH-1:5*KERNEL_DATA_WIDTH];
	w_kerne_data[6] = kernel_data_i[(6+1)*KERNEL_DATA_WIDTH-1:6*KERNEL_DATA_WIDTH];
	w_kerne_data[7] = kernel_data_i[(7+1)*KERNEL_DATA_WIDTH-1:7*KERNEL_DATA_WIDTH];
	w_kerne_data[8] = kernel_data_i[(8+1)*KERNEL_DATA_WIDTH-1:8*KERNEL_DATA_WIDTH];
end


wire [PRODUCT_DATA_WIDTH-1:0]w_mult_product[KERNEL_SIZE*KERNEL_SIZE-1:0];

/****************************************conv MAC tree**************************************/
generate
	genvar j;
	for(j = 0; j < KERNEL_SIZE * KERNEL_SIZE; j = j + 1) begin: mult_product_generate
		assign w_mult_product[j] = w_kerne_data[j] * filter_data_i[(j+1)*KERNEL_DATA_WIDTH-1-:KERNEL_DATA_WIDTH]; 
	end
endgenerate

wire s_pipe_stall;
assign s_pipe_stall = ~kernel_data_valid_i;

reg [PRODUCT_DATA_WIDTH-1:0]r_adder_tree_stage_1[4:0];
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_adder_tree_stage_1[0] <= 0;
		r_adder_tree_stage_1[1] <= 0;
		r_adder_tree_stage_1[2] <= 0;
		r_adder_tree_stage_1[3] <= 0;
		r_adder_tree_stage_1[4] <= 0;
	end
	else if(pipe_flush_i) begin
		r_adder_tree_stage_1[0] <= 0;
		r_adder_tree_stage_1[1] <= 0;
		r_adder_tree_stage_1[2] <= 0;
		r_adder_tree_stage_1[3] <= 0;
		r_adder_tree_stage_1[4] <= 0;
	end
	else if(!s_pipe_stall) begin
		r_adder_tree_stage_1[0] <= w_mult_product[0] + w_mult_product[1];
		r_adder_tree_stage_1[1] <= w_mult_product[2] + w_mult_product[3];
		r_adder_tree_stage_1[2] <= w_mult_product[4] + w_mult_product[5];
		r_adder_tree_stage_1[3] <= w_mult_product[6] + w_mult_product[7];
		r_adder_tree_stage_1[4] <= {24'd0, w_mult_product[8]};
	end
end

reg [PRODUCT_DATA_WIDTH-1:0]r_adder_tree_stage_2[2:0];
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_adder_tree_stage_2[0] <= 0;
		r_adder_tree_stage_2[1] <= 0;
		r_adder_tree_stage_2[2] <= 0;
	end
	else if(pipe_flush_i) begin
		r_adder_tree_stage_2[0] <= 0;
		r_adder_tree_stage_2[1] <= 0;
		r_adder_tree_stage_2[2] <= 0;
	end
	else if(!s_pipe_stall) begin
		r_adder_tree_stage_2[0] <= r_adder_tree_stage_1[0] + r_adder_tree_stage_1[1];
		r_adder_tree_stage_2[1] <= r_adder_tree_stage_1[2] + r_adder_tree_stage_1[3];
		r_adder_tree_stage_2[2] <= r_adder_tree_stage_1[4];
	end
end

reg [PRODUCT_DATA_WIDTH-1:0]r_adder_tree_stage_3;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_adder_tree_stage_3 <= 0;

	end
	else if(pipe_flush_i) begin
		r_adder_tree_stage_3 <= 0;
	end
	else if(!s_pipe_stall) begin
		r_adder_tree_stage_3 <= r_adder_tree_stage_2[0] + r_adder_tree_stage_2[1] + r_adder_tree_stage_2[2];
	end                         
end

reg [1:0]r_pipe_stage_cnt;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_pipe_stage_cnt <= 2'd0;
	end	
	else if(pipe_flush_i) begin
		r_pipe_stage_cnt <= 2'd0;
	end
	else if(!s_pipe_stall) begin
		if(r_pipe_stage_cnt < 3 && kernel_data_valid_i) begin
			r_pipe_stage_cnt <= r_pipe_stage_cnt + 1'b1;
		end
	end
end

assign conv_data_o = r_adder_tree_stage_3;
assign conv_data_valid_o = (r_pipe_stage_cnt == 3) ? 1 : 0;
	
endmodule