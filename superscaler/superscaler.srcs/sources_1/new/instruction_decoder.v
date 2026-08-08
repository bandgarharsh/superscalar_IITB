`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: instruction_decoder
// Description: Decodes a single 16-bit instruction according to strict 
//              R, I, and J type formatting.
//////////////////////////////////////////////////////////////////////////////////

module instruction_decoder(
    input  [15:0] instr,
    output        valid_inst,
    output [3:0]  opcode,
    output reg [2:0]  ra,
    output reg [2:0]  rb,
    output reg [2:0]  rc,
    output reg [15:0] imm_ext,
    output reg comp_bit,
    output reg[1:0] cz_bits
);
    
    assign opcode     = instr[15:12];
    assign valid_inst = (instr != 16'h0000); 
    
    always @(*) begin
        // Default assignments to prevent latches
        // Based on your format, RA and RB are universally at [11:9] and [8:6]
        ra = instr[11:9];
        rb = instr[8:6]; 
        rc = 3'b000;
        imm_ext = 16'd0;
        comp_bit  = 0;
        cz_bits = 2'b00;
        
        case(opcode)
            // -----------------------------------------------------
            // I-TYPE: Op | RA | RB | 6-bit Imm
            // -----------------------------------------------------
            4'b0000, 4'b0100, 4'b0101, 4'b1000, 4'b1001: begin 
                // ADI, LW, SW, BEQ, BLT, BLE
                // RB is already assigned to [8:6] above
                imm_ext = {{10{instr[5]}}, instr[5:0]}; // Sign-extended 6-bit immediate
            end
            
            // -----------------------------------------------------
            // R-TYPE: Op | RA | RB | RC | 3-bit unused
            // -----------------------------------------------------
            4'b0001, 4'b0010: begin 
                // ADA, ADC, ADZ, NDU, NDC, etc.
                // RB is already assigned to [8:6] above
                rc = instr[5:3];
                comp_bit  = instr[2]; // compliment bit
                cz_bits = instr[1:0]; // cz bits
            end
            
            4'b1101: begin 
                // JLR (Usually behaves like R-type without RC or I-type without Imm)
                // RB is already assigned to [8:6] above
            end

            // -----------------------------------------------------
            // J-TYPE: Op | RA | 9-bit Imm
            // -----------------------------------------------------
            4'b1100, 4'b1111: begin 
                // JAL, JRI (Jump targets)
                // RB is overwritten/ignored for these
                rb = 3'b000; 
                imm_ext = {{7{instr[8]}}, instr[8:0]}; // Sign-extended 9-bit immediate
            end
            
            4'b0011, 4'b0110, 4'b0111: begin 
                // LLI, LM, SM, LMF, SMF
                // Immediate used as unsigned mask or lower bits
                rb = 3'b000;
                imm_ext = {{7{1'b0}}, instr[8:0]}; // Zero-extended 9-bit immediate
            end
            
            default: begin
                rb = 3'b000;
                rc = 3'b000;
                imm_ext = 16'd0;
                comp_bit  = 0;
                cz_bits = 2'b00;
            end
        endcase
    end
endmodule