`timescale 1ns / 1ps

module win_gen
#(
	parameter DATA_WIDTH = 8,
	parameter VECTOR_SIZE = 3
)
(
	input  clk,
	input  rst_n,
	input  en,
	input  clear,
	
	input  [VECTOR_SIZE*DATA_WIDTH-1:0]vector_data_i,
	output window_data_valid_o,
	output [VECTOR_SIZE*VECTOR_SIZE*DATA_WIDTH-1:0]window_data_o
);

integer i;
reg [VECTOR_SIZE*DATA_WIDTH-1:0]window_data_regs[VECTOR_SIZE-1:0];

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i = 0; i < VECTOR_SIZE; i = i + 1) begin
			window_data_regs[i] <= {DATA_WIDTH*VECTOR_SIZE{1'b0}};
		end
	end
	else if(clear) begin
		for(i = 0; i < VECTOR_SIZE; i = i + 1) begin
			window_data_regs[i] <= {DATA_WIDTH*VECTOR_SIZE{1'b0}};
		end
	end
	else if(en) begin
		window_data_regs[0] <= vector_data_i;
		for(i = 1; i < VECTOR_SIZE; i = i + 1) begin
			window_data_regs[i] <= window_data_regs[i-1];
		end
	end
end

reg  [4:0]win_vector_cnt;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		win_vector_cnt <= 5'd0;
	end
	else if(clear) begin
		win_vector_cnt <= 5'd0;
	end
	else if(en) begin
		if(win_vector_cnt < VECTOR_SIZE) begin
			win_vector_cnt <= win_vector_cnt + 5'd1;
		end
	end
end

generate 
	genvar j;
	for(j = 0; j < VECTOR_SIZE; j = j + 1) begin
		assign window_data_o[(j+1)*VECTOR_SIZE*DATA_WIDTH-1-:VECTOR_SIZE*DATA_WIDTH] = window_data_regs[j];
	end
endgenerate

assign window_data_valid_o = (win_vector_cnt == VECTOR_SIZE) ? 1 : 0;

endmodule
