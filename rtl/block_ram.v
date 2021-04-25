`timescale 1ns / 1ps

module block_ram_simple_dual_port
#(
	parameter DATA_WIDTH = 32,
	parameter DATA_DEPTH = 256
)
(
	input  clka,
	input  ena,
	input  [clogb2(DATA_DEPTH)-1:0]addra,
	input  [DATA_WIDTH-1:0]dina,
	
	input  clkb,
	input  enb,
	input  [clogb2(DATA_DEPTH)-1:0]addrb,
	output [DATA_WIDTH-1:0]doutb
);
function integer clogb2 (input integer bit_depth);

for(clogb2 = 0; bit_depth > 0; clogb2 = clogb2 + 1) begin
	bit_depth = bit_depth >> 1;
end

endfunction
	
(* ram_style = "block" *)
reg [DATA_WIDTH-1:0] ram [DATA_DEPTH-1:0]; 
reg [clogb2(DATA_DEPTH)-1:0] ram_rd_addrb; 

initial begin: initialize_ram
	integer i;
	for(i = 0; i < DATA_DEPTH; i = i + 1) begin
		ram[i] = { DATA_WIDTH {1'b0} };
//		ram[i] = i;
	end
	ram_rd_addrb <= {(clogb2(DATA_DEPTH)) {1'b0}};
end

assign doutb = ram[ram_rd_addrb];

always @(posedge clka) begin
	if(ena) begin
		ram[addra] <= dina;
	end
end

always @(posedge clkb) begin
	if(enb) begin
		ram_rd_addrb <= addrb;
	end
end

endmodule
