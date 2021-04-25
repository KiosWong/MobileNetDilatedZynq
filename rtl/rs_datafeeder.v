`timescale 1ns / 1ps

/**
 * row-stationary data feed logic
 * 
 *
 *
 *
 */
module rs_datafeeder
#(
	parameter DATA_WIDTH = 8,
	parameter KERNEL_SIZE = 3
)
(
	input  clk,
	input  rst_n,
	input  en,
	input  clear,
	
	input  mode_sel_i,
	input  [1:0]dilation_sel_i,
	
	output [KERNEL_SIZE-1:0]ifmap_fifo_data_req_o,
	input  [KERNEL_SIZE-1:0]ifmap_fifo_data_valid_i,
	input  [KERNEL_SIZE*DATA_WIDTH-1:0]ifmap_fifo_data_i,
	output reg window_data_valid_o,
	output reg [KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH-1:0]window_data_o
);

localparam 	MODE_NORMAL_CONV 	= 1'b0,
			MODE_PW_CONV 		= 1'b1;
			
localparam 	DILATION_NONE 		= 2'b00,
			DILATION_2			= 2'b01,
			DILATION_4			= 2'b10;

integer i, j;
genvar k;

reg [DATA_WIDTH-1:0]r_window_data_regs[KERNEL_SIZE-1:0][KERNEL_SIZE-1:0];

wire [2:0]w_shift_line_data_valid;
wire [DATA_WIDTH*KERNEL_SIZE-1:0]w_tap_data[2:0];
wire s_shift_ram_data_valid;
generate 
	for(k = 0; k < KERNEL_SIZE; k = k + 1) begin: multi_line_shift_ram
		dilated_shift_ram u_dilated_shift_ram
		(
			.clk(clk),
			.rst_n(rst_n),
			.en(en),
			.clear(clear),
			
			.dilation_sel_i(dilation_sel_i),
			.ifmap_fifo_data_valid_i(ifmap_fifo_data_valid_i[k]),
		
			.tap_data_valid_o(w_shift_line_data_valid[k]),
			.shift_data_in_i(ifmap_fifo_data_i[(k+1)*DATA_WIDTH-1-:DATA_WIDTH]),
			.tap_data_o(w_tap_data[k])
		);
	end
endgenerate
assign s_shift_ram_data_valid = (w_shift_line_data_valid[0] & w_shift_line_data_valid[1] & w_shift_line_data_valid[2]);

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i = 0; i < KERNEL_SIZE; i = i + 1) begin
			for(j = 0; j < KERNEL_SIZE; j = j + 1) begin
				r_window_data_regs[i][j] <= {KERNEL_SIZE{1'd0}};
			end
		end
	end
	else if(clear) begin
		for(i = 0; i < KERNEL_SIZE; i = i + 1) begin
			for(j = 0; j < KERNEL_SIZE; j = j + 1) begin
				r_window_data_regs[i][j] <= {KERNEL_SIZE{1'd0}};
			end
		end
	end
	else if(ifmap_fifo_data_valid_i[0]) begin
		case(mode_sel_i)
			MODE_NORMAL_CONV: begin
				r_window_data_regs[0][0] <= w_tap_data[0][(0+1)*DATA_WIDTH-1-:DATA_WIDTH];
				r_window_data_regs[0][1] <= w_tap_data[0][(1+1)*DATA_WIDTH-1-:DATA_WIDTH];
				r_window_data_regs[0][2] <= w_tap_data[0][(2+1)*DATA_WIDTH-1-:DATA_WIDTH];
				r_window_data_regs[1][0] <= w_tap_data[1][(0+1)*DATA_WIDTH-1-:DATA_WIDTH];
				r_window_data_regs[1][1] <= w_tap_data[1][(1+1)*DATA_WIDTH-1-:DATA_WIDTH];
				r_window_data_regs[1][2] <= w_tap_data[1][(2+1)*DATA_WIDTH-1-:DATA_WIDTH];
				r_window_data_regs[2][0] <= w_tap_data[2][(0+1)*DATA_WIDTH-1-:DATA_WIDTH];
				r_window_data_regs[2][1] <= w_tap_data[2][(1+1)*DATA_WIDTH-1-:DATA_WIDTH];
				r_window_data_regs[2][2] <= w_tap_data[2][(2+1)*DATA_WIDTH-1-:DATA_WIDTH];
			end
			MODE_PW_CONV: begin
				for(i = 0; i < KERNEL_SIZE; i = i + 1) begin
					for(j = 0; j < KERNEL_SIZE; j = j + 1) begin
						r_window_data_regs[i][j] <= ifmap_fifo_data_i[(0+1)*DATA_WIDTH-1-:DATA_WIDTH];
					end
				end
			end
			default:;
		endcase
	end
end

always @(*) begin
	for(i = 0; i < KERNEL_SIZE; i = i + 1) begin
		for(j = 0; j < KERNEL_SIZE; j = j + 1) begin
			window_data_o[(i*KERNEL_SIZE+j+1)*DATA_WIDTH-1-:DATA_WIDTH] = r_window_data_regs[i][j];
		end
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		window_data_valid_o <= 1'b0;
	end
	else if(clear) begin
		window_data_valid_o <= 1'b0;
	end
	else if(mode_sel_i == MODE_NORMAL_CONV) begin
		window_data_valid_o <= s_shift_ram_data_valid;
	end
	else begin
		window_data_valid_o <= (en && ifmap_fifo_data_valid_i[0]) ? 1'b1 : 0;
	end
end

endmodule
