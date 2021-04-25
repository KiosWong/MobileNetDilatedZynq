`timescale 1ns / 1ps

module shift_ram
#(
	parameter DATA_WIDTH = 8,
	parameter TAP_NUMBER = 3
)
(
	input  clk,
	input  rst_n,
	input  en,
	input  clear,
	
	output ifmap_fifo_data_req_o,
	input  ifmap_fifo_data_valid_i,
	
	output tap_data_valid_o,
	input  [DATA_WIDTH-1:0]shift_data_in_i,
	output [TAP_NUMBER*DATA_WIDTH-1:0]tap_data_o
);

localparam FMAP_TILE_SIZE = 32;
integer i;

reg [DATA_WIDTH-1:0]shift_ram_regs[TAP_NUMBER*FMAP_TILE_SIZE-1:0];

initial begin
	for(i = 0; i < TAP_NUMBER*FMAP_TILE_SIZE; i = i + 1) begin
		shift_ram_regs[i] = 0;
	end
end

wire s_shift_ram_en;
assign s_shift_ram_en = en && ifmap_fifo_data_valid_i;

reg r_shift_ram_en;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_shift_ram_en <= 1'b0;
	end
	else if(clear) begin
		r_shift_ram_en <= 1'b0;
	end
	else begin
		r_shift_ram_en <= s_shift_ram_en;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i = 0; i < TAP_NUMBER*FMAP_TILE_SIZE; i = i + 1) begin
			shift_ram_regs[i] = 0;
		end
	end
	else if(clear) begin
		for(i = 0; i < TAP_NUMBER*FMAP_TILE_SIZE; i = i + 1) begin
			shift_ram_regs[i] = 0;
		end
	end
	else if(en) begin
		shift_ram_regs[0] <= shift_data_in_i;
		for(i = 1; i < TAP_NUMBER*FMAP_TILE_SIZE; i = i + 1) begin
			shift_ram_regs[i] <= shift_ram_regs[i-1];
		end
	end
end

reg [6:0]shift_cnt;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		shift_cnt <= 7'd0;
	end
	else if(clear) begin
		shift_cnt <= 7'd0;
	end
	else if(r_shift_ram_en) begin
		if(shift_cnt < TAP_NUMBER * FMAP_TILE_SIZE) begin
			shift_cnt <= shift_cnt + 7'd1;
		end
	end
end

generate 
	genvar j;
	for(j = 0; j < TAP_NUMBER; j = j + 1) begin
		assign tap_data_o[(j+1)*DATA_WIDTH-1-:DATA_WIDTH] = shift_ram_regs[(j+1)*FMAP_TILE_SIZE-1];
	end
endgenerate

assign ifmap_fifo_data_req_o = en;
assign tap_data_valid_o = (shift_cnt == TAP_NUMBER * FMAP_TILE_SIZE) ? 1 : 0;

endmodule

module dilated_shift_ram
#(
	parameter DATA_WIDTH = 8,
	parameter TAP_NUMBER = 3
)
(
	input  clk,
	input  rst_n,
	input  en,
	input  clear,
	
	input  [1:0]dilation_sel_i,
	input  ifmap_fifo_data_valid_i,
	
	output reg tap_data_valid_o,
	input  [DATA_WIDTH-1:0]shift_data_in_i,
	output reg [TAP_NUMBER*DATA_WIDTH-1:0]tap_data_o
);

localparam	SHIFT_REG_COLUMN 	= 5;
localparam 	DILATION_NONE 		= 2'b00,
			DILATION_2			= 2'b01,
			DILATION_4			= 2'b10;
integer i, j;

reg [DATA_WIDTH-1:0]shift_ram_regs[TAP_NUMBER-1:0][SHIFT_REG_COLUMN-1:0];

wire s_shift_ram_en;
assign s_shift_ram_en = en && ifmap_fifo_data_valid_i;

reg r_shift_ram_en;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_shift_ram_en <= 1'b0;
	end
	else if(clear) begin
		r_shift_ram_en <= 1'b0;
	end
	else begin
		r_shift_ram_en <= s_shift_ram_en;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i = 0; i < TAP_NUMBER; i = i + 1) begin
			for(j = 0; j < SHIFT_REG_COLUMN; j = j + 1) begin
				shift_ram_regs[i][j] = 0;
			end
		end
	end
	else if(clear) begin
		for(i = 0; i < TAP_NUMBER; i = i + 1) begin
			for(j = 0; j < SHIFT_REG_COLUMN; j = j + 1) begin
				shift_ram_regs[i][j] = 0;
			end
		end
	end
	else if(en) begin
		shift_ram_regs[0][0] <= shift_data_in_i;
		case(dilation_sel_i)
			DILATION_NONE: begin
				shift_ram_regs[1][0] <= shift_ram_regs[0][0];
				shift_ram_regs[2][0] <= shift_ram_regs[1][0];
			end
			DILATION_2: begin
				shift_ram_regs[1][0] <= shift_ram_regs[0][2];
				shift_ram_regs[2][0] <= shift_ram_regs[1][2];
			end
			DILATION_4: begin
				shift_ram_regs[1][0] <= shift_ram_regs[0][4];
				shift_ram_regs[2][0] <= shift_ram_regs[1][4];
			end
		endcase
		for(i = 0; i < TAP_NUMBER; i = i + 1) begin
			for(j = 1; j < SHIFT_REG_COLUMN; j = j + 1) begin
				shift_ram_regs[i][j] <= shift_ram_regs[i][j-1];
			end
		end
	end
end

reg [3:0]shift_cnt;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		shift_cnt <= 4'd0;
	end
	else if(clear) begin
		shift_cnt <= 4'd0;
	end
	else if(r_shift_ram_en) begin
		if(shift_cnt < TAP_NUMBER * SHIFT_REG_COLUMN) begin
			shift_cnt <= shift_cnt + 4'd1;
		end
	end
end

always @(*) begin
	case(dilation_sel_i)
		DILATION_NONE: begin
			tap_data_o[DATA_WIDTH*1-1-:DATA_WIDTH] = shift_ram_regs[0][0];
			tap_data_o[DATA_WIDTH*2-1-:DATA_WIDTH] = shift_ram_regs[1][0];
			tap_data_o[DATA_WIDTH*3-1-:DATA_WIDTH] = shift_ram_regs[2][0];
		end
		DILATION_2: begin
			tap_data_o[DATA_WIDTH*1-1-:DATA_WIDTH] = shift_ram_regs[0][2];
			tap_data_o[DATA_WIDTH*2-1-:DATA_WIDTH] = shift_ram_regs[1][2];
			tap_data_o[DATA_WIDTH*3-1-:DATA_WIDTH] = shift_ram_regs[2][2];
		end
		DILATION_4: begin
			tap_data_o[DATA_WIDTH*1-1-:DATA_WIDTH] = shift_ram_regs[0][4];
			tap_data_o[DATA_WIDTH*2-1-:DATA_WIDTH] = shift_ram_regs[1][4];
			tap_data_o[DATA_WIDTH*3-1-:DATA_WIDTH] = shift_ram_regs[2][4];
		end
		default: begin
			tap_data_o[DATA_WIDTH*1-1:0] = {DATA_WIDTH{1'b0}};
			tap_data_o[DATA_WIDTH*2-1:0] = {DATA_WIDTH{1'b0}};
			tap_data_o[DATA_WIDTH*3-1:0] = {DATA_WIDTH{1'b0}};
		end
	endcase
end

always @(*) begin
	case(dilation_sel_i)
		DILATION_NONE: begin
			if(shift_cnt >= TAP_NUMBER*1-1) begin
				tap_data_valid_o = 1'b1;
			end
			else begin
				tap_data_valid_o = 1'b0;
			end
		end
		DILATION_2: begin
			if(shift_cnt >= TAP_NUMBER*3-1) begin
				tap_data_valid_o = 1'b1;
			end
			else begin
				tap_data_valid_o = 1'b0;
			end
		end
		DILATION_4: begin
			if(shift_cnt >= TAP_NUMBER*5-1) begin
				tap_data_valid_o = 1'b1;
			end
			else begin
				tap_data_valid_o = 1'b0;
			end
		end
		default: tap_data_valid_o = 1'b0;
	endcase
end

endmodule

