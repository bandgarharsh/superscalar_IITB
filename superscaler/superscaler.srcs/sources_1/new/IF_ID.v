`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.08.2026 21:11:06
// Design Name: 
// Module Name: IF_ID
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


module IF_ID(
    input clk,
    input rst,
    input[15:0] pc,
    input[15:0] instruct1,
    input[15:0] instruct2,
    output reg[15:0] instruct1_o,
    output reg[15:0] instruct2_o,
    output reg[15:0] pc_1o,
    output reg[15:0] pc_2o
    );
    
    always@(posedge rst or posedge clk) begin
        if(rst) begin
            instruct1_o <= 16'd0;
            instruct2_o <= 16'd0;
            pc_1o <= 16'd0;
            pc_2o <= 16'd0;
        end
        else begin
            instruct1_o <= instruct1;
            instruct2_o <= instruct2;
            pc_1o <= pc;
            pc_2o <= pc + 16'd2;
        end
    end
endmodule
