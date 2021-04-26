
module conv2d_uart_wrapper
(
	input  clk,
	input  rst_n,
	input  clear,
	
	input  rs232_rx_data_i,
	output rs232_tx_data_o	
);

wire [7:0]w_uart_rx_data;
wire w_rs232_rx_int;
wire w_rs232_tx_int;
wire sys_clear;
assign sys_clear = ~clear;

uart_rx
#(
	.UART_CLK_MHZ(50)
)
u_uart_rx
(
	.clk(clk),
	.rst_n(rst_n),
	.baud_sel_i(3'd7),
	.rs232_rx_data_i(rs232_rx_data_i),
	.rs232_rx_data_o(w_uart_rx_data),
	.rs232_rx_int(w_rs232_rx_int)
);

reg [10:0]uart_rx_cnt;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		uart_rx_cnt <= 11'd0;
	end
	else if(sys_clear) begin
		uart_rx_cnt <= 11'd0;
	end
	else if(w_rs232_rx_int) begin
		uart_rx_cnt <= uart_rx_cnt + 11'd1;
	end
end
wire s_conv_en;
reg  s_ofmap_fifo_rd_en;
wire w_ofmap_fifo_data_valid;
wire [31:0]w_ofmap_fifo_data_out;

assign s_conv_en = (uart_rx_cnt == 1033) ? 1 : 0;

reg [3*3*8-1:0]r_filter_data;

integer i;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_filter_data <= 72'd0;
	end
	else if(sys_clear) begin
		r_filter_data <= 72'd0;
	end
	else if(uart_rx_cnt > 1023 && w_rs232_rx_int) begin
		r_filter_data[(uart_rx_cnt-1023)*8-1-:8] <= w_uart_rx_data;
	end
end

wire s_ifmap_fifo_wr_en;

assign s_ifmap_fifo_wr_en = ((uart_rx_cnt < 1024) && w_rs232_rx_int) ? 1 : 0;

conv2d_top
#(
	.IFMAP_DATA_WIDTH(8),
	.OFMAP_DATA_WIDTH(32)
)
u_conv2d_top
(
	.clk(clk),
	.rst_n(rst_n),
	.en(s_conv_en),
	.clear(sys_clear),
	
	.kernel_data_reorder_i(1),
	
	.ifmap_fifo_wr_en_i(s_ifmap_fifo_wr_en),
	.ifmap_fifo_data_i(w_uart_rx_data),
	.filter_data_i(r_filter_data),
	.ofmap_fifo_rd_en_i(s_ofmap_fifo_rd_en),
	.ofmap_fifo_data_valid(w_ofmap_fifo_data_valid),
	.ofmap_fifo_data_o(w_ofmap_fifo_data_out)
);

/* uart tx fsm */
localparam 	UART_TX_IDLE		= 6'b0000_00,
			UART_TX_RD			= 6'b0000_01,
			UART_TX_BYTE_1		= 6'b0000_10,
			UART_TX_BYTE_2		= 6'b0001_00,
			UART_TX_BYTE_3		= 6'b0010_00,
			UART_TX_BYTE_4		= 6'b0100_00,
			UART_TX_DONE		= 6'b1000_00;

reg [5:0]uart_tx_c_state;
reg [5:0]uart_tx_n_state;

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		uart_tx_n_state <= 6'b0;
	end
	else begin
		case(uart_tx_c_state)
			UART_TX_IDLE: begin
				if(w_ofmap_fifo_data_valid) begin
					uart_tx_n_state = UART_TX_RD;
				end
				else begin
					uart_tx_n_state <= uart_tx_n_state;
				end
			end
			/* handle 1 clk fifo read latency */
			UART_TX_RD: uart_tx_n_state <= UART_TX_BYTE_1;
			UART_TX_BYTE_1: begin
				if(w_rs232_tx_int) begin
					uart_tx_n_state <= UART_TX_BYTE_2;
				end
				else begin
					uart_tx_n_state <= uart_tx_n_state;
				end
			end
			UART_TX_BYTE_2: begin
				if(w_rs232_tx_int) begin
					uart_tx_n_state <= UART_TX_BYTE_3;
				end
				else begin
					uart_tx_n_state <= uart_tx_n_state;
				end
			end
			UART_TX_BYTE_3: begin
				if(w_rs232_tx_int) begin
					uart_tx_n_state <= UART_TX_BYTE_4;
				end
				else begin
					uart_tx_n_state <= uart_tx_n_state;
				end
			end
			UART_TX_BYTE_4: begin
				if(w_rs232_tx_int) begin
					uart_tx_n_state <= UART_TX_DONE;
				end
				else begin
					uart_tx_n_state <= uart_tx_n_state;
				end
			end
			UART_TX_DONE: uart_tx_n_state <= UART_TX_IDLE;
			default: uart_tx_n_state <= UART_TX_IDLE;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		uart_tx_c_state <= 6'b0;
	end
	else begin
		uart_tx_c_state <= uart_tx_n_state;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		s_ofmap_fifo_rd_en <= 1'b0;
	end
	else if(uart_tx_c_state == UART_TX_IDLE && w_ofmap_fifo_data_valid) begin
		s_ofmap_fifo_rd_en <= 1'b1;
	end
	else begin
		s_ofmap_fifo_rd_en <= 1'b0;
	end
end

reg [31:0]r_ofmap_fifo_data_out;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_ofmap_fifo_data_out <= 32'b0;
	end
	else if(uart_tx_c_state == UART_TX_RD) begin
		r_ofmap_fifo_data_out <= w_ofmap_fifo_data_out;
	end
end

reg s_uart_tx_start;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		s_uart_tx_start <= 1'b0;
	end
	else if((uart_tx_n_state == UART_TX_BYTE_1 && uart_tx_c_state == UART_TX_RD) || (uart_tx_n_state == UART_TX_BYTE_2 && uart_tx_c_state == UART_TX_BYTE_1) || (uart_tx_n_state == UART_TX_BYTE_3 && uart_tx_c_state == UART_TX_BYTE_2) || (uart_tx_n_state == UART_TX_BYTE_4 && uart_tx_c_state == UART_TX_BYTE_3)) begin
		s_uart_tx_start <= 1'b1;
	end
	else begin
		s_uart_tx_start <= 1'b0;
	end
end

reg r_uart_tx_start;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_uart_tx_start <= 1'b0;
	end
	else begin
		r_uart_tx_start <= s_uart_tx_start;
	end
end

reg [7:0]r_uart_tx_data;
always @(*) begin
	if(uart_tx_c_state == UART_TX_BYTE_1) begin
		r_uart_tx_data = r_ofmap_fifo_data_out[31:24];
	end
	else if(uart_tx_c_state == UART_TX_BYTE_2) begin
		r_uart_tx_data = r_ofmap_fifo_data_out[23:16];
	end
	else if(uart_tx_c_state == UART_TX_BYTE_3) begin
		r_uart_tx_data = r_ofmap_fifo_data_out[15:8];
	end
	else if(uart_tx_c_state == UART_TX_BYTE_4) begin
		r_uart_tx_data = r_ofmap_fifo_data_out[7:0];
	end
	else begin
		r_uart_tx_data = 8'b0;
	end
end

uart_tx
#(
	.UART_CLK_MHZ(50)
)
u_uart_tx
(
	.clk(clk),
	.rst_n(rst_n),
	.baud_sel_i(4'd7),	
	.rs232_tx_start(r_uart_tx_start),
	.rs232_tx_data_i(r_uart_tx_data),
	.rs232_tx_int(w_rs232_tx_int),
	.rs232_tx_o(rs232_tx_data_o)
);

//ila_0 sys_ila (
//	.clk(clk), // input wire clk


//	.probe0(w_rs232_rx_int), // input wire [0:0]  probe0  
//	.probe1(w_uart_rx_data), // input wire [7:0]  probe1 
//	.probe2(clear), // input wire [0:0]  probe2 
//	.probe3(uart_rx_cnt) // input wire [31:0]  probe3
//);


endmodule
