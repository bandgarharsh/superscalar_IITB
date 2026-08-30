library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL;

entity Core_Top is
    Port (
        -- =========================================================
        -- 1. CLOCK & RESET (The Heartbeat)
        -- =========================================================
        clk                 : in  std_logic;
        rst                 : in  std_logic;

        -- =========================================================
        -- 2. REAL-WORLD I/O PINS (GPIO)
        -- This allows your assembly code to read/write to the outside world
        -- =========================================================
        external_gpio_in    : in  std_logic_vector(15 downto 0); -- Hook to FPGA Switches
        external_gpio_out   : out std_logic_vector(15 downto 0); -- Hook to FPGA LEDs

        -- =========================================================
        -- 3. HARDWARE DEBUG PINS (For Vivado ILA / Oscilloscope)
        -- Prevents the synthesizer from deleting your core!
        -- =========================================================
        debug_fetch_pc      : out std_logic_vector(15 downto 0); 
        debug_commit_valid1 : out std_logic;                     -- FIXED
        debug_commit_valid2 : out std_logic;                     -- ADDED
        debug_commit_data1  : out std_logic_vector(15 downto 0); 
        debug_commit_data2  : out std_logic_vector(15 downto 0); 
        debug_commit_flag1  : out std_logic_vector(1 downto 0);  
        debug_commit_flag2  : out std_logic_vector(1 downto 0);  
        debug_global_flush  : out std_logic;                    -- Did we mispredict a branch?
        debug_stall_signals : out std_logic_vector(3 downto 0) 
    );
end Core_Top;

architecture Structural of Core_Top is

    -- =========================================================
    -- 0. GLOBAL CONTROL & STALL SIGNALS
    -- =========================================================
    signal rob_global_flush     : std_logic;
    signal rob_flush_target_pc  : std_logic_vector(15 downto 0);
    signal dispatch_stall       : std_logic;
    signal rr_stall_out         : std_logic;
    signal pipeline_stall       : std_logic; 
    
    signal if_sel               : std_logic_vector(1 downto 0);
    signal if_pc_bran           : std_logic_vector(15 downto 0);

    -- =========================================================
    -- 1. FETCH -> IF/ID LATCH WIRES
    -- =========================================================
    signal if_valid1, if_valid2               : std_logic;
    signal if_pc1, if_pc2                     : std_logic_vector(15 downto 0);
    signal if_inst1, if_inst2                 : std_logic_vector(15 downto 0);
    signal if_pred_taken1, if_pred_taken2     : std_logic;
    signal if_pred_target1, if_pred_target2   : std_logic_vector(15 downto 0);

    -- =========================================================
    -- 2. IF/ID LATCH -> DECODE WIRES
    -- =========================================================
    signal ifid_valid1, ifid_valid2             : std_logic;
    signal ifid_pc1, ifid_pc2                   : std_logic_vector(15 downto 0);
    signal ifid_inst1, ifid_inst2               : std_logic_vector(15 downto 0);

    -- =========================================================
    -- 3. DECODE -> ID/RF LATCH WIRES (SLOT 1)
    -- =========================================================
    signal id_op1_valid      : std_logic;
    signal id_pc1_out        : std_logic_vector(15 downto 0);
    signal id_op1            : std_logic_vector(3 downto 0);
    signal id_imm1           : std_logic_vector(15 downto 0);
    signal id_comp_bit1      : std_logic;
    signal id_cz_bits1       : std_logic_vector(1 downto 0);
    signal id_src1_reg1, id_src2_reg1, id_dest_reg1 : std_logic_vector(2 downto 0);
    signal id_reads_rs1_1, id_reads_rs2_1, id_we_gpr1, id_dest_is_r0_1, id_we_flag1 : std_logic;
    signal id_is_alu1, id_is_lsu1, id_is_branch1, id_is_multimem1, id_is_store1, id_illegal_op1 : std_logic;
    signal id_out_pred_taken1: std_logic;
    signal id_out_pred_target1: std_logic_vector(15 downto 0);

    -- =========================================================
    -- 4. DECODE -> ID/RF LATCH WIRES (SLOT 2)
    -- =========================================================
    signal id_op2_valid      : std_logic;
    signal id_pc2_out        : std_logic_vector(15 downto 0);
    signal id_op2            : std_logic_vector(3 downto 0);
    signal id_imm2           : std_logic_vector(15 downto 0);
    signal id_comp_bit2      : std_logic;
    signal id_cz_bits2       : std_logic_vector(1 downto 0);
    signal id_src1_reg2, id_src2_reg2, id_dest_reg2 : std_logic_vector(2 downto 0);
    signal id_reads_rs1_2, id_reads_rs2_2, id_we_gpr2, id_dest_is_r0_2, id_we_flag2 : std_logic;
    signal id_is_alu2, id_is_lsu2, id_is_branch2, id_is_multimem2, id_is_store2, id_illegal_op2 : std_logic;
    signal id_out_pred_taken2: std_logic;
    signal id_out_pred_target2: std_logic_vector(15 downto 0);

    -- =========================================================
    -- 5. ID/RF LATCH -> RR STAGE WIRES (SLOT 1 & 2 Outputs)
    -- =========================================================
    -- (Same naming structure as Group 3 & 4 but prefix 'idrf_')
    signal idrf_op1_valid_out, idrf_op2_valid_out : std_logic;
    signal idrf_pc1_out, idrf_pc2_out             : std_logic_vector(15 downto 0);
    signal idrf_op1_out, idrf_op2_out             : std_logic_vector(3 downto 0);
    signal idrf_imm1_out, idrf_imm2_out           : std_logic_vector(15 downto 0);
    signal idrf_comp_bit1_out, idrf_comp_bit2_out : std_logic;
    signal idrf_cz_bits1_out, idrf_cz_bits2_out   : std_logic_vector(1 downto 0);
    
    signal idrf_src1_reg1_out, idrf_src2_reg1_out, idrf_dest_reg1_out : std_logic_vector(2 downto 0);
    signal idrf_src1_reg2_out, idrf_src2_reg2_out, idrf_dest_reg2_out : std_logic_vector(2 downto 0);
    
    signal idrf_reads_rs1_1_out, idrf_reads_rs2_1_out, idrf_we_gpr1_out, idrf_dest_is_r0_1_out, idrf_we_flag1_out : std_logic;
    signal idrf_reads_rs1_2_out, idrf_reads_rs2_2_out, idrf_we_gpr2_out, idrf_dest_is_r0_2_out, idrf_we_flag2_out : std_logic;
    
    signal idrf_is_alu1_out, idrf_is_lsu1_out, idrf_is_branch1_out, idrf_is_multimem1_out, idrf_is_store1_out, idrf_illegal_op1_out : std_logic;
    signal idrf_is_alu2_out, idrf_is_lsu2_out, idrf_is_branch2_out, idrf_is_multimem2_out, idrf_is_store2_out, idrf_illegal_op2_out : std_logic;
    
    signal idrf_out_pred_taken1, idrf_out_pred_taken2 : std_logic;
    signal idrf_out_pred_target1, idrf_out_pred_target2 : std_logic_vector(15 downto 0);

    -- =========================================================
    -- 6. RR STAGE -> DISPATCH LATCH WIRES (The Renamed Bundles)
    -- =========================================================
    -- Slot 1 Renamed
    signal rr_dispatch_valid1_out, rr_comp_bit1_out : std_logic;
    signal rr_pc1_out, rr_imm1_out                  : std_logic_vector(15 downto 0);
    signal rr_op1_out, rr_rob_id1_out               : std_logic_vector(3 downto 0);
    signal rr_cz_bits1_out                          : std_logic_vector(1 downto 0);
    signal rr_arch_dest1                            : std_logic_vector(2 downto 0);
    signal rr_prs1_out, rr_prt1_out, rr_pr_flag1_out: std_logic_vector(4 downto 0);
    signal rr_pd1_new, rr_pd1_old, rr_pf1_new, rr_pf1_old : std_logic_vector(4 downto 0);
    signal rr_prs1_rdy, rr_prt1_rdy, rr_pr_flag1_rdy: std_logic;
    signal rr_out_pred_taken1                       : std_logic;
    signal rr_out_pred_target1                      : std_logic_vector(15 downto 0);
    -- Pass-through flags
    signal rr_reads_rs1_1_out, rr_reads_rs2_1_out, rr_dest_is_r0_1_out, rr_we_gpr1_out, rr_we_flag1_out : std_logic;
    signal rr_is_alu1_out, rr_is_lsu1_out, rr_is_branch1_out, rr_is_multimem1_out, rr_is_store1_out, rr_illegal_op1_out : std_logic;

    -- Slot 2 Renamed
    signal rr_dispatch_valid2_out, rr_comp_bit2_out : std_logic;
    signal rr_pc2_out, rr_imm2_out                  : std_logic_vector(15 downto 0);
    signal rr_op2_out, rr_rob_id2_out               : std_logic_vector(3 downto 0);
    signal rr_cz_bits2_out                          : std_logic_vector(1 downto 0);
    signal rr_arch_dest2                            : std_logic_vector(2 downto 0);
    signal rr_prs2_out, rr_prt2_out, rr_pr_flag2_out: std_logic_vector(4 downto 0);
    signal rr_pd2_new, rr_pd2_old, rr_pf2_new, rr_pf2_old : std_logic_vector(4 downto 0);
    signal rr_prs2_rdy, rr_prt2_rdy, rr_pr_flag2_rdy: std_logic;
    signal rr_out_pred_taken2                       : std_logic;
    signal rr_out_pred_target2                      : std_logic_vector(15 downto 0);
    -- Pass-through flags
    signal rr_reads_rs1_2_out, rr_reads_rs2_2_out, rr_dest_is_r0_2_out, rr_we_gpr2_out, rr_we_flag2_out : std_logic;
    signal rr_is_alu2_out, rr_is_lsu2_out, rr_is_branch2_out, rr_is_multimem2_out, rr_is_store2_out, rr_illegal_op2_out : std_logic;

    -- =========================================================
    -- 7. DISPATCH LATCH -> DISPATCH ROUTER WIRES
    -- =========================================================
    -- (Same naming structure as Group 6 but prefix 'disp_in_')
    -- Raw Dispatch Packets for the ROB (Pre-Router)
    signal rob_disp_packet_1 : dispatch_packet_t;
    signal rob_disp_packet_2 : dispatch_packet_t;
    
    signal disp_in_valid1, disp_in_valid2 : std_logic;
    -- Slot 1 Renamed
    signal disp_in_comp_bit1_out : std_logic;
    signal disp_in_pc1_out, disp_in_imm1_out                  : std_logic_vector(15 downto 0);
    signal disp_in_op1_out, disp_in_rob_id1_out               : std_logic_vector(3 downto 0);
    signal disp_in_cz_bits1_out                          : std_logic_vector(1 downto 0);
    signal disp_in_arch_dest1                            : std_logic_vector(2 downto 0);
    signal disp_in_prs1_out, disp_in_prt1_out, disp_in_pr_flag1_out: std_logic_vector(4 downto 0);
    signal disp_in_pd1_new, disp_in_pd1_old, disp_in_pf1_new, disp_in_pf1_old : std_logic_vector(4 downto 0);
    signal disp_in_prs1_rdy, disp_in_prt1_rdy, disp_in_pr_flag1_rdy: std_logic;
    signal disp_in_out_pred_taken1                       : std_logic;
    signal disp_in_out_pred_target1                      : std_logic_vector(15 downto 0);
    -- Pass-through flags
    signal disp_in_reads_rs1_1_out, disp_in_reads_rs2_1_out, disp_in_dest_is_r0_1_out, disp_in_we_gpr1_out, disp_in_we_flag1_out : std_logic;
    signal disp_in_is_alu1_out, disp_in_is_lsu1_out, disp_in_is_branch1_out, disp_in_is_multimem1_out, disp_in_is_store1_out, disp_in_illegal_op1_out : std_logic;

    -- Slot 2 Renamed
    signal disp_in_comp_bit2_out : std_logic;
    signal disp_in_pc2_out, disp_in_imm2_out                  : std_logic_vector(15 downto 0);
    signal disp_in_op2_out, disp_in_rob_id2_out               : std_logic_vector(3 downto 0);
    signal disp_in_cz_bits2_out                          : std_logic_vector(1 downto 0);
    signal disp_in_arch_dest2                            : std_logic_vector(2 downto 0);
    signal disp_in_prs2_out, disp_in_prt2_out, disp_in_pr_flag2_out: std_logic_vector(4 downto 0);
    signal disp_in_pd2_new, disp_in_pd2_old, disp_in_pf2_new, disp_in_pf2_old : std_logic_vector(4 downto 0);
    signal disp_in_prs2_rdy, disp_in_prt2_rdy, disp_in_pr_flag2_rdy: std_logic;
    signal disp_in_out_pred_taken2                       : std_logic;
    signal disp_in_out_pred_target2                      : std_logic_vector(15 downto 0);
    -- Pass-through flags
    signal disp_in_reads_rs1_2_out, disp_in_reads_rs2_2_out, disp_in_dest_is_r0_2_out, disp_in_we_gpr2_out, disp_in_we_flag2_out : std_logic;
    signal disp_in_is_alu2_out, disp_in_is_lsu2_out, disp_in_is_branch2_out, disp_in_is_multimem2_out, disp_in_is_store2_out, disp_in_illegal_op2_out : std_logic;

    -- [Note: To save vertical space, the router maps directly to the rr_* signals 
    -- passing through the latch, but these are the packets:]
    signal rs_alu_port1, rs_alu_port2 : dispatch_packet_t;
    signal rs_lsu_port1, rs_lsu_port2 : dispatch_packet_t;
    signal rs_br_port1, rs_br_port2   : dispatch_packet_t;
    
    signal rs_alu_free_slots  : unsigned(1 downto 0);
    signal rs_lsu_free_slots  : unsigned(1 downto 0);
    signal rs_br_free_slots   : unsigned(1 downto 0);
    
    signal live_gpr_busy_mask  : std_logic_vector(31 downto 0);
    signal live_flag_busy_mask : std_logic_vector(31 downto 0);
    -- =========================================================
    -- 8. RS -> EXECUTION UNIT WIRES
    -- =========================================================
    signal issue_alu_valid  : std_logic;
    signal issue_alu_pkt    : issue_packet_t;
    
    signal issue_br_valid   : std_logic;
    signal issue_br_pkt     : branch_issue_packet_t;
    
    signal issue_lsu_valid  : std_logic;
    signal issue_is_store   : std_logic;
    signal issue_lsu_pkt    : lsu_issue_packet_t;

    -- =========================================================
    -- 9. PRF READ PORTS (Asynchronous Data to Dispatch Router)
    -- =========================================================
    signal prf_r_data_rs1_1, prf_r_data_rs2_1 : std_logic_vector(15 downto 0);
    signal prf_r_flags_1                      : std_logic_vector(1 downto 0);
    signal prf_r_data_rs1_2, prf_r_data_rs2_2 : std_logic_vector(15 downto 0);
    signal prf_r_flags_2                      : std_logic_vector(1 downto 0);

    -- =========================================================
    -- 10. CDB BROADCAST BUNDLES (Arrays for easy routing)
    -- =========================================================
    signal cdb_gpr_en_bus    : std_logic_vector(2 downto 0);
    signal cdb_gpr_tag_bus   : array_of_5bit(0 to 2);
    signal cdb_gpr_data_bus  : array_of_16bit(0 to 2);
    
    signal cdb_flag_en_bus   : std_logic_vector(1 downto 0);
    signal cdb_flag_tag_bus  : array_of_5bit(0 to 1);
    signal cdb_flag_data_bus : array_of_2bit(0 to 1);

    -- =========================================================
    -- 11. EXECUTION UNIT OUTPUTS -> CDB & ROB
    -- =========================================================
    -- ALU Outputs
    signal alu_cdb_gpr_en, alu_cdb_flag_en     : std_logic;
    signal alu_cdb_gpr_tag, alu_cdb_flag_tag   : std_logic_vector(4 downto 0);
    signal alu_cdb_gpr_data                    : std_logic_vector(15 downto 0);
    signal alu_cdb_flag_data                   : std_logic_vector(1 downto 0);
    signal alu_rob_en                          : std_logic;
    signal alu_rob_id                          : std_logic_vector(3 downto 0);
    signal alu_rob_gpr_data                    : std_logic_vector(15 downto 0);
    signal alu_rob_flag_data                   : std_logic_vector(1 downto 0);
    signal alu_rob_cond_fail                   : std_logic;
    
    -- Branch Outputs
    signal br_cdb_gpr_en                       : std_logic;
    signal br_cdb_gpr_tag                      : std_logic_vector(4 downto 0);
    signal br_cdb_gpr_data                     : std_logic_vector(15 downto 0);
    signal br_rob_en                           : std_logic;
    signal br_rob_id                           : std_logic_vector(3 downto 0);
    signal br_rob_gpr_data                     : std_logic_vector(15 downto 0);
    signal br_rob_is_branch                    : std_logic;
    signal br_rob_mispred                      : std_logic;
    signal br_rob_target                       : std_logic_vector(15 downto 0);
    
    -- LSU (Load/Store Queue) Outputs
    signal lq_cdb_gpr_en, lq_cdb_flag_en       : std_logic;
    signal lq_cdb_gpr_tag, lq_cdb_flag_tag     : std_logic_vector(4 downto 0);
    signal lq_cdb_gpr_data                     : std_logic_vector(15 downto 0);
    signal lq_cdb_flag_data                    : std_logic_vector(1 downto 0);
    signal lq_rob_en, sq_rob_en                : std_logic;
    signal lq_rob_id, sq_rob_id                : std_logic_vector(3 downto 0);
    signal lq_rob_gpr_data                     : std_logic_vector(15 downto 0);
    signal lq_rob_flag_data                    : std_logic_vector(1 downto 0);

    -- =========================================================
    -- 12. DATA RAM & MEMORY MAPPED I/O
    -- =========================================================
    signal lq_ram_read_en, sq_ram_write_en     : std_logic;
    signal lq_ram_read_addr, sq_ram_write_addr : std_logic_vector(15 downto 0);
    signal sq_ram_write_data                   : std_logic_vector(15 downto 0);
    signal actual_ram_data_out, lq_ram_data_in : std_logic_vector(15 downto 0);
    signal sq_state_bus                        : sq_array_t; -- Load Queue Disambiguation

    -- =========================================================
    -- 13. ROB -> RRAT COMMIT SIGNALS
    -- =========================================================
    signal cmt_val_1, cmt_val_2                : std_logic;
    signal cmt_dest_1, cmt_dest_2              : std_logic_vector(2 downto 0);
    signal cmt_pd_1, cmt_pd_2                  : std_logic_vector(4 downto 0);
    signal cmt_flag_val_1, cmt_flag_val_2      : std_logic;
    signal cmt_pf_1, cmt_pf_2                  : std_logic_vector(4 downto 0);
    
    signal rob_free_count                      : unsigned(4 downto 0);
--    signal rob_tail_id1, rob_tail_id2          : std_logic_vector(3 downto 0);
    -- Intermediate signals for ROB connection
    signal br_correct_target_sig : std_logic_vector(15 downto 0);
    signal rob_tail_id1_sig       : std_logic_vector(3 downto 0);
    signal rob_tail_id2_sig       : std_logic_vector(3 downto 0);
    signal rob_full_sig          : std_logic;

    -- =========================================================
    -- 14. RRAT -> RR_STAGE (Recovery & Free List)
    -- =========================================================
    signal cmt_rat_flat                        : std_logic_vector(39 downto 0);
    signal cmt_flag_tag                        : std_logic_vector(4 downto 0);
    signal cmt_gpr_mask, cmt_flag_mask         : std_logic_vector(31 downto 0);
    
    signal free_gpr1_en, free_gpr2_en          : std_logic;
    signal free_gpr1_tag, free_gpr2_tag        : std_logic_vector(4 downto 0);
    signal free_f1_en, free_f2_en              : std_logic;
    signal free_f1_tag, free_f2_tag            : std_logic_vector(4 downto 0);
    
    
    -- =========================================================
    -- LSU & MEMORY SUBSYSTEM SIGNALS
    -- =========================================================
    -- RS_LSU to AGU Wires
    signal rs_to_agu_valid      : std_logic;
    signal rs_to_agu_is_store   : std_logic;
    signal rs_to_agu_packet     : lsu_issue_packet_t;
    
    -- AGU to Load/Store Queue Wires
    signal agu_out_valid        : std_logic;
    signal agu_out_is_store     : std_logic;
    signal agu_out_addr         : std_logic_vector(15 downto 0);
    signal agu_out_packet       : lsu_issue_packet_t;
    
    -- Queue & RAM Wires
    signal sq_commit_valid      : std_logic;
    signal sq_commit_id         : std_logic_vector(3 downto 0);
--    signal sq_rob_id       : std_logic_vector(3 downto 0); -- Matches your 5-bit SQ output
    
    
    signal cmt_data_1 : std_logic_vector(15 downto 0);
    signal cmt_data_2 : std_logic_vector(15 downto 0);
    signal cmt_flag_1 : std_logic_vector(1 downto 0);
    signal cmt_flag_2 : std_logic_vector(1 downto 0);
    
    signal decode_valid_1 : std_logic;
    signal decode_valid_2 : std_logic;
begin
    
    -- THE MAGIC BULLET: Filter out the 0x0000 padding NOPs so they don't break the decoder!
    decode_valid_1 <= ifid_valid1 when ifid_inst1 /= x"0000" else '0';
    decode_valid_2 <= ifid_valid2 when ifid_inst2 /= x"0000" else '0';
    -- =========================================================
    -- 1. PC CONTROL LOGIC (The Dumb Fetch for Baseline)
    -- =========================================================
    process(rob_global_flush, rob_flush_target_pc)
    begin
        if rob_global_flush = '1' then
            if_sel     <= "01"; 
            if_pc_bran <= rob_flush_target_pc;
        else
            if_sel     <= "00"; 
            if_pc_bran <= (others => '0');
        end if;
    end process;
    
    pipeline_stall <= rr_stall_out or dispatch_stall or rob_full_sig;

    -- =========================================================
    -- 2. CDB BROADCAST BUNDLING
    -- =========================================================
    cdb_gpr_en_bus(0)   <= alu_cdb_gpr_en;
    cdb_gpr_tag_bus(0)  <= alu_cdb_gpr_tag;
    cdb_gpr_data_bus(0) <= alu_cdb_gpr_data;
    cdb_flag_en_bus(0)  <= alu_cdb_flag_en;
    cdb_flag_tag_bus(0) <= alu_cdb_flag_tag;
    cdb_flag_data_bus(0)<= alu_cdb_flag_data;
    
    cdb_gpr_en_bus(1)   <= lq_cdb_gpr_en;   -- Changed to lq (Load Queue)
    cdb_gpr_tag_bus(1)  <= lq_cdb_gpr_tag;
    cdb_gpr_data_bus(1) <= lq_cdb_gpr_data;
    cdb_flag_en_bus(1)  <= lq_cdb_flag_en;
    cdb_flag_tag_bus(1) <= lq_cdb_flag_tag;
    cdb_flag_data_bus(1)<= lq_cdb_flag_data;
    
    cdb_gpr_en_bus(2)   <= br_cdb_gpr_en;
    cdb_gpr_tag_bus(2)  <= br_cdb_gpr_tag;
    cdb_gpr_data_bus(2) <= br_cdb_gpr_data;

    -- =========================================================
    -- 3. FETCH PIPELINE
    -- =========================================================
    Fetch_Inst : entity work.instruction_fetch
        port map (
            clk          => clk,
            rst          => rst,
            
            stall_fetch  => pipeline_stall,
            
            pc_bran      => if_pc_bran,
            sel          => if_sel,
            
            instruct1    => if_inst1,
            instruct2    => if_inst2,
            
            pc1_out      => if_pc1,
            pc2_out      => if_pc2,
            
            valid1       => if_valid1,
            valid2       => if_valid2,
            
            pred_taken1  => if_pred_taken1,
            pred_target1 => if_pred_target1,
            
            pred_taken2  => if_pred_taken2,
            pred_target2 => if_pred_target2
        );

    IF_ID_Latch : entity work.IF_ID
        port map (
            clk           => clk,
            rst           => rst,
            flush         => rob_global_flush,
            stall_fetch   => pipeline_stall,
            
            valid1_in     => if_valid1,
            valid2_in     => if_valid2,
            pc1_in        => if_pc1,
            pc2_in        => if_pc2,
            instruct1_in  => if_inst1,
            instruct2_in  => if_inst2,
            
            valid1_out    => ifid_valid1,
            valid2_out    => ifid_valid2,
            pc1_out       => ifid_pc1,
            pc2_out       => ifid_pc2,
            instruct1_out => ifid_inst1,
            instruct2_out => ifid_inst2
        );

    -- =========================================================
    -- 4. DECODE PIPELINE
    -- =========================================================
    Decode_Inst : entity work.ID_stage
        port map (
            clk          => clk,
            rst          => rst,
            stall_fetch  => pipeline_stall,
            
            valid1_in    => decode_valid_1,
            valid2_in    => decode_valid_2,
            pc1_in       => ifid_pc1,
            pc2_in       => ifid_pc2,
            instruct1_in => ifid_inst1,
            instruct2_in => ifid_inst2,
            
            in_pred_taken1  => if_pred_taken1, -- Bypass IF/ID latch for predict bits
            in_pred_target1 => if_pred_target1,
            in_pred_taken2  => if_pred_taken2,
            in_pred_target2 => if_pred_target2,
            
            op1_valid    => id_op1_valid,
            pc1_out      => id_pc1_out,
            op1          => id_op1,
            imm1         => id_imm1,
            comp_bit1    => id_comp_bit1,
            cz_bits1     => id_cz_bits1,
            
            src1_reg1    => id_src1_reg1,
            src2_reg1    => id_src2_reg1,
            dest_reg1    => id_dest_reg1,
            
            reads_rs1_1  => id_reads_rs1_1,
            reads_rs2_1  => id_reads_rs2_1,
            we_gpr1      => id_we_gpr1,
            dest_is_r0_1 => id_dest_is_r0_1,
            
            we_flag1     => id_we_flag1,
            
            is_alu1      => id_is_alu1,
            is_lsu1      => id_is_lsu1,
            is_branch1   => id_is_branch1,
            is_multimem1 => id_is_multimem1,
            is_store1    => id_is_store1,
            illegal_op1  => id_illegal_op1,
            
            out_pred_taken1 => id_out_pred_taken1,
            out_pred_target1=> id_out_pred_target1,

            -- Slot 2 mappings
            op2_valid    => id_op2_valid,
            pc2_out      => id_pc2_out,
            op2          => id_op2,
            imm2         => id_imm2,
            comp_bit2    => id_comp_bit2,
            cz_bits2     => id_cz_bits2,
            
            src1_reg2    => id_src1_reg2,
            src2_reg2    => id_src2_reg2,
            dest_reg2    => id_dest_reg2,
            
            reads_rs1_2  => id_reads_rs1_2,
            reads_rs2_2  => id_reads_rs2_2,
            we_gpr2      => id_we_gpr2,
            dest_is_r0_2 => id_dest_is_r0_2,
            
            we_flag2     => id_we_flag2,
            
            is_alu2      => id_is_alu2,
            is_lsu2      => id_is_lsu2,
            is_branch2   => id_is_branch2,
            is_multimem2 => id_is_multimem2,
            is_store2    => id_is_store2,
            illegal_op2  => id_illegal_op2,
            
            out_pred_taken2 => id_out_pred_taken2,
            out_pred_target2=> id_out_pred_target2
        );

    ID_RF_Latch : entity work.ID_RF
        port map (
            clk          => clk,
            rst          => rst,
            flush        => rob_global_flush,
            stall_rename => pipeline_stall,
            -- Slot 1 Inputs
            op1_valid    => id_op1_valid,
            pc1_in       => id_pc1_out,
            op1          => id_op1,
            imm1         => id_imm1,
            comp_bit1    => id_comp_bit1,
            cz_bits1     => id_cz_bits1,
            
            src1_reg1    => id_src1_reg1,
            src2_reg1    => id_src2_reg1,
            dest_reg1    => id_dest_reg1,
            
            reads_rs1_1  => id_reads_rs1_1,
            reads_rs2_1  => id_reads_rs2_1,
            we_gpr1      => id_we_gpr1,
            dest_is_r0_1 => id_dest_is_r0_1,
            we_flag1     => id_we_flag1,
            
            is_alu1      => id_is_alu1,
            is_lsu1      => id_is_lsu1,
            is_branch1   => id_is_branch1,
            is_multimem1 => id_is_multimem1,
            is_store1    => id_is_store1,
            illegal_op1  => id_illegal_op1,
            
            in_pred_taken1  => id_out_pred_taken1,
            in_pred_target1 => id_out_pred_target1,

            -- Slot 2 Inputs
            op2_valid    => id_op2_valid,
            pc2_in       => id_pc2_out,
            op2          => id_op2,
            imm2         => id_imm2,
            comp_bit2    => id_comp_bit2,
            cz_bits2     => id_cz_bits2,
            
            src1_reg2    => id_src1_reg2,
            src2_reg2    => id_src2_reg2,
            dest_reg2    => id_dest_reg2,
            
            reads_rs1_2  => id_reads_rs1_2,
            reads_rs2_2  => id_reads_rs2_2,
            we_gpr2      => id_we_gpr2,
            dest_is_r0_2 => id_dest_is_r0_2,
            we_flag2     => id_we_flag2,
            
            is_alu2      => id_is_alu2,
            is_lsu2      => id_is_lsu2,
            is_branch2   => id_is_branch2,
            is_multimem2 => id_is_multimem2,
            is_store2    => id_is_store2,
            illegal_op2  => id_illegal_op2,
            
            in_pred_taken2  => id_out_pred_taken2,
            in_pred_target2 => id_out_pred_target2,

            -- Slot 1 Outputs
            op1_valid_out   => idrf_op1_valid_out,
            pc1_out         => idrf_pc1_out,
            op1_out         => idrf_op1_out,
            imm1_out        => idrf_imm1_out,
            comp_bit1_out   => idrf_comp_bit1_out,
            cz_bits1_out    => idrf_cz_bits1_out,
            
            src1_reg1_out   => idrf_src1_reg1_out,
            src2_reg1_out   => idrf_src2_reg1_out,
            dest_reg1_out   => idrf_dest_reg1_out,
            
            reads_rs1_1_out => idrf_reads_rs1_1_out,
            reads_rs2_1_out => idrf_reads_rs2_1_out,
            we_gpr1_out     => idrf_we_gpr1_out,
            dest_is_r0_1_out=> idrf_dest_is_r0_1_out,
            we_flag1_out    => idrf_we_flag1_out,
            
            is_alu1_out     => idrf_is_alu1_out,
            is_lsu1_out     => idrf_is_lsu1_out,
            is_branch1_out  => idrf_is_branch1_out,
            is_multimem1_out=> idrf_is_multimem1_out,
            is_store1_out   => idrf_is_store1_out,
            illegal_op1_out => idrf_illegal_op1_out,
            
            out_pred_taken1 => idrf_out_pred_taken1,
            out_pred_target1=> idrf_out_pred_target1,

            -- Slot 2 Outputs
            op2_valid_out   => idrf_op2_valid_out,
            pc2_out         => idrf_pc2_out,
            op2_out         => idrf_op2_out,
            imm2_out        => idrf_imm2_out,
            comp_bit2_out   => idrf_comp_bit2_out,
            cz_bits2_out    => idrf_cz_bits2_out,
            
            src1_reg2_out   => idrf_src1_reg2_out,
            src2_reg2_out   => idrf_src2_reg2_out,
            dest_reg2_out   => idrf_dest_reg2_out,
            
            reads_rs1_2_out => idrf_reads_rs1_2_out,
            reads_rs2_2_out => idrf_reads_rs2_2_out,
            we_gpr2_out     => idrf_we_gpr2_out,
            dest_is_r0_2_out=> idrf_dest_is_r0_2_out,
            we_flag2_out    => idrf_we_flag2_out,
            
            is_alu2_out     => idrf_is_alu2_out,
            is_lsu2_out     => idrf_is_lsu2_out,
            is_branch2_out  => idrf_is_branch2_out,
            is_multimem2_out=> idrf_is_multimem2_out,
            is_store2_out   => idrf_is_store2_out,
            illegal_op2_out => idrf_illegal_op2_out,
            
            out_pred_taken2 => idrf_out_pred_taken2,
            out_pred_target2=> idrf_out_pred_target2
        );

    -- =========================================================
    -- 5. RENAME PIPELINE (RR STAGE)
    -- =========================================================
    RR_Inst : entity work.RR_stage
        port map (
            clk          => clk,
            rst          => rst,
            flush        => rob_global_flush,
            stall_out    => rr_stall_out,
            
            -- Inputs from ID_RF Slot 1
            op1_valid_in => idrf_op1_valid_out,
            pc1_in       => idrf_pc1_out,
            op1_in       => idrf_op1_out,
            imm1_in      => idrf_imm1_out,
            comp_bit1_in => idrf_comp_bit1_out,
            cz_bits1_in  => idrf_cz_bits1_out,
            
            src1_reg1_in => idrf_src1_reg1_out,
            src2_reg1_in => idrf_src2_reg1_out,
            dest_reg1_in => idrf_dest_reg1_out,
            
            reads_rs1_1_in=> idrf_reads_rs1_1_out,
            reads_rs2_1_in=> idrf_reads_rs2_1_out,
            we_gpr1_in   => idrf_we_gpr1_out,
            dest_is_r0_1_in=> idrf_dest_is_r0_1_out,
            we_flag1_in  => idrf_we_flag1_out,
            
            is_alu1_in   => idrf_is_alu1_out,
            is_lsu1_in   => idrf_is_lsu1_out,
            is_branch1_in=> idrf_is_branch1_out,
            is_multimem1_in=> idrf_is_multimem1_out,
            is_store1_in => idrf_is_store1_out,
            illegal_op1_in=> idrf_illegal_op1_out,
            
            in_pred_taken1=> idrf_out_pred_taken1,
            in_pred_target1=> idrf_out_pred_target1,

            -- Inputs from ID_RF Slot 2
            op2_valid_in => idrf_op2_valid_out,
            pc2_in       => idrf_pc2_out,
            op2_in       => idrf_op2_out,
            imm2_in      => idrf_imm2_out,
            comp_bit2_in => idrf_comp_bit2_out,
            cz_bits2_in  => idrf_cz_bits2_out,
            
            src1_reg2_in => idrf_src1_reg2_out,
            src2_reg2_in => idrf_src2_reg2_out,
            dest_reg2_in => idrf_dest_reg2_out,
            
            reads_rs1_2_in=> idrf_reads_rs1_2_out,
            reads_rs2_2_in=> idrf_reads_rs2_2_out,
            we_gpr2_in   => idrf_we_gpr2_out,
            dest_is_r0_2_in=> idrf_dest_is_r0_2_out,
            we_flag2_in  => idrf_we_flag2_out,
            
            is_alu2_in   => idrf_is_alu2_out,
            is_lsu2_in   => idrf_is_lsu2_out,
            is_branch2_in=> idrf_is_branch2_out,
            is_multimem2_in=> idrf_is_multimem2_out,
            is_store2_in => idrf_is_store2_out,
            illegal_op2_in=> idrf_illegal_op2_out,
            
            in_pred_taken2=> idrf_out_pred_taken2,
            in_pred_target2=> idrf_out_pred_target2,

            -- ROB and RRAT Connections
            rob_tail_id1_in => rob_tail_id1_sig, -- it was jus rob_tail_id1 
            rob_tail_id2_in => rob_tail_id2_sig, -- it was same as above _id2
            rob_free_count  => rob_free_count,
            
            commit_rat_flat => cmt_rat_flat,
            commit_flag_tag => cmt_flag_tag,
            commit_gpr_mask => cmt_gpr_mask,
            commit_flag_mask=> cmt_flag_mask,
            
            free_gpr1_en    => free_gpr1_en,
            free_gpr1_tag   => free_gpr1_tag,
            free_gpr2_en    => free_gpr2_en,
            free_gpr2_tag   => free_gpr2_tag,
            free_f1_en      => free_f1_en,
            free_f1_tag     => free_f1_tag,
            free_f2_en      => free_f2_en,
            free_f2_tag     => free_f2_tag,

            -- CDB Snooping
            wb_gpr1_en      => cdb_gpr_en_bus(0),
            wb_gpr1_tag     => cdb_gpr_tag_bus(0),
            wb_gpr2_en      => cdb_gpr_en_bus(1),
            wb_gpr2_tag     => cdb_gpr_tag_bus(1),
            wb_gpr3_en      => cdb_gpr_en_bus(2),
            wb_gpr3_tag     => cdb_gpr_tag_bus(2),
            wb_f1_en        => cdb_flag_en_bus(0),
            wb_f1_tag       => cdb_flag_tag_bus(0),
            wb_f2_en        => cdb_flag_en_bus(1),
            wb_f2_tag       => cdb_flag_tag_bus(1),

            -- Outputs Slot 1 (To Dispatch Latch)
            dispatch_valid1_out=> rr_dispatch_valid1_out,
            pc1_out            => rr_pc1_out,
            op1_out            => rr_op1_out,
            imm1_out           => rr_imm1_out,
            comp_bit1_out      => rr_comp_bit1_out,
            cz_bits1_out       => rr_cz_bits1_out,
            
            reads_rs1_1_out    => rr_reads_rs1_1_out,
            reads_rs2_1_out    => rr_reads_rs2_1_out,
            dest_is_r0_1_out   => rr_dest_is_r0_1_out,
            we_gpr1_out        => rr_we_gpr1_out,
            we_flag1_out       => rr_we_flag1_out,
            
            is_alu1_out        => rr_is_alu1_out,
            is_lsu1_out        => rr_is_lsu1_out,
            is_branch1_out     => rr_is_branch1_out,
            is_multimem1_out   => rr_is_multimem1_out,
            is_store1_out      => rr_is_store1_out,
            illegal_op1_out    => rr_illegal_op1_out,
            
            prs1_out           => rr_prs1_out,
            prt1_out           => rr_prt1_out,
            prs1_rdy           => rr_prs1_rdy,
            prt1_rdy           => rr_prt1_rdy,
            pr_flag1_out       => rr_pr_flag1_out,
            pr_flag1_rdy       => rr_pr_flag1_rdy,
            pd1_new            => rr_pd1_new,
            pd1_old            => rr_pd1_old,
            pf1_new            => rr_pf1_new,
            pf1_old            => rr_pf1_old,
            rob_id1_out        => rr_rob_id1_out,
            
            arch_dest1         => rr_arch_dest1,
            
            out_pred_taken1    => rr_out_pred_taken1,
            out_pred_target1   => rr_out_pred_target1,

            -- Outputs Slot 2
            dispatch_valid2_out=> rr_dispatch_valid2_out,
            pc2_out            => rr_pc2_out,
            op2_out            => rr_op2_out,
            imm2_out           => rr_imm2_out,
            comp_bit2_out      => rr_comp_bit2_out,
            cz_bits2_out       => rr_cz_bits2_out,
            
            reads_rs1_2_out    => rr_reads_rs1_2_out,
            reads_rs2_2_out    => rr_reads_rs2_2_out,
            dest_is_r0_2_out   => rr_dest_is_r0_2_out,
            we_gpr2_out        => rr_we_gpr2_out,
            we_flag2_out       => rr_we_flag2_out,
            
            is_alu2_out        => rr_is_alu2_out,
            is_lsu2_out        => rr_is_lsu2_out,
            is_branch2_out     => rr_is_branch2_out,
            is_multimem2_out   => rr_is_multimem2_out,
            is_store2_out      => rr_is_store2_out,
            illegal_op2_out    => rr_illegal_op2_out,
            
            prs2_out           => rr_prs2_out,
            prt2_out           => rr_prt2_out,
            prs2_rdy           => rr_prs2_rdy,
            prt2_rdy           => rr_prt2_rdy,
            pr_flag2_out       => rr_pr_flag2_out,
            pr_flag2_rdy       => rr_pr_flag2_rdy,
            pd2_new            => rr_pd2_new,
            pd2_old            => rr_pd2_old,
            pf2_new            => rr_pf2_new,
            pf2_old            => rr_pf2_old,
            rob_id2_out        => rr_rob_id2_out,
            
            arch_dest2         => rr_arch_dest2,
            
            out_pred_taken2    => rr_out_pred_taken2,
            out_pred_target2   => rr_out_pred_target2,
            
            gpr_busy_out    => live_gpr_busy_mask,
            flag_busy_out   => live_flag_busy_mask
        );

    -- =========================================================
    -- 6. DISPATCH PIPELINE
    -- =========================================================
    Dispatch_Latch : entity work.rf_dispatch_latch
        port map (
            clk              => clk,
            rst              => rst,
            stall            => dispatch_stall,
            flush            => rob_global_flush,
            
            -- Input Slot 1
            in_valid1        => rr_dispatch_valid1_out,
            in_pc1           => rr_pc1_out,
            in_op1           => rr_op1_out,
            in_imm1          => rr_imm1_out,
            in_comp_bit1     => rr_comp_bit1_out,
            in_cz_bits1      => rr_cz_bits1_out,
            
            in_reads_rs1_1   => rr_reads_rs1_1_out,
            in_reads_rs2_1   => rr_reads_rs2_1_out,
            in_dest_is_r0_1  => rr_dest_is_r0_1_out,
            in_we_gpr1       => rr_we_gpr1_out,
            in_we_flag1      => rr_we_flag1_out,
            
            in_is_alu1       => rr_is_alu1_out,
            in_is_lsu1       => rr_is_lsu1_out,
            in_is_branch1    => rr_is_branch1_out,
            in_is_multimem1  => rr_is_multimem1_out,
            in_is_store1     => rr_is_store1_out,
            in_illegal_op1   => rr_illegal_op1_out,
            
            in_prs1          => rr_prs1_out,
            in_prt1          => rr_prt1_out,
            in_prs1_rdy      => rr_prs1_rdy,
            in_prt1_rdy      => rr_prt1_rdy,
            
            in_pr_flag1      => rr_pr_flag1_out,
            in_pr_flag1_rdy  => rr_pr_flag1_rdy,
            
            in_pd1_new       => rr_pd1_new,
            in_pd1_old       => rr_pd1_old,
            
            in_pf1_new       => rr_pf1_new,
            in_pf1_old       => rr_pf1_old,
            
            in_rob_id1       => rr_rob_id1_out,
            
            in_arch_dest1    => rr_arch_dest1,
            
            in_pred_taken1   => rr_out_pred_taken1,
            in_pred_target1  => rr_out_pred_target1,

            -- Input Slot 2
            in_valid2        => rr_dispatch_valid2_out,
            in_pc2           => rr_pc2_out,
            in_op2           => rr_op2_out,
            in_imm2          => rr_imm2_out,
            in_comp_bit2     => rr_comp_bit2_out,
            in_cz_bits2      => rr_cz_bits2_out,
            
            in_reads_rs1_2   => rr_reads_rs1_2_out,
            in_reads_rs2_2   => rr_reads_rs2_2_out,
            in_dest_is_r0_2  => rr_dest_is_r0_2_out,
            in_we_gpr2       => rr_we_gpr2_out,
            in_we_flag2      => rr_we_flag2_out,
            
            in_is_alu2       => rr_is_alu2_out,
            in_is_lsu2       => rr_is_lsu2_out,
            in_is_branch2    => rr_is_branch2_out,
            in_is_multimem2  => rr_is_multimem2_out,
            in_is_store2     => rr_is_store2_out,
            in_illegal_op2   => rr_illegal_op2_out,
            
            in_prs2          => rr_prs2_out,
            in_prt2          => rr_prt2_out,
            in_prs2_rdy      => rr_prs2_rdy,
            in_prt2_rdy      => rr_prt2_rdy,
            
            in_pr_flag2      => rr_pr_flag2_out,
            in_pr_flag2_rdy  => rr_pr_flag2_rdy,
            
            in_pd2_new       => rr_pd2_new,
            in_pd2_old       => rr_pd2_old,
            
            in_pf2_new       => rr_pf2_new,
            in_pf2_old       => rr_pf2_old,
            
            in_rob_id2       => rr_rob_id2_out,
            
            in_arch_dest2    => rr_arch_dest2,
            
            in_pred_taken2   => rr_out_pred_taken2,
            in_pred_target2  => rr_out_pred_target2,

            -- Output Slot 1
            out_valid1       => disp_in_valid1,
            -- (Routing outputs to router)
            out_pc1          => disp_in_pc1_out,
            out_op1          => disp_in_op1_out,
            out_imm1         => disp_in_imm1_out,
            out_comp_bit1    => disp_in_comp_bit1_out,
            out_cz_bits1     => disp_in_cz_bits1_out,
            
            out_reads_rs1_1  => disp_in_reads_rs1_1_out, -- Mapped safely in router normally
            out_reads_rs2_1  => disp_in_reads_rs2_1_out, 
            out_dest_is_r0_1 => disp_in_dest_is_r0_1_out,
            out_we_gpr1      => disp_in_we_gpr1_out,
            out_we_flag1     => disp_in_we_flag1_out,
            
            out_is_alu1      => disp_in_is_alu1_out,
            out_is_lsu1      => disp_in_is_lsu1_out,
            out_is_branch1   => disp_in_is_branch1_out,
            out_is_multimem1 => disp_in_is_multimem1_out,
            out_is_store1    => disp_in_is_store1_out,
            out_illegal_op1  => disp_in_illegal_op1_out,
            
            out_prs1         => disp_in_prs1_out,
            out_prt1         => disp_in_prt1_out,
            out_prs1_rdy     => disp_in_prs1_rdy,
            out_prt1_rdy     => disp_in_prt1_rdy,
            
            out_pr_flag1     => disp_in_pr_flag1_out,
            out_pr_flag1_rdy => disp_in_pr_flag1_rdy,
            
            out_pd1_new      => disp_in_pd1_new,
            out_pd1_old      => disp_in_pd1_old,
            
            out_pf1_new      => disp_in_pf1_new,
            out_pf1_old      => disp_in_pf1_old,
            
            out_rob_id1      => disp_in_rob_id1_out,
            
            out_arch_dest1   => disp_in_arch_dest1,
            
            out_pred_taken1  => disp_in_out_pred_taken1,
            out_pred_target1 => disp_in_out_pred_target1,

            -- Output Slot 2
            out_valid2       => disp_in_valid2,
            -- (Routing outputs to router)
            out_pc2          => disp_in_pc2_out,
            out_op2          => disp_in_op2_out,
            out_imm2         => disp_in_imm2_out,
            out_comp_bit2    => disp_in_comp_bit2_out,
            out_cz_bits2     => disp_in_cz_bits2_out,
            
            out_reads_rs1_2  => disp_in_reads_rs1_2_out, -- Mapped safely in router normally
            out_reads_rs2_2  => disp_in_reads_rs2_2_out, 
            out_dest_is_r0_2 => disp_in_dest_is_r0_2_out,
            out_we_gpr2      => disp_in_we_gpr2_out,
            out_we_flag2     => disp_in_we_flag2_out,
            
            out_is_alu2      => disp_in_is_alu2_out,
            out_is_lsu2      => disp_in_is_lsu2_out,
            out_is_branch2   => disp_in_is_branch2_out,
            out_is_multimem2 => disp_in_is_multimem2_out,
            out_is_store2    => disp_in_is_store2_out,
            out_illegal_op2  => disp_in_illegal_op2_out,
            
            out_prs2         => disp_in_prs2_out,
            out_prt2         => disp_in_prt2_out,
            out_prs2_rdy     => disp_in_prs2_rdy,
            out_prt2_rdy     => disp_in_prt2_rdy,
            
            out_pr_flag2     => disp_in_pr_flag2_out,
            out_pr_flag2_rdy => disp_in_pr_flag2_rdy,
            
            out_pd2_new      => disp_in_pd2_new,
            out_pd2_old      => disp_in_pd2_old,
            
            out_pf2_new      => disp_in_pf2_new,
            out_pf2_old      => disp_in_pf2_old,
            
            out_rob_id2      => disp_in_rob_id2_out,
            
            out_arch_dest2   => disp_in_arch_dest2,
            
            out_pred_taken2  => disp_in_out_pred_taken2,
            out_pred_target2 => disp_in_out_pred_target2
        );

    Disp_Router : entity work.dispatch_router
        port map(
            valid1_in       => disp_in_valid1,
            pc1             => disp_in_pc1_out,  
            op1             => disp_in_op1_out, 
            imm1            => disp_in_imm1_out,  
            comp_bit1       => disp_in_comp_bit1_out,
            cz_bits1        => disp_in_cz_bits1_out, 
            
            in_reads_rs1_1  => disp_in_reads_rs1_1_out,
            in_reads_rs2_1  => disp_in_reads_rs2_1_out,
            in_dest_is_r0_1 => disp_in_dest_is_r0_1_out,
            in_we_gpr1      => disp_in_we_gpr1_out,
            in_we_flag1     => disp_in_we_flag1_out,
            is_alu1         => disp_in_is_alu1_out,
            is_lsu1         => disp_in_is_lsu1_out,
            is_branch1      => disp_in_is_branch1_out,
            in_is_multimem1 => disp_in_is_multimem1_out,
            in_is_store1    => disp_in_is_store1_out,
            in_illegal_op1  => disp_in_illegal_op1_out,
            
            prs1_tag        => disp_in_prs1_out, 
            prt1_tag        => disp_in_prt1_out, 
            prs1_rdy        => disp_in_prs1_rdy,
            prt1_rdy        => disp_in_prt1_rdy,
            pr_flag1_tag    => disp_in_pr_flag1_out, 
            pr_flag1_rdy    => disp_in_pr_flag1_rdy,
            
            pd1_new         => disp_in_pd1_new, 
            pd1_old         => disp_in_pd1_old, 
            pf1_new         => disp_in_pf1_new, 
            pf1_old         => disp_in_pf1_old,
            
            rob_id1         => disp_in_rob_id1_out,
            
            arch_dest1      => disp_in_arch_dest1,
             
            pred_taken1     => disp_in_out_pred_taken1,
            pred_target1    => disp_in_out_pred_target1 , 
            
            valid2_in       => disp_in_valid2,
            pc2             => disp_in_pc2_out,  
            op2             => disp_in_op2_out, 
            imm2            => disp_in_imm2_out,  
            comp_bit2       => disp_in_comp_bit2_out,
            cz_bits2        => disp_in_cz_bits2_out, 
            
            in_reads_rs1_2  => disp_in_reads_rs1_2_out,
            in_reads_rs2_2  => disp_in_reads_rs2_2_out,
            in_dest_is_r0_2 => disp_in_dest_is_r0_2_out,
            in_we_gpr2      => disp_in_we_gpr2_out,
            in_we_flag2     => disp_in_we_flag2_out,
            is_alu2         => disp_in_is_alu2_out,
            is_lsu2         => disp_in_is_lsu2_out,
            is_branch2      => disp_in_is_branch2_out,
            in_is_multimem2 => disp_in_is_multimem2_out,
            in_is_store2    => disp_in_is_store2_out,
            in_illegal_op2  => disp_in_illegal_op2_out,
            
            prs2_tag        => disp_in_prs2_out, 
            prt2_tag        => disp_in_prt2_out, 
            prs2_rdy        => disp_in_prs2_rdy,
            prt2_rdy        => disp_in_prt2_rdy,
            pr_flag2_tag    => disp_in_pr_flag2_out, 
            pr_flag2_rdy    => disp_in_pr_flag2_rdy,
            
            pd2_new         => disp_in_pd2_new, 
            pd2_old         => disp_in_pd2_old, 
            pf2_new         => disp_in_pf2_new, 
            pf2_old         => disp_in_pf2_old,
            
            rob_id2         => disp_in_rob_id2_out,
            
            arch_dest2      => disp_in_arch_dest2,
             
            pred_taken2     => disp_in_out_pred_taken2,
            pred_target2    => disp_in_out_pred_target2 , 
           
            live_rob_id1 => rob_tail_id1_sig,
            live_rob_id2 => rob_tail_id2_sig,
            
            gpr_busy_mask    => live_gpr_busy_mask,
            flag_busy_mask   => live_flag_busy_mask,
            
            prf_prs1_data   => prf_r_data_rs1_1,  
            prf_prt1_data   => prf_r_data_rs2_1,  
            prf_flag1_data  => prf_r_flags_1,
            
            prf_prs2_data   => prf_r_data_rs1_2, 
            prf_prt2_data   => prf_r_data_rs2_2,  
            prf_flag2_data  => prf_r_flags_2,
            
            rs_alu_free     => rs_alu_free_slots, 
            rs_lsu_free     => rs_lsu_free_slots,
            rs_branch_free  => rs_br_free_slots,
            dispatch_stall  => dispatch_stall,
            
            rs_alu_port1    => rs_alu_port1,
            rs_alu_port2    => rs_alu_port2,
            rs_lsu_port1    => rs_lsu_port1,
            rs_lsu_port2    => rs_lsu_port2,
            rs_br_port1     => rs_br_port1,
            rs_br_port2     => rs_br_port2
        );
    -- =========================================================
    -- 7. RESERVATION STATIONS
    -- =========================================================
    
    RS_ALU_Inst : entity work.RS_ALU
        port map (
            clk          => clk,
            rst          => rst,
            flush        => rob_global_flush,
            
            disp_port1   => rs_alu_port1,
            disp_port2   => rs_alu_port2,
            free_slots   => rs_alu_free_slots,
            
            cdb_gpr_en   => cdb_gpr_en_bus,
            cdb_gpr_tag  => cdb_gpr_tag_bus,
            cdb_gpr_data => cdb_gpr_data_bus,
            
            cdb_flag_en  => cdb_flag_en_bus,
            cdb_flag_tag => cdb_flag_tag_bus,
            cdb_flag_data=> cdb_flag_data_bus,
            
            issue_valid  => issue_alu_valid,
            issue_packet => issue_alu_pkt
        );

    RS_Branch_Inst : entity work.RS_Branch
        port map (
            clk               => clk,
            rst               => rst,
            
            flush             => rob_global_flush,
            
            disp_port1        => rs_br_port1,
            disp_port2        => rs_br_port2,
            
            branch_free_slots => rs_br_free_slots,
            
            cdb_gpr_en        => cdb_gpr_en_bus,
            cdb_gpr_tag       => cdb_gpr_tag_bus,
            cdb_gpr_data      => cdb_gpr_data_bus,
            
            cdb_flag_en       => cdb_flag_en_bus(0), 
            cdb_flag_tag      => cdb_flag_tag_bus(0),
            cdb_flag_data     => cdb_flag_data_bus(0),
            
            issue_valid       => issue_br_valid,
            issue_packet      => issue_br_pkt
        );
        
    RS_LSU_Inst : entity work.RS_LSU
        port map (
            clk             => clk,
            rst             => rst,
            flush           => rob_global_flush,
            
            disp_port1      => rs_lsu_port1,
            disp_port2      => rs_lsu_port2,
            lsu_free_slots  => rs_lsu_free_slots,
            
            cdb_gpr_en      => cdb_gpr_en_bus,
            cdb_gpr_tag     => cdb_gpr_tag_bus,
            cdb_gpr_data    => cdb_gpr_data_bus,
            
            issue_valid     => rs_to_agu_valid,
            issue_is_store  => rs_to_agu_is_store,
            issue_packet    => rs_to_agu_packet
        );
    -- =========================================================
    -- 8. EXECUTION UNITS
    -- =========================================================
    ALU_Exec_Inst : entity work.alu_execution_unit
        port map (
            clk             => clk,
            rst             => rst,
            
            issue_valid     => issue_alu_valid,
            issue_in        => issue_alu_pkt,
            
            cdb_gpr_en      => alu_cdb_gpr_en,
            cdb_gpr_tag     => alu_cdb_gpr_tag,
            cdb_gpr_data    => alu_cdb_gpr_data,
            
            cdb_flag_en     => alu_cdb_flag_en,
            cdb_flag_tag    => alu_cdb_flag_tag,
            cdb_flag_data   => alu_cdb_flag_data,
            
            rob_complete_en => alu_rob_en,
            rob_id_out      => alu_rob_id,
            rob_gpr_data    => alu_rob_gpr_data,
            rob_flag_data   => alu_rob_flag_data,
            rob_cond_fail   => alu_rob_cond_fail
        );

    Branch_Exec_Inst : entity work.Branch_Execution_Unit
        port map (
            clk                 => clk,
            rst                 => rst,
            
            issue_valid         => issue_br_valid,
            issue_packet        => issue_br_pkt,
            
            cdb_gpr_en          => br_cdb_gpr_en,
            cdb_gpr_tag         => br_cdb_gpr_tag,
            cdb_gpr_data        => br_cdb_gpr_data,
            
            rob_complete_en     => br_rob_en,
            rob_id_out          => br_rob_id,
            rob_gpr_data        => br_rob_gpr_data,
            
            rob_is_branch       => br_rob_is_branch,
            rob_mispredicted    => br_rob_mispred,
            rob_correct_target  => br_correct_target_sig 
        );
    
    AGU_Inst : entity work.AGU
        port map (
            clk             => clk,
            rst             => rst,
            flush           => rob_global_flush,
            
            -- Inputs from RS_LSU
            issue_valid     => rs_to_agu_valid,
            issue_is_store  => rs_to_agu_is_store,
            issue_packet    => rs_to_agu_packet,
            
            -- Outputs to Queues
            agu_valid       => agu_out_valid,
            agu_is_store    => agu_out_is_store,
            agu_addr        => agu_out_addr,
            agu_packet      => agu_out_packet
        );

    -- 3. LOAD QUEUE
    Load_Queue_Inst : entity work.Load_Queue
        port map (
            clk             => clk,
            rst             => rst,
            flush           => rob_global_flush,
            
            -- Inputs from AGU
            agu_valid       => agu_out_valid,
            agu_is_store    => agu_out_is_store,
            agu_addr        => agu_out_addr,
            agu_packet      => agu_out_packet,
            
            sq_state_in     => sq_state_bus,
            
            ram_read_en     => lq_ram_read_en,
            ram_read_addr   => lq_ram_read_addr,
            ram_data_in     => lq_ram_data_in,
            
            cdb_gpr_en      => lq_cdb_gpr_en,
            cdb_gpr_tag     => lq_cdb_gpr_tag,
            cdb_gpr_data    => lq_cdb_gpr_data,
            
            cdb_flag_en     => lq_cdb_flag_en,
            cdb_flag_tag    => lq_cdb_flag_tag,
            cdb_flag_data   => lq_cdb_flag_data,
            
            rob_complete_en => lq_rob_en,
            rob_id_out      => lq_rob_id,
            rob_gpr_data    => lq_rob_gpr_data,
            rob_flag_data   => lq_rob_flag_data
        );

    -- 4. STORE QUEUE
    Store_Queue_Inst : entity work.Store_Queue
        port map (
            clk             => clk,
            rst             => rst,
            flush           => rob_global_flush,
            
            -- Inputs from AGU
            agu_valid       => agu_out_valid,
            agu_is_store    => agu_out_is_store,
            agu_addr        => agu_out_addr,
            agu_packet      => agu_out_packet,
            
            -- Snoop CDB for missing Store Data
            cdb_gpr_en      => cdb_gpr_en_bus,
            cdb_gpr_tag     => cdb_gpr_tag_bus,
            cdb_gpr_data    => cdb_gpr_data_bus,

            commit_valid    => sq_commit_valid,
            commit_rob_id   => sq_commit_id,
            
            ram_write_en    => sq_ram_write_en,
            ram_write_addr  => sq_ram_write_addr,
            ram_write_data  => sq_ram_write_data,
            
            rob_complete_en => sq_rob_en,
            rob_id_out      => sq_rob_id,
            
            sq_state_out    => sq_state_bus
        );

    -- 5. DATA RAM
    Data_RAM_Inst : entity work.Data_RAM
        port map (
            clk             => clk,
            
            ram_read_en     => lq_ram_read_en,
            ram_read_addr   => lq_ram_read_addr,
            ram_data_out    => actual_ram_data_out,
            
            ram_write_en    => sq_ram_write_en,
            ram_write_addr  => sq_ram_write_addr,
            ram_write_data  => sq_ram_write_data
        );

    -- MMIO Trick: If address is FFFE, read from external GPIO switches
    lq_ram_data_in <= external_gpio_in when (lq_ram_read_addr = x"FFFE") else actual_ram_data_out;
    -- =========================================================
    -- 9. PRF & RECOVERY MEMORY
    -- =========================================================
    PRF_Inst : entity work.PRF
        port map (
            clk            => clk,
            rst            => rst,
            
            -- Instruction 1 Async Reads
            r_tag_rs1_1    => disp_in_prs1_out,     -- FIXED
            r_data_rs1_1   => prf_r_data_rs1_1,
            r_tag_rs2_1    => disp_in_prt1_out,     -- FIXED
            r_data_rs2_1   => prf_r_data_rs2_1,
            r_tag_flag_1   => disp_in_pr_flag1_out, -- FIXED
            r_flags_1      => prf_r_flags_1,
            
            -- Instruction 2 Async Reads
            r_tag_rs1_2    => disp_in_prs2_out,     -- FIXED
            r_data_rs1_2   => prf_r_data_rs1_2,
            r_tag_rs2_2    => disp_in_prt2_out,     -- FIXED
            r_data_rs2_2   => prf_r_data_rs2_2,
            r_tag_flag_2   => disp_in_pr_flag2_out, -- FIXED
            r_flags_2      => prf_r_flags_2,
            
            -- Sync Writes from CDB
            we_alu_gpr     => cdb_gpr_en_bus(0),
            tag_alu_gpr    => cdb_gpr_tag_bus(0),
            data_alu_gpr   => cdb_gpr_data_bus(0),
            
            we_alu_flag    => cdb_flag_en_bus(0),
            tag_alu_flag   => cdb_flag_tag_bus(0),
            data_alu_flag  => cdb_flag_data_bus(0),
            
            we_lsu_gpr     => cdb_gpr_en_bus(1),
            tag_lsu_gpr    => cdb_gpr_tag_bus(1),
            data_lsu_gpr   => cdb_gpr_data_bus(1),
            
            we_lsu_flag    => cdb_flag_en_bus(1),
            tag_lsu_flag   => cdb_flag_tag_bus(1),
            data_lsu_flag  => cdb_flag_data_bus(1),
            
            we_br_gpr      => cdb_gpr_en_bus(2),
            tag_br_gpr     => cdb_gpr_tag_bus(2),
            data_br_gpr    => cdb_gpr_data_bus(2)
        );

    -- =========================================================
    -- REORDER BUFFER (ROB) - Perfectly Matched to your Entity!
    -- =========================================================
    -- =========================================================
    -- RAW PACKET BUILDERS FOR ROB DISPATCH
    -- (The ROB needs to see EVERY instruction, not just ALU ops!)
    -- =========================================================
    rob_disp_packet_1.pc        <= disp_in_pc1_out;
    rob_disp_packet_1.op        <= disp_in_op1_out;
    rob_disp_packet_1.pd_new    <= disp_in_pd1_new;
    rob_disp_packet_1.arch_dest <= disp_in_arch_dest1;
    rob_disp_packet_1.we_gpr    <= disp_in_we_gpr1_out;
    rob_disp_packet_1.we_flag   <= disp_in_we_flag1_out;
    rob_disp_packet_1.pf_new    <= disp_in_pf1_new;

    rob_disp_packet_2.pc        <= disp_in_pc2_out;
    rob_disp_packet_2.op        <= disp_in_op2_out;
    rob_disp_packet_2.pd_new    <= disp_in_pd2_new;
    rob_disp_packet_2.arch_dest <= disp_in_arch_dest2;
    rob_disp_packet_2.we_gpr    <= disp_in_we_gpr2_out;
    rob_disp_packet_2.we_flag   <= disp_in_we_flag2_out;
    rob_disp_packet_2.pf_new    <= disp_in_pf2_new;
    
    ROB_Inst : entity work.ROB
        port map (
            clk                 => clk,
            rst                 => rst,

            -- Global Flush
            global_flush        => rob_global_flush,
            flush_target_pc     => rob_flush_target_pc,

            -- 1. DISPATCH INTERFACE
            disp_valid_1        => disp_in_valid1,     -- Latched valid
            disp_packet_1       => rob_disp_packet_1,  -- Raw pre-router packet!
            
            disp_valid_2        => disp_in_valid2,     -- Latched valid
            disp_packet_2       => rob_disp_packet_2,  -- Raw pre-router packet!
            
            dispatch_stall =>   dispatch_stall,
            
            rob_tail_id1         => rob_tail_id1_sig, -- this changed and added change old one was rob_tail_id_sig
            rob_tail_id2         => rob_tail_id2_sig, -- where are we sending this signals
            
            rob_full            => rob_full_sig,
            rob_free_count      => rob_free_count,
            -- 2. COMPLETION BUSES
            -- ALU
            alu_complete        => alu_rob_en,
            alu_rob_id          => alu_rob_id,
            alu_data            => alu_cdb_gpr_data,
            alu_flags           => alu_cdb_flag_data,
            alu_cond_fail       => alu_rob_cond_fail, -- for contion fail safe
            -- LSU
            lsu_complete        => lq_rob_en,
            lsu_rob_id          => lq_rob_id,
            lsu_data            => lq_cdb_gpr_data,
            lsu_flags           => lq_cdb_flag_data,
            
            -- Branch
            br_complete         => br_rob_en,
            br_rob_id           => br_rob_id,
            br_data             => br_cdb_gpr_data,
            br_mispredicted     => br_rob_mispred,
            br_correct_target   => br_correct_target_sig,
            
            sq_complete         => sq_rob_en,
            sq_rob_id           => sq_rob_id,
            -- 3. COMMIT INTERFACE
            commit_valid_1      => cmt_val_1,
            commit_arch_dest_1  => cmt_dest_1,
            commit_pd_1         => cmt_pd_1,
            commit_data_1 => cmt_data_1,
            
            commit_flag_valid_1 => cmt_flag_val_1, -- NEWLY CONNECTED
            commit_pf_1         => cmt_pf_1,       -- NEWLY CONNECTED
            commit_flag_1 => cmt_flag_1,

            commit_valid_2      => cmt_val_2,
            commit_arch_dest_2  => cmt_dest_2,
            commit_pd_2         => cmt_pd_2,
            commit_data_2 => cmt_data_2,
            
            commit_flag_valid_2 => cmt_flag_val_2, -- NEWLY CONNECTED
            commit_pf_2         => cmt_pf_2,       -- NEWLY CONNECTED
            commit_flag_2 => cmt_flag_2,
            
            commit_store_valid  => sq_commit_valid, -- Will connect to Store Queue later
            commit_store_id     => sq_commit_id
        );

    RRAT_Inst : entity work.RRAT
        port map (
            clk                 => clk,
            rst                 => rst,
            
            commit_valid_1      => cmt_val_1,
            commit_arch_dest_1  => cmt_dest_1,
            commit_pd_1         => cmt_pd_1,
            commit_flag_valid_1 => cmt_flag_val_1,
            commit_pf_1         => cmt_pf_1,
            
            commit_valid_2      => cmt_val_2,
            commit_arch_dest_2  => cmt_dest_2,
            commit_pd_2         => cmt_pd_2,
            commit_flag_valid_2 => cmt_flag_val_2,
            commit_pf_2         => cmt_pf_2,
            
            free_gpr1_en        => free_gpr1_en,
            free_gpr1_tag       => free_gpr1_tag,
            free_gpr2_en        => free_gpr2_en,
            free_gpr2_tag       => free_gpr2_tag,
            
            free_f1_en          => free_f1_en,
            free_f1_tag         => free_f1_tag,
            free_f2_en          => free_f2_en,
            free_f2_tag         => free_f2_tag,
            
            commit_rat_flat     => cmt_rat_flat,
            commit_flag_tag     => cmt_flag_tag,
            commit_gpr_mask     => cmt_gpr_mask,
            commit_flag_mask    => cmt_flag_mask
        );
        
        -- We assume LQ and SQ won't complete on the exact same clock cycle.
--    lsu_combined_rob_en <= lq_rob_en or sq_rob_en;
--    lsu_combined_rob_id <= lq_rob_id when lq_rob_en = '1' else sq_rob_id(4 downto 0);

    -- =========================================================
    -- 14. TOP-LEVEL OUTPUT DRIVERS (GPIO & Debug)
    -- =========================================================
    -- Driving the Debug Pins
    debug_fetch_pc      <= if_pc1;
    debug_commit_valid1  <= cmt_val_1;
    debug_commit_valid2  <= cmt_val_2;
    -- We output the physical tag of the committed instruction for debugging
    debug_commit_data1   <= cmt_data_1;
    debug_commit_data2   <= cmt_data_2;
    debug_commit_flag1   <= cmt_flag_1;
    debug_commit_flag2   <= cmt_flag_2;
    debug_global_flush  <= rob_global_flush;
    
    debug_stall_signals(0) <= pipeline_stall;
    debug_stall_signals(1) <= rr_stall_out;
    debug_stall_signals(2) <= dispatch_stall;
    debug_stall_signals(3) <= rob_full_sig;
    -- Driving the Memory-Mapped LEDs (Address 0xFFFF)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                external_gpio_out <= (others => '0');
            else
                -- If Store Queue writes to 0xFFFF, turn on the LEDs!
                if sq_ram_write_en = '1' and sq_ram_write_addr = x"FFFF" then
                    external_gpio_out <= sq_ram_write_data;
                end if;
            end if;
        end if;
    end process;
    
end Structural;