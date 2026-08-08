`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.08.2026 14:15:27
// Design Name: 
// Module Name: PRF
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


module PRF(
    input clk,
    input rst,
    
    input[4:0] prs1_addr, prt1_addr,
    input[4:0] prs2_addr, prt2_addr,
    
    output[15:0] data_rs1, data_rt1,
    output[15:0] data_rs2, data_rt2,
    
    input we1,
    input[4:0] p_dest1_addr,
    input[15:0] data_in1,
    
    input we2,
    input[4:0] p_dest2_addr,
    input[15:0] data_in2
    );
    
    reg[15:0] registers[31:0];
    
    integer i;
    
    assign data_rs1 = registers[prs1_addr];
    assign data_rt1 = registers[prt1_addr];
    assign data_rs2 = registers[prs2_addr];
    assign data_rt2 = registers[prt2_addr];
    
    
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            for(i=0;i<32;i=i+1) begin
                registers[i] = 16'd0;
            end
        end
        else begin
            if(we1) registers[p_dest1_addr] <= data_in1;
            if(we2) registers[p_dest2_addr] <= data_in2;
        end
    end
endmodule
