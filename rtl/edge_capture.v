`timescale 1ns / 1ps

module edge_capture
#(
	parameter EDGE_TYPE = 0		//0 = rising edge, 1 = falling edge
)
(	
	input clk,
	input rst_n,
	input signal_i,
	output edge_captured_o
);

reg signal_1dff, signal_2dff;

generate 
	if(EDGE_TYPE == 0) begin
		assign edge_captured_o = signal_1dff & (~signal_2dff);
	end
	else begin
		assign edge_captured_o = (~signal_1dff) & signal_2dff;
	end
endgenerate

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		signal_1dff <= 1'b0;
		signal_2dff <= 1'b0;
	end
	else begin
		signal_1dff <= signal_i;
		signal_2dff = signal_1dff;
	end
end

endmodule
