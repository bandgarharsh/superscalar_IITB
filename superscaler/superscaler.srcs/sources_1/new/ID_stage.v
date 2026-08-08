`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: ID_stage
// Description: Superscalar Instruction Decode with Intra-Cycle Dependency 
//              Checking for ROB Tag Routing and RAT Overrides.
//////////////////////////////////////////////////////////////////////////////////

module ID_stage(
    input  [15:0] instruct1_in,
    input  [15:0] instruct2_in,
    
    output [3:0]  op1,
    output [2:0]  ra1, rb1, rc1,
    output [15:0] imm1,
    output comp_bit1,
    output [1:0] cz_bits1,
    
    output [3:0]  op2,
    output [2:0]  ra2, rb2, rc2,
    output [15:0] imm2,
    output comp_bit2,
    output [1:0] cz_bits2,
    // Updated Output Ports for ROB/RS architecture
    output route_inst1_tag_to_inst2_rb,
    output route_inst1_tag_to_inst2_rc,
    output inst2_overrides_rat
);
    
    wire valid1, valid2;
    
    instruction_decoder decoder_inst1(
        .instr      (instruct1_in),
        .valid_inst (valid1),
        .opcode     (op1),
        .ra         (ra1),
        .rb         (rb1),
        .rc         (rc1),
        .imm_ext    (imm1),
        .comp_bit   (comp_bit1),
        .cz_bits    (cz_bits1)
    );
    
    instruction_decoder decoder_inst2(
        .instr      (instruct2_in),
        .valid_inst (valid2),
        .opcode     (op2),
        .ra         (ra2),
        .rb         (rb2),
        .rc         (rc2),
        .imm_ext    (imm2),
        .comp_bit   (comp_bit2),
        .cz_bits    (cz_bits2)
    );
    
    // Intra-Cycle Dependency Definitions
    wire inst1_writes_reg = (op1 == 4'b0001 || op1 == 4'b0010 || op1 == 4'b0100 || op1 == 4'b0011); 
    wire inst2_reads_rb   = (op2 == 4'b0001 || op2 == 4'b1000); 
    wire inst2_reads_rc   = (op2 == 4'b0001 || op2 == 4'b0010);
    wire inst2_writes_reg = (op2 == 4'b0001 || op2 == 4'b0010 || op2 == 4'b0100 || op2 == 4'b0011);
    
    // RAW Dependency: Route Inst 1's newly allocated ROB tag to Inst 2's operands
    assign route_inst1_tag_to_inst2_rb = valid1 && valid2 && inst1_writes_reg && 
                                         (inst2_reads_rb && (ra1 == rb2));
                                         
    assign route_inst1_tag_to_inst2_rc = valid1 && valid2 && inst1_writes_reg && 
                                         (inst2_reads_rc && (ra1 == rc2));
    
    // WAW Dependency: Ensure only Inst 2 updates the Register Alias Table (RAT)
    assign inst2_overrides_rat = valid1 && valid2 && inst1_writes_reg && 
                                 inst2_writes_reg && (ra1 == ra2);

endmodule