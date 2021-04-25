`timescale 1ns / 1ps

module rx_bps_ctrl
#(
	parameter UART_CLK_MHZ = 50
)
(
	input  clk,
	input  rst_n,
	input  en,
	input  [2:0]baud_sel,
	output reg [9:0]bps_para_nclk
);

function integer clogb2 (input integer bit_depth);

for(clogb2 = 0; bit_depth > 0; clogb2 = clogb2 + 1) begin
	bit_depth = bit_depth >> 1;
end

endfunction

localparam	BPS9600_NCLK 	= 1000000 * UART_CLK_MHZ / 9600 / 9 - 1,
			BPS19200_NCLK 	= 1000000 * UART_CLK_MHZ / 19200 / 9 - 1,
			BPS38400_NCLK 	= 1000000 * UART_CLK_MHZ / 38400 / 9 - 1,
			BPS57600_NCLK 	= 1000000 * UART_CLK_MHZ / 57600 / 9 - 1,
			BPS115200_NCLK	= 1000000 * UART_CLK_MHZ / 115200 / 9 - 1,
			BPS230400_NCLK	= 1000000 * UART_CLK_MHZ / 230400 / 9 - 1,
			BPS460800_NCLK	= 1000000 * UART_CLK_MHZ / 460800 / 9 - 1,
			BPS921600_NCLK	= 1000000 * UART_CLK_MHZ / 921600 / 9 - 1;
			
reg [2:0] r_baud_ctrl;

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_baud_ctrl <= 3'd0;
	end
	else if(en) begin
		r_baud_ctrl <= baud_sel;
	end
end

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin 
			bps_para_nclk <= 3'd0;
		end
	else begin
		case (r_baud_ctrl)
			3'd0: bps_para_nclk <= BPS9600_NCLK;
			3'd1: bps_para_nclk <= BPS19200_NCLK;
			3'd2: bps_para_nclk <= BPS38400_NCLK;
			3'd3: bps_para_nclk <= BPS57600_NCLK;
			3'd4: bps_para_nclk <= BPS115200_NCLK;
			3'd5: bps_para_nclk <= BPS230400_NCLK;
			3'd6: bps_para_nclk <= BPS460800_NCLK;
			3'd7: bps_para_nclk <= BPS921600_NCLK;
			default: bps_para_nclk <= BPS9600_NCLK;
		endcase
	end
end

endmodule

module sample_clk_gen
#(
	parameter UART_CLK_MHZ = 50
)
(
	input  clk,
	input  rst_n,
	input  sample_clk_en,
	input  [9:0]rx_sample_nclk,
	output reg rx_sample_clk
);

reg [9:0]bps_period_cnt;
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		bps_period_cnt <= 10'd0;
	end
	else if(sample_clk_en) begin
		if(bps_period_cnt == rx_sample_nclk) begin
			bps_period_cnt <= 10'd0;
		end	
		else begin
			bps_period_cnt <= bps_period_cnt + 1'b1;
		end
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rx_sample_clk <= 1'b0;
	end
	else if(bps_period_cnt == 1'd1) begin
		rx_sample_clk <= 1'b1;
	end
	else begin
		rx_sample_clk <= 1'b0;
	end
end

endmodule

module uart_rx
#(
	parameter UART_CLK_MHZ = 50
)
(
	input  clk,
	input  rst_n,
	input  [2:0]baud_sel_i,
	input  rs232_rx_data_i,
	output reg [7:0]rs232_rx_data_o,
	output rs232_rx_int
);

wire neg_rs232_rx;
edge_capture #(1) u_rx_falling_edge_capture(clk, rst_n, rs232_rx_data_i, neg_rs232_rx);

reg sample_clk_en; 
wire sample_clk;
reg [6:0]sample_clk_cnt;

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		sample_clk_en <= 0;
	end
	else if(neg_rs232_rx) begin
		sample_clk_en <= 1;
	end
	else if(sample_clk_cnt == 89) begin
		sample_clk_en <= 0;
	end
end

wire  [9:0]rx_sample_nclk;

rx_bps_ctrl
#(
	.UART_CLK_MHZ(UART_CLK_MHZ)

)
u_rx_bps_ctrl
(
	.clk(clk),
	.rst_n(rst_n),
	.en(sample_clk_en),
	.baud_sel(baud_sel_i),
	.bps_para_nclk(rx_sample_nclk)
);

sample_clk_gen
#(
	.UART_CLK_MHZ(UART_CLK_MHZ)
)
u_sample_clk_gen
(
	.clk(clk),
	.rst_n(rst_n),
	.sample_clk_en(sample_clk_en),
	.rx_sample_nclk(rx_sample_nclk),
	.rx_sample_clk(sample_clk)
);

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		sample_clk_cnt <= 7'b0;
	end
	else if(sample_clk_en == 0) begin
		sample_clk_cnt <= 7'd0;
	end
	else if(sample_clk_cnt == 7'd89) begin
		sample_clk_cnt <= 0;
	end
	else if(sample_clk) begin
		sample_clk_cnt <= sample_clk_cnt + 1'b1;
	end
end

reg [1:0]rs232_rx_bits[9:0];

integer i;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		for(i = 0; i < 10; i = i + 1) begin
			rs232_rx_bits[i] <= 2'b00;
		end
	end
	else if(sample_clk) begin
		case(sample_clk_cnt)
			7'd0: begin
				for(i = 0; i < 10; i = i + 1) begin
					rs232_rx_bits[i] <= 2'b00;
				end
			end
			7'd3,  7'd4,  7'd5:  rs232_rx_bits[0] <= rs232_rx_bits[0] + rs232_rx_data_i;
			7'd12, 7'd13, 7'd14: rs232_rx_bits[1] <= rs232_rx_bits[1] + rs232_rx_data_i;
			7'd21, 7'd22, 7'd23: rs232_rx_bits[2] <= rs232_rx_bits[2] + rs232_rx_data_i;
			7'd30, 7'd31, 7'd32: rs232_rx_bits[3] <= rs232_rx_bits[3] + rs232_rx_data_i;
			7'd39, 7'd40, 7'd41: rs232_rx_bits[4] <= rs232_rx_bits[4] + rs232_rx_data_i;
			7'd48, 7'd49, 7'd50: rs232_rx_bits[5] <= rs232_rx_bits[5] + rs232_rx_data_i;
			7'd57, 7'd58, 7'd59: rs232_rx_bits[6] <= rs232_rx_bits[6] + rs232_rx_data_i;
			7'd66, 7'd67, 7'd68: rs232_rx_bits[7] <= rs232_rx_bits[7] + rs232_rx_data_i;
			7'd75, 7'd76, 7'd77: rs232_rx_bits[8] <= rs232_rx_bits[8] + rs232_rx_data_i;
			7'd84, 7'd85, 7'd86: rs232_rx_bits[9] <= rs232_rx_bits[9] + rs232_rx_data_i;
			default:;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rs232_rx_data_o <= 8'b0; 
	end
	else if(sample_clk_cnt == 7'd89) begin
		for(i = 0; i < 8; i = i + 1) begin
			rs232_rx_data_o[i] <= rs232_rx_bits[i+1][1];
		end
	end
end

reg r_rs232_rx_int;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_rs232_rx_int <= 0;
	end
	else if(sample_clk_cnt == 7'd89) begin
		r_rs232_rx_int <= 1'b1;
	end
	else begin
		r_rs232_rx_int <= 1'b0;
	end
end

assign rs232_rx_int = r_rs232_rx_int;

endmodule
