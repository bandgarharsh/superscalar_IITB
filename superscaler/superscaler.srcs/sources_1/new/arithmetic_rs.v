`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: arithmetic_rs
// Description: 4-slot Reservation Station for Arithmetic/Logic instructions.
//              Snoops 2 CDB ports for operands and issues 1 ready instruction.
//////////////////////////////////////////////////////////////////////////////////

module arithmetic_rs(
    input clk,
    input rst,
    input flush, // From Branch Misprediction (ROB Commit)
    
    // --- 1. DISPATCH INTERFACE (Writing to RS) ---
    input         we,              // Write Enable from Dispatch
    input  [1:0]  alloc_idx,       // Which of the 4 slots to write into
    input  [3:0]  d_opcode,
    input         d_comp,
    input  [1:0]  d_cz,
    input  [4:0]  d_dest_pr,       // Destination Physical Register
    input  [4:0]  d_rob_tag,       // ROB Entry ID
    
    // Operand 1 (RA)
    input         d_vj_valid,
    input  [15:0] d_vj_data,
    input  [4:0]  d_qj_tag,
    
    // Operand 2 (RB or Immediate)
    input         d_vk_valid,
    input  [15:0] d_vk_data,
    input  [4:0]  d_qk_tag,
    
    // --- 2. COMMON DATA BUS INTERFACE (Snooping) ---
    // CDB Port 1 (e.g., from ALU 1)
    input         cdb1_valid,
    input  [4:0]  cdb1_tag,
    input  [15:0] cdb1_data,
    
    // CDB Port 2 (e.g., from ALU 2 or Load Unit)
    input         cdb2_valid,
    input  [4:0]  cdb2_tag,
    input  [15:0] cdb2_data,
    
    // --- 3. ISSUE INTERFACE (To ALU) ---
    output reg        issue_valid,
    output reg [3:0]  issue_opcode,
    output reg        issue_comp,
    output reg [1:0]  issue_cz,
    output reg [15:0] issue_vj,
    output reg [15:0] issue_vk,
    output reg [4:0]  issue_dest_pr,
    output reg [4:0]  issue_rob_tag,
    
    // Status to Dispatcher
    output [3:0] busy_slots // Tells Dispatch which slots are full
);

    // RS Slot Arrays (4 Entries)
    reg        busy      [3:0];
    reg [3:0]  opcode    [3:0];
    reg        comp      [3:0];
    reg [1:0]  cz        [3:0];
    reg [4:0]  dest_pr   [3:0];
    reg [4:0]  rob_tag   [3:0];
    
    reg        vj_valid  [3:0];
    reg [15:0] vj        [3:0];
    reg [4:0]  qj        [3:0];
    
    reg        vk_valid  [3:0];
    reg [15:0] vk        [3:0];
    reg [4:0]  qk        [3:0];

    reg [1:0] issue_idx;
    
    integer i;
    
    // Output busy vector so Dispatch knows where to allocate
    assign busy_slots = {busy[3], busy[2], busy[1], busy[0]};

    // -------------------------------------------------------------------------
    // Sequential Logic: Dispatch, CDB Snooping, and Flushing
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            for (i = 0; i < 4; i = i + 1) begin
                busy[i] <= 1'b0;
            end
        end
        else begin
            // 1. CLEAR ISSUED INSTRUCTION
            // If an instruction was issued this cycle, free up its slot
            if (issue_valid) begin
                busy[issue_idx] <= 1'b0;
            end

            // 2. DISPATCH (Allocate new instruction)
            if (we) begin
                busy[alloc_idx]      <= 1'b1;
                opcode[alloc_idx]    <= d_opcode;
                comp[alloc_idx]      <= d_comp;
                cz[alloc_idx]        <= d_cz;
                dest_pr[alloc_idx]   <= d_dest_pr;
                rob_tag[alloc_idx]   <= d_rob_tag;
                
                vj_valid[alloc_idx]  <= d_vj_valid;
                vj[alloc_idx]        <= d_vj_data;
                qj[alloc_idx]        <= d_qj_tag;
                
                vk_valid[alloc_idx]  <= d_vk_valid;
                vk[alloc_idx]        <= d_vk_data;
                qk[alloc_idx]        <= d_qk_tag;
            end

            // 3. CDB SNOOPING (Capture broadcasted data)
            for (i = 0; i < 4; i = i + 1) begin
                if (busy[i]) begin
                    // Check Operand J against CDB 1 and 2
                    if (!vj_valid[i]) begin
                        if (cdb1_valid && (qj[i] == cdb1_tag)) begin
                            vj[i] <= cdb1_data;
                            vj_valid[i] <= 1'b1;
                        end else if (cdb2_valid && (qj[i] == cdb2_tag)) begin
                            vj[i] <= cdb2_data;
                            vj_valid[i] <= 1'b1;
                        end
                    end
                    
                    // Check Operand K against CDB 1 and 2
                    if (!vk_valid[i]) begin
                        if (cdb1_valid && (qk[i] == cdb1_tag)) begin
                            vk[i] <= cdb1_data;
                            vk_valid[i] <= 1'b1;
                        end else if (cdb2_valid && (qk[i] == cdb2_tag)) begin
                            vk[i] <= cdb2_data;
                            vk_valid[i] <= 1'b1;
                        end
                    end
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Combinational Logic: Issue Selection (Find oldest ready instruction)
    // -------------------------------------------------------------------------
    // An instruction is ready if it is busy and both operands are valid.
    wire ready0 = busy[0] && vj_valid[0] && vk_valid[0];
    wire ready1 = busy[1] && vj_valid[1] && vk_valid[1];
    wire ready2 = busy[2] && vj_valid[2] && vk_valid[2];
    wire ready3 = busy[3] && vj_valid[3] && vk_valid[3];

    
    
    // Priority Encoder: Pick the lowest index ready instruction to issue
    always @(*) begin
        // Default assignments
        issue_valid = 1'b0;
        issue_idx = 2'd0; // Default index
        issue_opcode = 4'd0; issue_comp = 1'b0; issue_cz = 2'd0;
        issue_vj = 16'd0; issue_vk = 16'd0; 
        issue_dest_pr = 5'd0; issue_rob_tag = 5'd0;

        if (ready0) begin
            issue_valid = 1'b1; issue_idx = 2'd0; 
            issue_opcode = opcode[0]; issue_comp = comp[0]; issue_cz = cz[0];
            issue_vj = vj[0]; issue_vk = vk[0]; issue_dest_pr = dest_pr[0]; issue_rob_tag = rob_tag[0];
        end else if (ready1) begin
            issue_valid = 1'b1; issue_idx = 2'd1; 
            issue_opcode = opcode[1]; issue_comp = comp[1]; issue_cz = cz[1];
            issue_vj = vj[1]; issue_vk = vk[1]; issue_dest_pr = dest_pr[1]; issue_rob_tag = rob_tag[1];
        end else if (ready2) begin
            issue_valid = 1'b1; issue_idx = 2'd2; 
            issue_opcode = opcode[2]; issue_comp = comp[2]; issue_cz = cz[2];
            issue_vj = vj[2]; issue_vk = vk[2]; issue_dest_pr = dest_pr[2]; issue_rob_tag = rob_tag[2];
        end else if (ready3) begin
            issue_valid = 1'b1; issue_idx = 2'd3; 
            issue_opcode = opcode[3]; issue_comp = comp[3]; issue_cz = cz[3];
            issue_vj = vj[3]; issue_vk = vk[3]; issue_dest_pr = dest_pr[3]; issue_rob_tag = rob_tag[3];
        end
    end

endmodule
