`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ID_RF
// Description: Pipeline Latch between Instruction Decode and Register Read.
//              Acts as the Issue Queue holding decoded instructions, dependencies,
//              and their respective Program Counters.
//////////////////////////////////////////////////////////////////////////////////

module ID_RF(
    input clk,
    input rst,
    
    // Program Counters from IF_ID latch
    input [15:0] pc1_in,
    input [15:0] pc2_in,
    
    // Instruction 1 Decoded Data
    input [3:0]  op1_in,
    input [2:0]  ra1_in, rb1_in, rc1_in,
    input [15:0] imm1_in,
    input        comp_bit1_in,
    input [1:0]  cz_bits1_in,
    
    // Instruction 2 Decoded Data
    input [3:0]  op2_in,
    input [2:0]  ra2_in, rb2_in, rc2_in,
    input [15:0] imm2_in,
    input        comp_bit2_in,
    input [1:0]  cz_bits2_in,
    
    // Dependency & Routing Flags
    input route_inst1_tag_to_inst2_rb_in,
    input route_inst1_tag_to_inst2_rc_in,
    input inst2_overrides_rat_in,
    
    // --- OUTPUTS ---
    
    output reg [15:0] pc1_op,
    output reg [15:0] pc2_op,
    
    output reg [3:0]  op1_op,
    output reg [2:0]  ra1_op, rb1_op, rc1_op,
    output reg [15:0] imm1_op,
    output reg        comp_bit1_op,
    output reg [1:0]  cz_bits1_op,
    
    output reg [3:0]  op2_op,
    output reg [2:0]  ra2_op, rb2_op, rc2_op,
    output reg [15:0] imm2_op,
    output reg        comp_bit2_op,
    output reg [1:0]  cz_bits2_op,
    
    output reg route_inst1_tag_to_inst2_rb_op,
    output reg route_inst1_tag_to_inst2_rc_op,
    output reg inst2_overrides_rat_op
);
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            pc1_op <= 16'd0;
            pc2_op <= 16'd0;
            
            op1_op <= 4'd0;
            ra1_op <= 3'd0;
            rb1_op <= 3'd0;
            rc1_op <= 3'd0;
            imm1_op <= 16'd0;
            comp_bit1_op <= 1'd0;
            cz_bits1_op <= 2'd0;
            
            op2_op <= 4'd0;
            ra2_op <= 3'd0;
            rb2_op <= 3'd0;
            rc2_op <= 3'd0;
            imm2_op <= 16'd0;
            comp_bit2_op <= 1'd0;
            cz_bits2_op <= 2'd0;
            
            route_inst1_tag_to_inst2_rb_op <= 1'd0;
            route_inst1_tag_to_inst2_rc_op <= 1'd0;
            inst2_overrides_rat_op         <= 1'd0;
        end
        else begin
            pc1_op <= pc1_in;
            pc2_op <= pc2_in;
            
            op1_op <= op1_in;
            ra1_op <= ra1_in;
            rb1_op <= rb1_in;
            rc1_op <= rc1_in;
            imm1_op <= imm1_in;
            comp_bit1_op <= comp_bit1_in;
            cz_bits1_op <= cz_bits1_in;
            
            op2_op <= op2_in;
            ra2_op <= ra2_in;
            rb2_op <= rb2_in;
            rc2_op <= rc2_in;
            imm2_op <= imm2_in;
            comp_bit2_op <= comp_bit2_in;
            cz_bits2_op <= cz_bits2_in;
            
            route_inst1_tag_to_inst2_rb_op <= route_inst1_tag_to_inst2_rb_in;
            route_inst1_tag_to_inst2_rc_op <= route_inst1_tag_to_inst2_rc_in;
            inst2_overrides_rat_op         <= inst2_overrides_rat_in;
        end
    end
endmodule