`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.08.2026 16:52:13
// Design Name: 
// Module Name: rf_dispatch_latch
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


module rf_dispatch_latch(
    input clk,
    input rst,
    
    input[15:0] pc1_in, pc2_in,
    input[3:0] op1_in, op2_in,
    input[15:0] imm1_in, imm2_in,
    input comp_bit1_in, comp_bit2_in,
    input[1:0] cz_bits1_in, cz_bits2_in,
    
    input[4:0] dest_tag1_in, dest_tag2_in,
    input we_dest1_in, we_dest2_in,
    
    input[4:0] tag_rs1_in, tag_rt1_in, tag_rs2_in, tag_rt2_in,
    input[15:0] data_rs1_in, data_rt1_in, data_rs2_in, data_rt2_in,
    input valid_rs1_in, valid_rt1_in, valid_rs2_in, valid_rt2_in,
    
    output reg[15:0] pc1_out, pc2_out,
    output reg[3:0] op1_out, op2_out,
    output reg[15:0] imm1_out, imm2_out,
    output reg comp_bit1_out, comp_bit2_out,
    output reg[1:0] cz_bits1_out, cz_bits2_out,
    
    output reg[4:0] dest_tag1_out, dest_tag2_out,
    output reg we_dest1_out, we_dest2_out,
    
    output reg[15:0] payload_rs1, payload_rt1, payload_rs2, payload_rt2,
    output reg is_tag_rs1, is_tag_rt1, is_tag_rs2, is_tag_rt2
    );
    
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            pc1_out <= 16'd0; pc2_out <= 16'd0;
            op1_out <= 4'd0;  op2_out <= 4'd0;
            imm1_out <= 16'd0; imm2_out <= 16'd0;
            comp_bit1_out <= 1'b0; comp_bit2_out <= 1'b0;
            cz_bits1_out <= 2'b00; cz_bits2_out <= 2'b00;
            dest_tag1_out <= 5'd0; dest_tag2_out <= 5'd0;
            we_dest1_out <= 1'b0;  we_dest2_out <= 1'b0;
            
            payload_rs1 <= 16'd0; payload_rt1 <= 16'd0;
            payload_rs2 <= 16'd0; payload_rt2 <= 16'd0;
            is_tag_rs1 <= 1'b0; is_tag_rt1 <= 1'b0;
            is_tag_rs2 <= 1'b0; is_tag_rt2 <= 1'b0;
        end
        else begin
            pc1_out <= pc1_in; pc2_out <= pc2_in;
            op1_out <= op1_in; op2_out <= op2_in;
            imm1_out <= imm1_in; imm2_out <= imm2_in;
            comp_bit1_out <= comp_bit1_in; comp_bit2_out <= comp_bit2_in;
            cz_bits1_out <= cz_bits1_in; cz_bits2_out <= cz_bits2_in;
            dest_tag1_out <= dest_tag1_in; dest_tag2_out <= dest_tag2_in;
            we_dest1_out <= we_dest1_in; we_dest2_out <= we_dest2_in;
            
            if(valid_rs1_in) begin
                payload_rs1 <= data_rs1_in;
                is_tag_rs1 <= 1'b0;
            end
            else begin
                payload_rs1 <= {11'd0, tag_rs1_in};
                is_tag_rs1 <= 1'b1;
            end
            
            if(valid_rt1_in) begin
                payload_rt1 <= data_rt1_in;
                is_tag_rt1 <= 1'b0;
            end
            else begin
                payload_rt1 <= {11'd0, tag_rt1_in};
                is_tag_rt1 <= 1'b1;
            end
            
            if(valid_rs2_in) begin
                payload_rs2 <= data_rs2_in;
                is_tag_rs2 <= 1'b0;
            end
            else begin
                payload_rs2 <= {11'd0, tag_rs2_in};
                is_tag_rs2 <= 1'b1;
            end
            
            if(valid_rt2_in) begin
                payload_rt2 <= data_rt2_in;
                is_tag_rt2 <= 1'b0;
            end
            else begin
                payload_rt2 <= {11'd0, tag_rt2_in};
                is_tag_rt2 <= 1'b1;
            end
            
        end
    end
endmodule
