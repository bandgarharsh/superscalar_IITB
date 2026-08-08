`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.08.2026 14:32:44
// Design Name: 
// Module Name: free_list
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


module free_list(
    input clk,
    input rst,
    
    input pop1,
    input pop2,
    output [4:0] free_pr1,
    output [4:0] free_pr2,
    output empty_stall,
    
    input push1,
    input [4:0] freed_pr1,
    input push2,
    input [4:0] freed_pr2
    );
    
    reg[4:0] fifo[31:0];
    reg[4:0] head;
    reg[4:0] tail;
    reg[4:0] count;
    
    integer i;
    
    
    assign free_pr1 = fifo[head];
    assign free_pr2 = fifo[head + 5'd1];
    
    assign empty_stall = (pop1 && pop2 && count < 6'd2) || (pop1 && !pop2 && count < 6'd1);
    
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            for(i=0;i<24;i=i+1) begin
                fifo[i] <= i+8;
            end
            head <= 5'd0;
            tail <= 5'd24;
            count <= 6'd24;
        end
        else begin
            if(pop1 && pop2 && !empty_stall) begin
                head <= head + 5'd2;
            end
            else if (pop1 && !empty_stall) begin
                head <=head + 5'd1;
            end
            
            if(push1 && push2) begin
                fifo[tail] <= freed_pr1;
                fifo[tail + 5'd1] <= freed_pr2;
                tail <= tail + 5'd2;
            end
            else if(push1) begin
                fifo[tail] <= freed_pr1;
                tail <= tail + 5'd1;
            end
            else if(push2) begin
                fifo[tail] <= freed_pr2;
                tail <= tail + 5'd1;
            end
            
            count <= count - (pop1 + pop2) + (push1 + push2);
        end
    end
endmodule
