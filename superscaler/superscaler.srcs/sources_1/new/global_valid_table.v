`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.08.2026 16:41:56
// Design Name: 
// Module Name: global_valid_table
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


module global_valid_table(
    input clk,
    input rst,
    
    input[4:0] prs1_addr,prt1_addr,
    input[4:0] prs2_addr,prt2_addr,
    output valid_rs1, valid_rt1,
    output valid_rs2, valid_rt2,
    
    input alloc_we1,
    input[4:0] alloc_tag1,
    input alloc_we2,
    input[4:0] alloc_tag2,
    
    input cbd_we1,
    input[4:0] cbd_tag1,
    input cbd_we2,
    input[4:0] cbd_tag2
    );
    
    reg[31:0] ready_bits;
    
    assign valid_rs1 = ready_bits[prs1_addr];
    assign valid_rt1 = ready_bits[prt1_addr];
    assign valid_rs2 = ready_bits[prs2_addr];
    assign valid_rt2 = ready_bits[prt2_addr];
    
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            ready_bits <= 32'hFFFF_FFFF;
        end
        else begin
            ready_bits <= ready_bits;
            
            if(alloc_we1) ready_bits[alloc_tag1] <= 1'b0;
            if(alloc_we2) ready_bits[alloc_tag2] <= 1'b0;
            
            if(cbd_we1) ready_bits[cbd_tag1] <= 1'b1;
            if(cbd_we2) ready_bits[cbd_tag2] <= 1'b1;
            
        end
    end
endmodule
