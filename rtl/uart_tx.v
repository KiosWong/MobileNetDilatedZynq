`timescale 1ns / 1ps

module tx_bps_ctrl
#(
	parameter UART_CLK_MHZ = 50
)
(
	input  clk,
	input  rst_n,
	input  en,
	input  [2:0]baud_sel,
	output reg [12:0]bps_para_nclk
);

function integer clogb2 (input integer bit_depth);

for(clogb2 = 0; bit_depth > 0; clogb2 = clogb2 + 1) begin
	bit_depth = bit_depth >> 1;
end

endfunction

localparam	BPS9600_NCLK 	= 1000000 * UART_CLK_MHZ / 9600 - 1,
			BPS19200_NCLK 	= 1000000 * UART_CLK_MHZ / 19200 - 1,
			BPS38400_NCLK 	= 1000000 * UART_CLK_MHZ / 38400 - 1,
			BPS57600_NCLK 	= 1000000 * UART_CLK_MHZ / 57600 - 1,
			BPS115200_NCLK	= 1000000 * UART_CLK_MHZ / 115200 - 1,
			BPS230400_NCLK	= 1000000 * UART_CLK_MHZ / 230400 - 1,
			BPS460800_NCLK	= 1000000 * UART_CLK_MHZ / 460800 - 1,
			BPS921600_NCLK	= 1000000 * UART_CLK_MHZ / 921600 - 1;
			
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
		bps_para_nclk <= 12'b0;
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


module tx_bps_clk_gen
#(
	parameter UART_CLK_MHZ = 50
)
(
	input  clk,
	input  rst_n,
	input  bps_clk_en,
	input  [12:0]tx_bps_nclk,
	output reg tx_bps_clk
);

reg [12:0]bps_period_cnt;
always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		bps_period_cnt <= 12'd0;
	end
	else if(bps_clk_en) begin
		if(bps_period_cnt == tx_bps_nclk) begin
			bps_period_cnt <= 12'd0;
		end	
		else begin
			bps_period_cnt <= bps_period_cnt + 1'b1;
		end
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		tx_bps_clk <= 1'b0;
	end
	else if(bps_period_cnt == 1'd1) begin
		tx_bps_clk <= 1'b1;
	end
	else begin
		tx_bps_clk <= 1'b0;
	end
end

endmodule

module uart_tx
#(
	parameter UART_CLK_MHZ = 50
)
(
	input  clk,
	input  rst_n,
	input  [2:0]baud_sel_i,
	input  rs232_tx_start,
	input  [7:0]rs232_tx_data_i,
	output reg rs232_tx_int,
	output reg rs232_tx_o
);

reg rs232_tx_en;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rs232_tx_en <= 0;
	end
	else if(rs232_tx_int) begin
		rs232_tx_en <= 0;
	end
	else if(rs232_tx_start) begin
		rs232_tx_en <= 1;
	end
end

wire [12:0]tx_bps_nclk;
wire tx_bps_clk;

tx_bps_ctrl
#(
	.UART_CLK_MHZ(UART_CLK_MHZ)
)
u_tx_bps_ctrl
(
	.clk(clk),
	.rst_n(rst_n),
	.en(rs232_tx_en),
	.baud_sel(baud_sel_i),
	.bps_para_nclk(tx_bps_nclk)
);

tx_bps_clk_gen
#(
	.UART_CLK_MHZ(UART_CLK_MHZ)
)
u_tx_bps_clk_gen
(
	.clk(clk),
	.rst_n(rst_n),
	.bps_clk_en(rs232_tx_en),
	.tx_bps_nclk(tx_bps_nclk),
	.tx_bps_clk(tx_bps_clk)
);

reg [4:0]bps_clk_cnt;
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		bps_clk_cnt <= 4'b0;
	end
	else if(bps_clk_cnt == 4'd11) begin
		bps_clk_cnt <= 4'b0;
	end
	else if(tx_bps_clk) begin
		bps_clk_cnt <= bps_clk_cnt + 1'b1;
	end
	else begin
		bps_clk_cnt <= bps_clk_cnt;
	end
end

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rs232_tx_int <= 1'b0;
	end
	else if(bps_clk_cnt == 4'd11) begin
		rs232_tx_int <= 1'b1;
	end
	else begin
		rs232_tx_int <= 1'b0;
	end
end

reg [7:0]rs232_tx_data_r;
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		rs232_tx_data_r = 8'd0;
	end
	else if(tx_bps_clk & bps_clk_cnt == 4'd1) begin
		rs232_tx_data_r <= rs232_tx_data_i;
	end
end
  
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)  
		rs232_tx_o <= 1'b1;
	else begin
		case(bps_clk_cnt)
			4'd1: rs232_tx_o <= 1'b0;
			4'd2: rs232_tx_o <= rs232_tx_data_r[0];
			4'd3: rs232_tx_o <= rs232_tx_data_r[1];
			4'd4: rs232_tx_o <= rs232_tx_data_r[2];  
			4'd5: rs232_tx_o <= rs232_tx_data_r[3];
			4'd6: rs232_tx_o <= rs232_tx_data_r[4];
			4'd7: rs232_tx_o <= rs232_tx_data_r[5];
			4'd8: rs232_tx_o <= rs232_tx_data_r[6];
			4'd9: rs232_tx_o <= rs232_tx_data_r[7];
			4'd10: rs232_tx_o <= 1'b1;
			default:rs232_tx_o <= 1'b1;
		endcase
	end
end

endmodule
