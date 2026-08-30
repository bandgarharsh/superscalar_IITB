library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity superscalar_core is
    Port (
        clk : in std_logic;
        rst : in std_logic
    );
end superscalar_core;

architecture Structural of superscalar_core is

    signal flush_pipeline : std_logic;
    signal flush_pc       : std_logic_vector(15 downto 0);
    signal dispatch_stall : std_logic;

    -- ROB Signals
    signal rob_we1, rob_we2         : std_logic;
    signal rob_tag1, rob_tag2       : std_logic_vector(2 downto 0);
    signal rob_packet1, rob_packet2 : std_logic_vector(44 downto 0);
    signal rob_free_slots           : unsigned(5 downto 0);
    signal rob_commit1_valid, rob_commit2_valid : std_logic;
    signal rob_commit1_tag,   rob_commit2_tag   : std_logic_vector(2 downto 0);

    -- Dispatch <-> RS Signals
    signal rs_packet1, rs_packet2 : std_logic_vector(68 downto 0); 
    signal alu_we1, alu_we2, br_we1, br_we2, lsq_we1, lsq_we2 : std_logic;
    signal rs_alu_free, rs_br_free, rs_lsq_free : unsigned(2 downto 0);

    -- CDB Signals
    signal cdb1_valid, cdb2_valid : std_logic;
    signal cdb1_tag, cdb2_tag     : std_logic_vector(4 downto 0);
    signal cdb1_data, cdb2_data   : std_logic_vector(15 downto 0);
    signal cdb1_rob_tag, cdb2_rob_tag : std_logic_vector(2 downto 0);
    signal cdb1_mispredict, cdb2_mispredict : std_logic;
    signal cdb1_target_pc, cdb2_target_pc   : std_logic_vector(15 downto 0);

    -- Latch <-> Dispatch & RS Signals
    signal lat_v1, lat_v2 : std_logic;
    signal lat_op1, lat_op2 : std_logic_vector(3 downto 0);
    signal lat_ra1, lat_ra2 : std_logic_vector(2 downto 0);
    signal lat_pra1, lat_pra2, lat_pflag1, lat_pflag2 : std_logic_vector(4 downto 0);
    signal lat_old_pra1, lat_old_pra2, lat_old_pflag1, lat_old_pflag2 : std_logic_vector(4 downto 0);
    signal lat_weflag1, lat_weflag2 : std_logic;
    signal lat_imm1, lat_imm2 : std_logic_vector(15 downto 0);
    signal lat_cz1, lat_cz2 : std_logic_vector(1 downto 0);
    signal lat_comp1, lat_comp2 : std_logic;
    signal lat_pc1, lat_pc2 : std_logic_vector(15 downto 0);
    
    signal lat_qj1, lat_qk1, lat_qj2, lat_qk2 : std_logic_vector(4 downto 0);
    signal lat_vj_val1, lat_vk_val1, lat_vj_val2, lat_vk_val2 : std_logic;
    signal lat_vj_data1, lat_vk_data1, lat_vj_data2, lat_vk_data2 : std_logic_vector(15 downto 0);

    -- PRF & GVT Structural Loop Signals (To be connected to Front-End modules)
    signal gvt_we1, gvt_we2 : std_logic;
    signal prf_we1, prf_we2 : std_logic;
    
    -- Execution Issue Signals
    signal alu_issue_valid, br_issue_valid, lsq_issue_valid : std_logic;
    signal alu_issue_ready, br_issue_ready, lsq_issue_ready : std_logic := '1';
    signal alu_issue_opcode, br_issue_opcode : std_logic_vector(3 downto 0);
    signal alu_issue_comp : std_logic;
    signal alu_issue_cz : std_logic_vector(1 downto 0);
    signal alu_issue_imm, br_issue_imm, br_issue_pc : std_logic_vector(15 downto 0);
    signal alu_issue_vj, alu_issue_vk, br_issue_vj, br_issue_vk : std_logic_vector(15 downto 0);
    signal alu_issue_dest_pr, br_issue_dest_pr, lsq_issue_dest : std_logic_vector(4 downto 0);
    signal alu_issue_rob_tag, br_issue_rob_tag, lsq_issue_rob : std_logic_vector(2 downto 0);
    signal lsq_issue_is_st : std_logic;
    signal lsq_issue_addr, lsq_issue_data : std_logic_vector(15 downto 0);
    signal alu1_valid, alu2_valid, alu3_valid : std_logic;
    signal alu1_tag, alu2_tag, alu3_tag : std_logic_vector(4 downto 0);
    signal alu1_data, alu2_data, alu3_data : std_logic_vector(15 downto 0);
    signal alu1_rob_tag, alu2_rob_tag, alu3_rob_tag : std_logic_vector(2 downto 0);
    signal alu3_mispredict : std_logic;
    signal alu3_target_pc : std_logic_vector(15 downto 0);

begin

    -- CDB Broadcast loop back to the frontend Registers
    prf_we1 <= cdb1_valid;
    gvt_we1 <= cdb1_valid;
    prf_we2 <= cdb2_valid;
    gvt_we2 <= cdb2_valid;

    -- =========================================================
    -- 1. RF DISPATCH LATCH (Data entry point)
    -- =========================================================
    latch_inst : entity work.rf_dispatch_latch
        port map (
            clk => clk, rst => rst, stall => dispatch_stall, flush => flush_pipeline,
            
            -- Instruction 1 (Stubbed Inputs from Rename)
            in_valid1 => '0', in_op1 => "0000", in_ra1 => "000", in_p_ra1 => "00000", in_p_flag1 => "00000", in_old_p_ra1 => "00000", in_old_p_flag1 => "00000", in_we_flag1 => '0', in_imm1 => x"0000", in_cz1 => "00", in_comp1 => '0', in_pc1 => x"0000",
            in_tag_j1 => "00000", in_tag_k1 => "00000", in_tag_f1 => "00000", in_data_j1 => x"0000", in_valid_j1 => '0', in_data_k1 => x"0000", in_valid_k1 => '0', in_data_f1 => "00", in_valid_f1 => '0',
            
            -- Instruction 2 (Stubbed Inputs from Rename)
            in_valid2 => '0', in_op2 => "0000", in_ra2 => "000", in_p_ra2 => "00000", in_p_flag2 => "00000", in_old_p_ra2 => "00000", in_old_p_flag2 => "00000", in_we_flag2 => '0', in_imm2 => x"0000", in_cz2 => "00", in_comp2 => '0', in_pc2 => x"0000",
            in_tag_j2 => "00000", in_tag_k2 => "00000", in_tag_f2 => "00000", in_data_j2 => x"0000", in_valid_j2 => '0', in_data_k2 => x"0000", in_valid_k2 => '0', in_data_f2 => "00", in_valid_f2 => '0',
            
            -- Latch Outputs to Dispatch
            out_valid1 => lat_v1, out_op1 => lat_op1, out_ra1 => lat_ra1, out_p_ra1 => lat_pra1, out_p_flag1 => lat_pflag1, out_old_p_ra1 => lat_old_pra1, out_old_p_flag1 => lat_old_pflag1, out_we_flag1 => lat_weflag1, out_imm1 => lat_imm1, out_cz1 => lat_cz1, out_comp1 => lat_comp1, out_pc1 => lat_pc1,
            out_valid2 => lat_v2, out_op2 => lat_op2, out_ra2 => lat_ra2, out_p_ra2 => lat_pra2, out_p_flag2 => lat_pflag2, out_old_p_ra2 => lat_old_pra2, out_old_p_flag2 => lat_old_pflag2, out_we_flag2 => lat_weflag2, out_imm2 => lat_imm2, out_cz2 => lat_cz2, out_comp2 => lat_comp2, out_pc2 => lat_pc2,
            
            -- Latch Outputs to Reservation Stations
            out_tag_j1 => lat_qj1, out_tag_k1 => lat_qk1, out_data_j1 => lat_vj_data1, out_valid_j1 => lat_vj_val1, out_data_k1 => lat_vk_data1, out_valid_k1 => lat_vk_val1,
            out_tag_j2 => lat_qj2, out_tag_k2 => lat_qk2, out_data_j2 => lat_vj_data2, out_valid_j2 => lat_vj_val2, out_data_k2 => lat_vk_data2, out_valid_k2 => lat_vk_val2
        );

    -- =========================================================
    -- 2. DISPATCH STAGE
    -- =========================================================
    dispatch_inst : entity work.dispatch_stage
        port map (
            clk => clk, rst => rst, flush => flush_pipeline,
            
            valid1_in => lat_v1, op1_in => lat_op1, ra1_in => lat_ra1, p_ra1 => lat_pra1, p_flag1_dest => lat_pflag1, p_rb1 => lat_qj1, p_rc1 => lat_qk1, pr_flag1 => "00000", old_p_ra1 => lat_old_pra1, old_pr_flag1 => lat_old_pflag1, we_flag1_in => lat_weflag1, imm1_in => lat_imm1, cz1_in => lat_cz1, comp1_in => lat_comp1, pc1_in => lat_pc1,
            valid2_in => lat_v2, op2_in => lat_op2, ra2_in => lat_ra2, p_ra2 => lat_pra2, p_flag2_dest => lat_pflag2, p_rb2 => lat_qj2, p_rc2 => lat_qk2, pr_flag2 => "00000", old_p_ra2 => lat_old_pra2, old_pr_flag2 => lat_old_pflag2, we_flag2_in => lat_weflag2, imm2_in => lat_imm2, cz2_in => lat_cz2, comp2_in => lat_comp2, pc2_in => lat_pc2,

            rob_tag1_in => rob_tag1, rob_tag2_in => rob_tag2,
            rob_free_slots => rob_free_slots, rs_alu_free => rs_alu_free, rs_mem_free => rs_lsq_free, rs_br_free => rs_br_free,
            dispatch_stall => dispatch_stall,
            
            rs_packet1 => rs_packet1, rs_packet2 => rs_packet2,
            rs_alu_valid1 => alu_we1, rs_alu_valid2 => alu_we2, rs_br_valid1 => br_we1, rs_br_valid2 => br_we2, rs_mem_valid1 => lsq_we1, rs_mem_valid2 => lsq_we2,
            
            rob_packet1 => rob_packet1, rob_packet2 => rob_packet2, rob_valid1 => rob_we1, rob_valid2 => rob_we2
        );
        
    -- =========================================================
    -- 3. RESERVATION STATIONS
    -- =========================================================
    alu_rs_inst : entity work.arithmetic_rs
        port map (
            clk => clk, rst => rst, flush => flush_pipeline,
            we1 => alu_we1, rs_packet1 => rs_packet1(63 downto 0), rob_tag1 => rs_packet1(68 downto 64),
            d1_vj_valid => lat_vj_val1, d1_vj_data => lat_vj_data1, d1_vk_valid => lat_vk_val1, d1_vk_data => lat_vk_data1,
            we2 => alu_we2, rs_packet2 => rs_packet2(63 downto 0), rob_tag2 => rs_packet2(68 downto 64),
            d2_vj_valid => lat_vj_val2, d2_vj_data => lat_vj_data2, d2_vk_valid => lat_vk_val2, d2_vk_data => lat_vk_data2,
            
            cdb1_valid => cdb1_valid, cdb1_tag => cdb1_tag, cdb1_data => cdb1_data, cdb2_valid => cdb2_valid, cdb2_tag => cdb2_tag, cdb2_data => cdb2_data,
            issue_ready => alu_issue_ready, issue_valid => alu_issue_valid, issue_opcode => alu_issue_opcode, issue_comp => alu_issue_comp, issue_cz => alu_issue_cz, issue_imm => alu_issue_imm, issue_vj => alu_issue_vj, issue_vk => alu_issue_vk, issue_dest_pr => alu_issue_dest_pr, issue_dest_flag_pr => open, issue_rob_tag => alu_issue_rob_tag, free_slots => rs_alu_free
        );

    branch_rs_inst : entity work.branch_rs
        port map (
            clk => clk, rst => rst, flush => flush_pipeline,
            we1 => br_we1, rs_packet1 => rs_packet1(63 downto 0), rob_tag1 => rs_packet1(68 downto 64),
            d1_vj_valid => lat_vj_val1, d1_vj_data => lat_vj_data1, d1_vk_valid => lat_vk_val1, d1_vk_data => lat_vk_data1,
            we2 => br_we2, rs_packet2 => rs_packet2(63 downto 0), rob_tag2 => rs_packet2(68 downto 64),
            d2_vj_valid => lat_vj_val2, d2_vj_data => lat_vj_data2, d2_vk_valid => lat_vk_val2, d2_vk_data => lat_vk_data2,
            
            cdb1_valid => cdb1_valid, cdb1_tag => cdb1_tag, cdb1_data => cdb1_data, cdb2_valid => cdb2_valid, cdb2_tag => cdb2_tag, cdb2_data => cdb2_data,
            issue_ready => br_issue_ready, issue_valid => br_issue_valid, issue_opcode => br_issue_opcode, issue_pc => br_issue_pc, issue_imm => br_issue_imm, issue_vj => br_issue_vj, issue_vk => br_issue_vk, issue_dest_pr => br_issue_dest_pr, issue_rob_tag => br_issue_rob_tag, free_slots => rs_br_free
        );

    lsq_inst : entity work.load_store_queue
        port map (
            clk => clk, rst => rst, flush => flush_pipeline,
            we1 => lsq_we1, rs_packet1 => rs_packet1(63 downto 0), rob_tag1 => rs_packet1(68 downto 64),
            d1_vbase_valid => lat_vj_val1, d1_vbase_data => lat_vj_data1, d1_vdata_valid => lat_vk_val1, d1_vdata_data => lat_vk_data1,
            we2 => lsq_we2, rs_packet2 => rs_packet2(63 downto 0), rob_tag2 => rs_packet2(68 downto 64),
            d2_vbase_valid => lat_vj_val2, d2_vbase_data => lat_vj_data2, d2_vdata_valid => lat_vk_val2, d2_vdata_data => lat_vk_data2,
            
            cdb1_valid => cdb1_valid, cdb1_tag => cdb1_tag, cdb1_data => cdb1_data, cdb2_valid => cdb2_valid, cdb2_tag => cdb2_tag, cdb2_data => cdb2_data,
            rob_commit1_valid => rob_commit1_valid, rob_commit1_tag => rob_commit1_tag, rob_commit2_valid => rob_commit2_valid, rob_commit2_tag => rob_commit2_tag,
            issue_ready => lsq_issue_ready, issue_valid => lsq_issue_valid, issue_is_st => lsq_issue_is_st, issue_addr => lsq_issue_addr, issue_data => lsq_issue_data, issue_dest => lsq_issue_dest, issue_rob => lsq_issue_rob, available_slots => rs_lsq_free
        );
        
    -- =========================================================
    -- 3. EXECUTION ALUS
    -- =========================================================
    exec_alu_inst : entity work.execution_alu
        port map(
            clk => clk, rst => rst,
            issue_valid => alu_issue_valid, issue_opcode => alu_issue_opcode, issue_comp => alu_issue_comp, issue_cz => alu_issue_cz, 
            issue_imm => alu_issue_imm, issue_vj => alu_issue_vj, issue_vk => alu_issue_vk, issue_dest_pr => alu_issue_dest_pr, issue_rob_tag => alu_issue_rob_tag,
            
            cdb_valid => alu1_valid, cdb_tag => alu1_tag, cdb_data => alu1_data, cdb_rob_tag => alu1_rob_tag,
            cdb_c_flag => open, cdb_z_flag => open
        );

    branch_alu_inst : entity work.branch_alu
        port map(
            clk => clk, rst => rst,
            issue_valid => br_issue_valid, issue_opcode => br_issue_opcode, issue_pc => br_issue_pc, issue_imm => br_issue_imm, 
            issue_vj => br_issue_vj, issue_vk => br_issue_vk, issue_dest_pr => br_issue_dest_pr, issue_rob_tag => br_issue_rob_tag,
            pred_taken => '0', -- Static not-taken prediction
            
            cdb_valid => alu3_valid, cdb_tag => alu3_tag, cdb_data => alu3_data, cdb_rob_tag => alu3_rob_tag,
            cdb_mispredict => alu3_mispredict, cdb_target_pc => alu3_target_pc,
            branch_taken => open, target_pc => open
        );

    ls_alu_inst : entity work.load_store_alu
        port map(
            clk => clk, rst => rst,
            issue_valid => lsq_issue_valid, issue_is_st => lsq_issue_is_st, issue_addr => lsq_issue_addr, issue_data => lsq_issue_data, 
            issue_dest_pr => lsq_issue_dest, issue_rob_tag => lsq_issue_rob,
            
            mem_we => mem_we, mem_addr => mem_addr, mem_data_out => mem_data_out, mem_data_in => mem_data_in,
            
            cdb_valid => alu2_valid, cdb_tag => alu2_tag, cdb_data => alu2_data, cdb_rob_tag => alu2_rob_tag
        );

    -- =========================================================
    -- 4. CDB ARBITER
    -- =========================================================
    cdb_arbiter_inst : entity work.cdb_arbiter
        port map(
            clk => clk, rst => rst,
            
            alu1_valid => alu1_valid, alu1_tag => alu1_tag, alu1_data => alu1_data, alu1_rob_tag => alu1_rob_tag,
            alu2_valid => alu2_valid, alu2_tag => alu2_tag, alu2_data => alu2_data, alu2_rob_tag => alu2_rob_tag,
            alu3_valid => alu3_valid, alu3_tag => alu3_tag, alu3_data => alu3_data, alu3_rob_tag => alu3_rob_tag, alu3_mispredict => alu3_mispredict, alu3_target_pc => alu3_target_pc,
            
            cdb1_valid => cdb1_valid, cdb1_tag => cdb1_tag, cdb1_data => cdb1_data, cdb1_rob_tag => cdb1_rob_tag, cdb1_mispredict => cdb1_mispredict, cdb1_target_pc => cdb1_target_pc,
            cdb2_valid => cdb2_valid, cdb2_tag => cdb2_tag, cdb2_data => cdb2_data, cdb2_rob_tag => cdb2_rob_tag, cdb2_mispredict => cdb2_mispredict, cdb2_target_pc => cdb2_target_pc
        );

    -- =========================================================
    -- 5. REORDER BUFFER (Commit Engine)
    -- =========================================================
    rob_inst : entity work.reorder_buffer
        port map (
            clk => clk, rst => rst, flush => flush_pipeline,
            
            we1 => rob_we1, rob_packet1 => rob_packet1, out_rob_tag1 => rob_tag1,
            we2 => rob_we2, rob_packet2 => rob_packet2, out_rob_tag2 => rob_tag2,
            rob_free_slots => rob_free_slots,
            
            cdb1_valid => cdb1_valid, cdb1_rob_tag => cdb1_rob_tag, cdb1_mispredict => cdb1_mispredict, cdb1_target_pc => cdb1_target_pc,
            cdb2_valid => cdb2_valid, cdb2_rob_tag => cdb2_rob_tag, cdb2_mispredict => cdb2_mispredict, cdb2_target_pc => cdb2_target_pc,
            
            rob_commit1_valid => rob_commit1_valid, rob_commit1_tag => rob_commit1_tag,
            rob_commit2_valid => rob_commit2_valid, rob_commit2_tag => rob_commit2_tag,

            rob_push_gpr1 => open, rob_freed_gpr1 => open, rob_push_flag1 => open, rob_freed_flag1 => open,
            rob_push_gpr2 => open, rob_freed_gpr2 => open, rob_push_flag2 => open, rob_freed_flag2 => open,
            retire1_valid => open, retire1_we_gpr => open, retire1_we_flag => open, retire1_arch_reg => open, retire1_phys_reg => open,
            retire2_valid => open, retire2_we_gpr => open, retire2_we_flag => open, retire2_arch_reg => open, retire2_phys_reg => open,

            flush_pipeline => flush_pipeline,
            flush_pc => flush_pc
        );

end Structural;