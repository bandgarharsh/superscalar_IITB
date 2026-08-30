library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL; 

entity dispatch_router is
    Port (
        valid1_in       : in std_logic;
        pc1             : in std_logic_vector(15 downto 0);
        op1             : in std_logic_vector(3 downto 0);
        imm1            : in std_logic_vector(15 downto 0);
        comp_bit1       : in std_logic;
        cz_bits1        : in std_logic_vector(1 downto 0);
        
        in_reads_rs1_1   : in std_logic; 
        in_reads_rs2_1   : in std_logic;
        in_dest_is_r0_1  : in std_logic;
        in_we_gpr1       : in std_logic;
        in_we_flag1      : in std_logic; 
        is_alu1         : in std_logic;
        is_lsu1         : in std_logic;
        is_branch1      : in std_logic;
        in_is_multimem1  : in std_logic;
        in_is_store1     : in std_logic; 
        in_illegal_op1   : in std_logic; 
        
        prs1_tag        : in std_logic_vector(4 downto 0);
        prt1_tag        : in std_logic_vector(4 downto 0);
        prs1_rdy        : in std_logic;
        prt1_rdy        : in std_logic;
        pr_flag1_tag    : in std_logic_vector(4 downto 0);
        pr_flag1_rdy    : in std_logic;
        
        pd1_new         : in std_logic_vector(4 downto 0);
        pd1_old         : in std_logic_vector(4 downto 0);
        pf1_new         : in std_logic_vector(4 downto 0);
        pf1_old         : in std_logic_vector(4 downto 0);
        rob_id1         : in std_logic_vector(3 downto 0); 
        arch_dest1      : in std_logic_vector(2 downto 0);
        pred_taken1      : in std_logic;
        pred_target1     : in std_logic_vector(15 downto 0);
        
        valid2_in       : in std_logic;
        pc2             : in std_logic_vector(15 downto 0);
        op2             : in std_logic_vector(3 downto 0);
        imm2            : in std_logic_vector(15 downto 0);
        comp_bit2       : in std_logic;
        cz_bits2        : in std_logic_vector(1 downto 0);
        
        in_reads_rs1_2   : in std_logic; 
        in_reads_rs2_2   : in std_logic; 
        in_dest_is_r0_2  : in std_logic;
        in_we_gpr2       : in std_logic; 
        in_we_flag2      : in std_logic; 
        is_alu2         : in std_logic;
        is_lsu2         : in std_logic;
        is_branch2      : in std_logic;
        in_is_multimem2  : in std_logic;
        in_is_store2     : in std_logic; 
        in_illegal_op2   : in std_logic;
        
        prs2_tag        : in std_logic_vector(4 downto 0);
        prt2_tag        : in std_logic_vector(4 downto 0);
        prs2_rdy        : in std_logic;
        prt2_rdy        : in std_logic;
        pr_flag2_tag    : in std_logic_vector(4 downto 0);
        pr_flag2_rdy    : in std_logic;
        
        pd2_new         : in std_logic_vector(4 downto 0);
        pd2_old         : in std_logic_vector(4 downto 0);
        pf2_new         : in std_logic_vector(4 downto 0);
        pf2_old         : in std_logic_vector(4 downto 0);
        rob_id2         : in std_logic_vector(3 downto 0);
        arch_dest2      : in std_logic_vector(2 downto 0);
        pred_taken2      : in std_logic;
        pred_target2     : in std_logic_vector(15 downto 0);

        live_rob_id1    : in std_logic_vector(3 downto 0);
        live_rob_id2    : in std_logic_vector(3 downto 0);
        
        -- NEW: LIVE BUSY TABLE SNOOPING!
        gpr_busy_mask   : in std_logic_vector(31 downto 0);
        flag_busy_mask  : in std_logic_vector(31 downto 0);

        prf_prs1_data   : in std_logic_vector(15 downto 0);
        prf_prt1_data   : in std_logic_vector(15 downto 0);
        prf_flag1_data  : in std_logic_vector(1 downto 0);
        prf_prs2_data   : in std_logic_vector(15 downto 0);
        prf_prt2_data   : in std_logic_vector(15 downto 0);
        prf_flag2_data  : in std_logic_vector(1 downto 0);

        rs_alu_free     : in unsigned(1 downto 0); 
        rs_lsu_free     : in unsigned(1 downto 0);
        rs_branch_free  : in unsigned(1 downto 0);
        dispatch_stall  : out std_logic; 
        
        rs_alu_port1    : out dispatch_packet_t;
        rs_alu_port2    : out dispatch_packet_t;
        rs_lsu_port1    : out dispatch_packet_t;
        rs_lsu_port2    : out dispatch_packet_t;
        rs_br_port1     : out dispatch_packet_t;
        rs_br_port2     : out dispatch_packet_t
    );
end dispatch_router;

architecture Combinational of dispatch_router is
    signal alu_needed, lsu_needed, br_needed : unsigned(1 downto 0);
    signal stall_internal : std_logic;
    signal route_to_alu1 : std_logic;
    signal route_to_alu2 : std_logic;
begin

    process(valid1_in, route_to_alu1, valid2_in, route_to_alu2)
    begin
        if (valid1_in = '1' and route_to_alu1 = '1') and (valid2_in = '1' and route_to_alu2 = '1') then alu_needed <= "10";
        elsif (valid1_in = '1' and route_to_alu1 = '1') or (valid2_in = '1' and route_to_alu2 = '1') then alu_needed <= "01";
        else alu_needed <= "00";
        end if;
    end process;

    process(valid1_in, is_lsu1, valid2_in, is_lsu2)
    begin
        if (valid1_in = '1' and is_lsu1 = '1') and (valid2_in = '1' and is_lsu2 = '1') then lsu_needed <= "10";
        elsif (valid1_in = '1' and is_lsu1 = '1') or (valid2_in = '1' and is_lsu2 = '1') then lsu_needed <= "01";
        else lsu_needed <= "00";
        end if;
    end process;

    process(valid1_in, is_branch1, valid2_in, is_branch2)
    begin
        if (valid1_in = '1' and is_branch1 = '1') and (valid2_in = '1' and is_branch2 = '1') then br_needed <= "10";
        elsif (valid1_in = '1' and is_branch1 = '1') or (valid2_in = '1' and is_branch2 = '1') then br_needed <= "01";
        else br_needed <= "00";
        end if;
    end process;

    stall_internal <= '1' when (alu_needed > rs_alu_free) or 
                               (lsu_needed > rs_lsu_free) or 
                               (br_needed > rs_branch_free) else '0';
                               
    dispatch_stall <= stall_internal;
    route_to_alu1 <= '1' when (is_alu1 = '1') or (is_lsu1 = '0' and is_branch1 = '0') else '0';
    route_to_alu2 <= '1' when (is_alu2 = '1') or (is_lsu2 = '0' and is_branch2 = '0') else '0';
    
    -- =================================================================
    -- SLOT 1 LIVE PACKING
    -- =================================================================
    rs_alu_port1.valid       <= valid1_in and route_to_alu1 and (not stall_internal); 
    rs_alu_port1.pc          <= pc1;
    rs_alu_port1.op          <= op1;
    rs_alu_port1.imm         <= imm1;
    rs_alu_port1.comp_bit    <= comp_bit1;
    rs_alu_port1.cz_bits     <= cz_bits1;
    rs_alu_port1.prs_tag    <= prs1_tag;
    rs_alu_port1.prs_data   <= prf_prs1_data;
    rs_alu_port1.prt_tag     <= prt1_tag;
    rs_alu_port1.prt_data    <= prf_prt1_data;
    rs_alu_port1.pr_flag_tag <= pr_flag1_tag;
    rs_alu_port1.pr_flag_data<= prf_flag1_data;
    rs_alu_port1.pd_new      <= pd1_new;
    rs_alu_port1.pf_new      <= pf1_new;
    rs_alu_port1.rob_id      <= live_rob_id1; 
    rs_alu_port1.we_gpr      <= in_we_gpr1  when (is_alu1 = '1' and in_illegal_op1 = '0') else '0';
    rs_alu_port1.we_flag     <= in_we_flag1 when (is_alu1 = '1' and in_illegal_op1 = '0') else '0';
    rs_alu_port1.pred_taken  <= pred_taken1;
    rs_alu_port1.pred_target  <= pred_target1;
    rs_alu_port1.arch_dest    <= arch_dest1;
    
    -- LIVE READINESS CHECKS!
    rs_alu_port1.prs_rdy     <= (not gpr_busy_mask(to_integer(unsigned(prs1_tag)))) or (not in_reads_rs1_1);
    rs_alu_port1.prt_rdy     <= (not gpr_busy_mask(to_integer(unsigned(prt1_tag)))) or (not in_reads_rs2_1);
    rs_alu_port1.pr_flag_rdy <= (not flag_busy_mask(to_integer(unsigned(pr_flag1_tag)))) when (cz_bits1 /= COND_AL) else '1';

    -- ... (DUPLICATE FOR LSU AND BR PORT 1) ...
    rs_lsu_port1.valid       <= valid1_in and is_lsu1 and (not stall_internal) and not(in_illegal_op1);
    rs_lsu_port1.pc <= pc1; rs_lsu_port1.op <= op1; rs_lsu_port1.imm <= imm1; rs_lsu_port1.comp_bit <= comp_bit1; rs_lsu_port1.cz_bits <= cz_bits1;
    rs_lsu_port1.prs_tag <= prs1_tag; rs_lsu_port1.prs_data <= prf_prs1_data; rs_lsu_port1.prt_tag <= prt1_tag; rs_lsu_port1.prt_data <= prf_prt1_data;
    rs_lsu_port1.pr_flag_tag <= pr_flag1_tag; rs_lsu_port1.pr_flag_data <= prf_flag1_data; rs_lsu_port1.pd_new <= pd1_new; rs_lsu_port1.pf_new <= pf1_new;
    rs_lsu_port1.rob_id <= live_rob_id1; rs_lsu_port1.we_gpr <= in_we_gpr1; rs_lsu_port1.we_flag <= in_we_flag1;
    rs_lsu_port1.pred_taken <= pred_taken1; rs_lsu_port1.pred_target <= pred_target1; rs_lsu_port1.arch_dest <= arch_dest1;
    rs_lsu_port1.prs_rdy <= (not gpr_busy_mask(to_integer(unsigned(prs1_tag)))) or (not in_reads_rs1_1);
    rs_lsu_port1.prt_rdy <= (not gpr_busy_mask(to_integer(unsigned(prt1_tag)))) or (not in_reads_rs2_1);
    rs_lsu_port1.pr_flag_rdy <= (not flag_busy_mask(to_integer(unsigned(pr_flag1_tag)))) when (cz_bits1 /= COND_AL) else '1';

    rs_br_port1.valid        <= valid1_in and is_branch1 and (not stall_internal) and not(in_illegal_op1);
    rs_br_port1.pc <= pc1; rs_br_port1.op <= op1; rs_br_port1.imm <= imm1; rs_br_port1.comp_bit <= comp_bit1; rs_br_port1.cz_bits <= cz_bits1;
    rs_br_port1.prs_tag <= prs1_tag; rs_br_port1.prs_data <= prf_prs1_data; rs_br_port1.prt_tag <= prt1_tag; rs_br_port1.prt_data <= prf_prt1_data;
    rs_br_port1.pr_flag_tag <= pr_flag1_tag; rs_br_port1.pr_flag_data <= prf_flag1_data; rs_br_port1.pd_new <= pd1_new; rs_br_port1.pf_new <= pf1_new;
    rs_br_port1.rob_id <= live_rob_id1; rs_br_port1.we_gpr <= in_we_gpr1; rs_br_port1.we_flag <= in_we_flag1;
    rs_br_port1.pred_taken <= pred_taken1; rs_br_port1.pred_target <= pred_target1; rs_br_port1.arch_dest <= arch_dest1;
    rs_br_port1.prs_rdy <= (not gpr_busy_mask(to_integer(unsigned(prs1_tag)))) or (not in_reads_rs1_1);
    rs_br_port1.prt_rdy <= (not gpr_busy_mask(to_integer(unsigned(prt1_tag)))) or (not in_reads_rs2_1);
    rs_br_port1.pr_flag_rdy <= (not flag_busy_mask(to_integer(unsigned(pr_flag1_tag)))) when (cz_bits1 /= COND_AL) else '1';

    -- =================================================================
    -- SLOT 2 LIVE PACKING
    -- =================================================================
    rs_alu_port2.valid       <= valid2_in and route_to_alu2 and (not stall_internal);
    rs_alu_port2.pc          <= pc2;
    rs_alu_port2.op          <= op2;
    rs_alu_port2.imm         <= imm2;
    rs_alu_port2.comp_bit    <= comp_bit2;
    rs_alu_port2.cz_bits     <= cz_bits2;
    rs_alu_port2.prs_tag     <= prs2_tag;
    rs_alu_port2.prs_data    <= prf_prs2_data;
    rs_alu_port2.prt_tag     <= prt2_tag;
    rs_alu_port2.prt_data    <= prf_prt2_data;
    rs_alu_port2.pr_flag_tag <= pr_flag2_tag;
    rs_alu_port2.pr_flag_data<= prf_flag2_data;
    rs_alu_port2.pd_new      <= pd2_new;
    rs_alu_port2.pf_new      <= pf2_new;
    rs_alu_port2.rob_id      <= live_rob_id2; 
    rs_alu_port2.we_gpr      <= in_we_gpr2  when (is_alu2 = '1' and in_illegal_op2 = '0') else '0';
    rs_alu_port2.we_flag     <= in_we_flag2 when (is_alu2 = '1' and in_illegal_op2 = '0') else '0';
    rs_alu_port2.pred_taken  <= pred_taken2;
    rs_alu_port2.pred_target  <= pred_target2;
    rs_alu_port2.arch_dest    <= arch_dest2;

    -- LIVE READINESS CHECKS!
    rs_alu_port2.prs_rdy     <= (not gpr_busy_mask(to_integer(unsigned(prs2_tag)))) or (not in_reads_rs1_2);
    rs_alu_port2.prt_rdy     <= (not gpr_busy_mask(to_integer(unsigned(prt2_tag)))) or (not in_reads_rs2_2);
    rs_alu_port2.pr_flag_rdy <= (not flag_busy_mask(to_integer(unsigned(pr_flag2_tag)))) when (cz_bits2 /= COND_AL) else '1';

    -- ... (DUPLICATE FOR LSU AND BR PORT 2) ...
    rs_lsu_port2.valid       <= valid2_in and is_lsu2 and (not stall_internal) and not(in_illegal_op2);
    rs_lsu_port2.pc <= pc2; rs_lsu_port2.op <= op2; rs_lsu_port2.imm <= imm2; rs_lsu_port2.comp_bit <= comp_bit2; rs_lsu_port2.cz_bits <= cz_bits2;
    rs_lsu_port2.prs_tag <= prs2_tag; rs_lsu_port2.prs_data <= prf_prs2_data; rs_lsu_port2.prt_tag <= prt2_tag; rs_lsu_port2.prt_data <= prf_prt2_data;
    rs_lsu_port2.pr_flag_tag <= pr_flag2_tag; rs_lsu_port2.pr_flag_data <= prf_flag2_data; rs_lsu_port2.pd_new <= pd2_new; rs_lsu_port2.pf_new <= pf2_new;
    rs_lsu_port2.rob_id <= live_rob_id2; rs_lsu_port2.we_gpr <= in_we_gpr2; rs_lsu_port2.we_flag <= in_we_flag2;
    rs_lsu_port2.pred_taken <= pred_taken2; rs_lsu_port2.pred_target <= pred_target2; rs_lsu_port2.arch_dest <= arch_dest2;
    rs_lsu_port2.prs_rdy <= (not gpr_busy_mask(to_integer(unsigned(prs2_tag)))) or (not in_reads_rs1_2);
    rs_lsu_port2.prt_rdy <= (not gpr_busy_mask(to_integer(unsigned(prt2_tag)))) or (not in_reads_rs2_2);
    rs_lsu_port2.pr_flag_rdy <= (not flag_busy_mask(to_integer(unsigned(pr_flag2_tag)))) when (cz_bits2 /= COND_AL) else '1';

    rs_br_port2.valid        <= valid2_in and is_branch2 and (not stall_internal) and not(in_illegal_op2);
    rs_br_port2.pc <= pc2; rs_br_port2.op <= op2; rs_br_port2.imm <= imm2; rs_br_port2.comp_bit <= comp_bit2; rs_br_port2.cz_bits <= cz_bits2;
    rs_br_port2.prs_tag <= prs2_tag; rs_br_port2.prs_data <= prf_prs2_data; rs_br_port2.prt_tag <= prt2_tag; rs_br_port2.prt_data <= prf_prt2_data;
    rs_br_port2.pr_flag_tag <= pr_flag2_tag; rs_br_port2.pr_flag_data <= prf_flag2_data; rs_br_port2.pd_new <= pd2_new; rs_br_port2.pf_new <= pf2_new;
    rs_br_port2.rob_id <= live_rob_id2; rs_br_port2.we_gpr <= in_we_gpr2; rs_br_port2.we_flag <= in_we_flag2;
    rs_br_port2.pred_taken <= pred_taken2; rs_br_port2.pred_target <= pred_target2; rs_br_port2.arch_dest <= arch_dest2;
    rs_br_port2.prs_rdy <= (not gpr_busy_mask(to_integer(unsigned(prs2_tag)))) or (not in_reads_rs1_2);
    rs_br_port2.prt_rdy <= (not gpr_busy_mask(to_integer(unsigned(prt2_tag)))) or (not in_reads_rs2_2);
    rs_br_port2.pr_flag_rdy <= (not flag_busy_mask(to_integer(unsigned(pr_flag2_tag)))) when (cz_bits2 /= COND_AL) else '1';

end Combinational;