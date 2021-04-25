`timescale 1ns / 1ps

module sync_fifo_docker
#(
	parameter DATA_WIDTH = 16,
	parameter BUF_SIZE = 784
)
(
	input clk,
	input rst_n,
	input clear,
	
	input [DATA_WIDTH-1:0]fifo_din,
	input fifo_wr_en,
	input fifo_rd_en,
	input fifo_rd_rewind,
	output fifo_empty,
	output fifo_full,
	output [DATA_WIDTH-1:0]fifo_out,
	
	output mem_rd_en_o,
	output [clogb2(BUF_SIZE)-1:0]mem_rd_addr_o,
	input  [DATA_WIDTH-1:0]mem_rd_data_i,
	output mem_wr_en_o,
	output [clogb2(BUF_SIZE)-1:0]mem_wr_addr_o,
	output [DATA_WIDTH-1:0]mem_wr_data_o
);

function integer clogb2 (input integer bit_depth);

for(clogb2=0; bit_depth>0; clogb2=clogb2+1) begin
	bit_depth = bit_depth >> 1;
end

endfunction
	
localparam CNT_BIT_NUM = clogb2(BUF_SIZE);

reg [CNT_BIT_NUM-1:0] fifo_rd_addr, fifo_wr_addr;
reg [CNT_BIT_NUM-1:0] fifo_cnt;
reg [CNT_BIT_NUM-1:0] buf_cnt;

reg r_fifo_rd_en;
reg r_fifo_empty;

assign fifo_empty = (fifo_cnt == 0); 
assign fifo_full  = (fifo_cnt == BUF_SIZE);
assign mem_wr_en_o = (fifo_wr_en && !fifo_full) ? 1 : 0;
assign mem_wr_addr_o = fifo_wr_addr;
assign mem_wr_data_o = fifo_din;
assign mem_rd_en_o = (!fifo_empty && fifo_rd_en);
assign mem_rd_addr_o = fifo_rd_addr;
assign fifo_out = mem_rd_data_i;

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_fifo_empty <= 0;
	end
	else begin
		r_fifo_empty <= fifo_empty;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		r_fifo_rd_en <= 0;
	end
	else begin
		r_fifo_rd_en <= fifo_rd_en;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		fifo_cnt <= 0;
	end
	else if(clear) begin
		fifo_cnt <= 0;
	end
	else begin
		if(fifo_rd_rewind) begin
			fifo_cnt <= buf_cnt;
		end
		else if((!fifo_full && fifo_wr_en) && (!fifo_empty && fifo_rd_en)) begin
			fifo_cnt <= fifo_cnt;
		end
		else if(!fifo_empty && fifo_rd_en) begin
			fifo_cnt <= fifo_cnt - 1;
		end
		else if(!fifo_full && fifo_wr_en) begin
			fifo_cnt <= fifo_cnt + 1;
		end
	end
end
	
always @(posedge clk or negedge rst_n) begin 
	if(!rst_n) begin
		fifo_wr_addr <= 0;
	end
	else if(clear) begin
		fifo_wr_addr <= 0;
	end
	else if(!fifo_full && fifo_wr_en) begin
		if(fifo_wr_addr == BUF_SIZE - 1) begin
			fifo_wr_addr <= 0;
		end
		else begin
			fifo_wr_addr <= fifo_wr_addr + 1;
		end
	end
end
	
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		fifo_rd_addr <= 0;
	end
	else if(clear) begin
		fifo_rd_addr <= 0;
	end
	else if(fifo_rd_rewind) begin
		fifo_rd_addr <= 0; 
	end
	else if(!fifo_empty && fifo_rd_en) begin
		if(fifo_rd_addr == BUF_SIZE - 1) begin
			fifo_rd_addr <= 0;
		end
		else begin
			fifo_rd_addr <= fifo_rd_addr + 1;
		end
	end
end
			
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		buf_cnt <= 0;
	end
	else if(clear) begin
		buf_cnt <= 0;
	end
	else if(buf_cnt < BUF_SIZE - 1 && fifo_wr_en) begin   
		buf_cnt <= buf_cnt + 1;
	end
end
	
endmodule

module sync_bram_fifo
#(
	parameter DATA_WIDTH = 16,
	parameter BUF_SIZE = 784
)
(
	input clk,
	input rst_n,
	input clear,
	
	input [DATA_WIDTH-1:0]fifo_din,
	input fifo_wr_en,
	input fifo_rd_en,
	input fifo_rd_rewind,
	output fifo_empty,
	output fifo_full,
	output [DATA_WIDTH-1:0]fifo_out
);

function integer clogb2 (input integer bit_depth);

for(clogb2=0; bit_depth>0; clogb2=clogb2+1) begin
	bit_depth = bit_depth >> 1;
end
	
endfunction

wire w_bram_rd_en;
wire [clogb2(BUF_SIZE)-1:0]w_bram_rd_addr;
wire [DATA_WIDTH-1:0]w_bram_rd_data;
wire w_bram_wr_en;
wire [clogb2(BUF_SIZE)-1:0]w_bram_wr_addr;
wire [DATA_WIDTH-1:0]w_bram_wr_data;

sync_fifo_docker
#(
	.DATA_WIDTH(DATA_WIDTH),
	.BUF_SIZE(BUF_SIZE)
)
u_sync_fifo_docker
(
	.clk(clk),
	.rst_n(rst_n),
	.clear(clear),

	.fifo_din(fifo_din),
	.fifo_wr_en(fifo_wr_en),
	.fifo_rd_en(fifo_rd_en),
	.fifo_rd_rewind(fifo_rd_rewind),
	.fifo_empty(fifo_empty),
	.fifo_full(fifo_full),
	.fifo_out(fifo_out),

	.mem_rd_en_o(w_bram_rd_en),
	.mem_rd_addr_o(w_bram_rd_addr),
	.mem_rd_data_i(w_bram_rd_data),
	.mem_wr_en_o(w_bram_wr_en),
	.mem_wr_addr_o(w_bram_wr_addr),
	.mem_wr_data_o(w_bram_wr_data)
);

block_ram_simple_dual_port
#(
	.DATA_WIDTH(DATA_WIDTH),
	.DATA_DEPTH(BUF_SIZE)
)
u_block_ram
(
	/*write port*/
	.clka(clk),                          
	.ena(w_bram_wr_en),                           
	.addra(w_bram_wr_addr), 
	.dina(w_bram_wr_data),          

	/*read port*/						   
	.clkb(clk),                          
	.enb(w_bram_rd_en),                           
	.addrb(w_bram_rd_addr), 
	.doutb(w_bram_rd_data)          
);
	
endmodule

module simple_distributed_fifo
#(
	parameter DATA_WIDTH = 16,
	parameter FIFO_DEPTH_SIZE = 4
)
(
	input clk,
	input rst_n,
	
	input [DATA_WIDTH-1:0]fifo_din_i,
	input fifo_wr_en_i,
	input fifo_rd_en_i,
	
	output fifo_empty_o,
	output fifo_full_o,
	output reg [DATA_WIDTH-1:0]fifo_out_o
);

localparam FIFO_DEPTH = 8'b0000_0001 << FIFO_DEPTH_SIZE;

reg [DATA_WIDTH-1:0]fifo_buf[FIFO_DEPTH-1:0];
reg [FIFO_DEPTH_SIZE-1:0]fifo_rd_cnt;
reg [FIFO_DEPTH_SIZE-1:0]fifo_wr_cnt;
wire w_fifo_full_1dff;

 initial begin: initialize_ram
	integer i;
	for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
		fifo_buf[i] = {DATA_WIDTH {1'b0} };
//			ram[i] = i;
	end
end

assign fifo_empty_o = (fifo_rd_cnt == fifo_wr_cnt) ? 1 : 0;
assign fifo_full_o = (fifo_rd_cnt == fifo_wr_cnt + 1'b1) ? 1 : 0;

always @(posedge clk or negedge rst_n) begin 
	if(!rst_n) begin
		fifo_wr_cnt <= 0;
	end
	else if(!fifo_full_o && fifo_wr_en_i) begin
		fifo_wr_cnt <= fifo_wr_cnt + 1;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		fifo_rd_cnt <= 0;
	end
	else if(!fifo_empty_o && fifo_rd_en_i) begin
		fifo_rd_cnt <= fifo_rd_cnt + 1;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		fifo_out_o <= 0;
	end
	else if(fifo_rd_en_i) begin
		fifo_out_o <= fifo_buf[fifo_rd_cnt];
	end
end

always @(posedge clk) begin
	if(fifo_wr_en_i && !w_fifo_full_1dff) begin
		fifo_buf[fifo_wr_cnt] <= fifo_din_i;
	end
end

	
dff_stages
#(
	.DATA_WIDTH(1),
	.STAGE(1)
) 
u_fifo_full_wr_stages
(
	.clk(clk),
	.rst_n(rst_n),
	
	.stage_in(fifo_full_o),
	.stage_out(w_fifo_full_1dff)
);

endmodule
