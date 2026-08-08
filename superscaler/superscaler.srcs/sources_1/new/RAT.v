`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: RAT
// Description: Register Alias Table for mapping 8 architectural registers 
//              to 32 physical registers. Includes intra-cycle forwarding 
//              for 2-way superscalar dependencies.
//////////////////////////////////////////////////////////////////////////////////

module RAT(
    input clk,
    input rst,
    
    // Read addresses (Operands)
    input [2:0] rs1,
    input [2:0] rt1,
    input [2:0] rs2,
    input [2:0] rt2,
    
    // Intra-cycle dependency flags (from ID_RF latch)
    input route_rs2_from_inst1, // High if Inst 2's rs2 depends on Inst 1's rd1
    input route_rt2_from_inst1, // High if Inst 2's rt2 depends on Inst 1's rd1
    input inst2_overrides_waw,  // High if both write to the same destination
    
    // Output physical register tags
    output [4:0] prs1,
    output [4:0] prt1,
    output [4:0] prs2,
    output [4:0] prt2, 
    
    // Write Port 1 (Instruction 1)
    input we1,
    input [2:0] rd1,
    input [4:0] new_pr1,
    
    // Write Port 2 (Instruction 2)
    input we2,
    input [2:0] rd2,
    input [4:0] new_pr2
);
    
    reg [4:0] map [7:0];
    integer i;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for(i=0; i<8; i=i+1)
                map[i] <= i; // Initial 1:1 mapping mapping
        end
        else begin
            // Update Port 1: Only write if Inst 2 isn't overwriting the exact same register
            if(we1 && !inst2_overrides_waw) begin
                map[rd1] <= new_pr1;
            end
            
            // Update Port 2: Always writes if enabled (higher priority in program order)
            if(we2) begin
                map[rd2] <= new_pr2;
            end
        end
    end
    
    // Combinational Read Logic with RAW Bypassing
    assign prs1 = map[rs1];
    assign prt1 = map[rt1];
    
    // If Inst 2 requires the result of Inst 1, give it the newly allocated physical tag directly
    assign prs2 = (route_rs2_from_inst1) ? new_pr1 : map[rs2];
    assign prt2 = (route_rt2_from_inst1) ? new_pr1 : map[rt2];

endmodule