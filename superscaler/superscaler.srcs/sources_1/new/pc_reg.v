`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.08.2026 20:21:16
// Design Name: 
// Module Name: pc_reg
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pc_reg(
    input clk,
    input rst,
    input[15:0] pc_in,
    output reg[15:0] pc_out
    );
    always@(posedge clk or posedge rst) begin
    if(rst) 
        pc_out <= 16'd0;
    else
        pc_out <= pc_in;
    end
endmodule
