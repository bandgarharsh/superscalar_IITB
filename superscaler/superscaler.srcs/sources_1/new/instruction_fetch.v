`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Harsh Bandgar
// 
// Create Date: 01.08.2026 19:24:06
// Design Name: 
// Module Name: instruction_fetch
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


module instruction_fetch(
    input clk, 
    input rst,
    input[15:0] pc_bran,
    input [1:0] sel,
    output[15:0] instruct1,
    output[15:0] instruct2,
    output[15:0] pc
    );
    reg  [15:0] pc_in;
    wire [15:0] pc_4;
    
    pc_reg pc_Reg(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(pc)
    );
    pc_adder pc_Adder(
        .pc(pc),
        .pc_out(pc_4)
    );
    instru_mem instru_Mem(
        .clk(clk),
        .addr(pc),
        .instruct1(instruct1),
        .instruct2(instruct2)
    );
    
    always@(*) begin
        case(sel)
            2'b00: pc_in = pc_4;
            2'b01: pc_in = pc_bran;
            default: pc_in = pc;
        endcase
    end
endmodule
