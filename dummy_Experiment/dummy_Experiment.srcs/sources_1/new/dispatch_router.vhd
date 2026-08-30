library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; 
use work.iitb_risc_pkg.ALL; 

entity dispatch_router is
    Port (
        clk             : in std_logic; rst : in std_logic;
        valid1_in       : in std_logic; pc1 : in std_logic_vector(15 downto 0); op1 : in std_logic_vector(3 downto 0); imm1 : in std_logic_vector(15 downto 0); comp_bit1 : in std_logic; cz_bits1 : in std_logic_vector(1 downto 0);
        in_reads_rs1_1  : in std_logic; in_reads_rs2_1 : in std_logic; in_dest_is_r0_1 : in std_logic; in_we_gpr1 : in std_logic; in_we_flag1 : in std_logic; 
        is_alu1         : in std_logic; is_lsu1 : in std_logic; is_branch1 : in std_logic; in_is_multimem1 : in std_logic; in_is_store1 : in std_logic; in_illegal_op1 : in std_logic; 
        prs1_tag        : in std_logic_vector(4 downto 0); prt1_tag : in std_logic_vector(4 downto 0); prs1_rdy : in std_logic; prt1_rdy : in std_logic; pr_flag1_tag : in std_logic_vector(4 downto 0); pr_flag1_rdy : in std_logic;
        pd1_new         : in std_logic_vector(4 downto 0); pd1_old : in std_logic_vector(4 downto 0); pf1_new : in std_logic_vector(4 downto 0); pf1_old : in std_logic_vector(4 downto 0); rob_id1 : in std_logic_vector(3 downto 0); arch_dest1 : std_logic_vector(2 downto 0); pred_taken1 : in std_logic; pred_target1 : in std_logic_vector(15 downto 0);
        
        valid2_in       : in std_logic; pc2 : in std_logic_vector(15 downto 0); op2 : in std_logic_vector(3 downto 0); imm2 : in std_logic_vector(15 downto 0); comp_bit2 : in std_logic; cz_bits2 : in std_logic_vector(1 downto 0);
        in_reads_rs1_2  : in std_logic; in_reads_rs2_2 : in std_logic; in_dest_is_r0_2 : in std_logic; in_we_gpr2 : in std_logic; in_we_flag2 : in std_logic; 
        is_alu2         : in std_logic; is_lsu2 : in std_logic; is_branch2 : in std_logic; in_is_multimem2 : in std_logic; in_is_store2 : in std_logic; in_illegal_op2 : in std_logic;
        prs2_tag        : in std_logic_vector(4 downto 0); prt2_tag : in std_logic_vector(4 downto 0); prs2_rdy : in std_logic; prt2_rdy : in std_logic; pr_flag2_tag : in std_logic_vector(4 downto 0); pr_flag2_rdy : in std_logic;
        pd2_new         : in std_logic_vector(4 downto 0); pd2_old : in std_logic_vector(4 downto 0); pf2_new : in std_logic_vector(4 downto 0); pf2_old : in std_logic_vector(4 downto 0); rob_id2 : in std_logic_vector(3 downto 0); arch_dest2 : std_logic_vector(2 downto 0); pred_taken2 : in std_logic; pred_target2 : in std_logic_vector(15 downto 0);

        live_rob_id1    : in std_logic_vector(3 downto 0); live_rob_id2 : in std_logic_vector(3 downto 0);
        gpr_busy_mask   : in std_logic_vector(31 downto 0); flag_busy_mask : in std_logic_vector(31 downto 0);
        prf_prs1_data   : in std_logic_vector(15 downto 0); prf_prt1_data : in std_logic_vector(15 downto 0); prf_flag1_data : in std_logic_vector(1 downto 0);
        prf_prs2_data   : in std_logic_vector(15 downto 0); prf_prt2_data : in std_logic_vector(15 downto 0); prf_flag2_data : in std_logic_vector(1 downto 0);

        rs_alu_free     : in unsigned(1 downto 0); rs_lsu_free : in unsigned(1 downto 0); rs_branch_free : in unsigned(1 downto 0);
        dispatch_stall  : out std_logic; 
        
        rs_alu_port1    : out dispatch_packet_t; rs_alu_port2 : out dispatch_packet_t;
        rs_lsu_port1    : out dispatch_packet_t; rs_lsu_port2 : out dispatch_packet_t;
        rs_br_port1     : out dispatch_packet_t; rs_br_port2  : out dispatch_packet_t
    );
end dispatch_router;

architecture Combinational of dispatch_router is
    signal alu_needed, lsu_needed, br_needed : unsigned(1 downto 0);
    signal stall_internal, route_to_alu1, route_to_alu2 : std_logic;
begin

    process(valid1_in, route_to_alu1, valid2_in, route_to_alu2) begin
        if (valid1_in = '1' and route_to_alu1 = '1') and (valid2_in = '1' and route_to_alu2 = '1') then alu_needed <= "10";
        elsif (valid1_in = '1' and route_to_alu1 = '1') or (valid2_in = '1' and route_to_alu2 = '1') then alu_needed <= "01";
        else alu_needed <= "00"; end if;
    end process;

    process(valid1_in, is_lsu1, valid2_in, is_lsu2) begin
        if (valid1_in = '1' and is_lsu1 = '1') and (valid2_in = '1' and is_lsu2 = '1') then lsu_needed <= "10";
        elsif (valid1_in = '1' and is_lsu1 = '1') or (valid2_in = '1' and is_lsu2 = '1') then lsu_needed <= "01";
        else lsu_needed <= "00"; end if;
    end process;

    process(valid1_in, is_branch1, valid2_in, is_branch2) begin
        if (valid1_in = '1' and is_branch1 = '1') and (valid2_in = '1' and is_branch2 = '1') then br_needed <= "10";
        elsif (valid1_in = '1' and is_branch1 = '1') or (valid2_in = '1' and is_branch2 = '1') then br_needed <= "01";
        else br_needed <= "00"; end if;
    end process;

    stall_internal <= '1' when (alu_needed > rs_alu_free) or (lsu_needed > rs_lsu_free) or (br_needed > rs_branch_free) else '0';
    dispatch_stall <= stall_internal;
    route_to_alu1 <= '1' when (is_alu1 = '1') or (is_lsu1 = '0' and is_branch1 = '0') else '0';
    route_to_alu2 <= '1' when (is_alu2 = '1') or (is_lsu2 = '0' and is_branch2 = '0') else '0';
    
    -- =================================================================
    -- SLOT 1 LIVE PACKING
    -- =================================================================
    rs_alu_port1.valid <= valid1_in and route_to_alu1 and (not stall_internal); 
    rs_alu_port1.pc <= pc1; rs_alu_port1.op <= op1; rs_alu_port1.imm <= imm1; rs_alu_port1.comp_bit <= comp_bit1; rs_alu_port1.cz_bits <= cz_bits1;
    rs_alu_port1.prs_tag <= prs1_tag; rs_alu_port1.prs_data <= prf_prs1_data; rs_alu_port1.prt_tag <= prt1_tag; rs_alu_port1.prt_data <= prf_prt1_data;
    rs_alu_port1.pr_flag_tag <= pr_flag1_tag; rs_alu_port1.pr_flag_data<= prf_flag1_data; rs_alu_port1.pd_new <= pd1_new; rs_alu_port1.pf_new <= pf1_new; rs_alu_port1.rob_id <= live_rob_id1; 
    rs_alu_port1.we_gpr <= in_we_gpr1 when (is_alu1 = '1' and in_illegal_op1 = '0') else '0'; rs_alu_port1.we_flag <= in_we_flag1 when (is_alu1 = '1' and in_illegal_op1 = '0') else '0';
    rs_alu_port1.pred_taken <= pred_taken1; rs_alu_port1.pred_target <= pred_target1; rs_alu_port1.arch_dest <= arch_dest1;
    
    rs_alu_port1.prs_rdy     <= '1' when (op1 = OP_LLI) else (not gpr_busy_mask(to_integer(unsigned(prs1_tag)))) or (not in_reads_rs1_1);
    rs_alu_port1.prt_rdy     <= '1' when (op1 = OP_LLI or op1 = OP_ADI) else (not gpr_busy_mask(to_integer(unsigned(prt1_tag)))) or (not in_reads_rs2_1);
    
    -- THE BUG FIX: Flawless Flag Dependency Logic
    rs_alu_port1.pr_flag_rdy <= 
        '1' when (op1 /= OP_ADD and op1 /= OP_NDU) else
        '1' when (op1 = OP_ADD and cz_bits1 = COND_AL) else
        not flag_busy_mask(to_integer(unsigned(pr_flag1_tag)));

    rs_lsu_port1.valid <= valid1_in and is_lsu1 and (not stall_internal) and not(in_illegal_op1);
    rs_lsu_port1.pc <= pc1; rs_lsu_port1.op <= op1; rs_lsu_port1.imm <= imm1; rs_lsu_port1.comp_bit <= comp_bit1; rs_lsu_port1.cz_bits <= cz_bits1;
    rs_lsu_port1.prs_tag <= prs1_tag; rs_lsu_port1.prs_data <= prf_prs1_data; rs_lsu_port1.prt_tag <= prt1_tag; rs_lsu_port1.prt_data <= prf_prt1_data;
    rs_lsu_port1.pr_flag_tag <= pr_flag1_tag; rs_lsu_port1.pr_flag_data <= prf_flag1_data; rs_lsu_port1.pd_new <= pd1_new; rs_lsu_port1.pf_new <= pf1_new; rs_lsu_port1.rob_id <= live_rob_id1; rs_lsu_port1.we_gpr <= in_we_gpr1; rs_lsu_port1.we_flag <= in_we_flag1; rs_lsu_port1.pred_taken <= pred_taken1; rs_lsu_port1.pred_target <= pred_target1; rs_lsu_port1.arch_dest <= arch_dest1;
    rs_lsu_port1.prs_rdy <= (not gpr_busy_mask(to_integer(unsigned(prs1_tag)))) or (not in_reads_rs1_1);
    rs_lsu_port1.prt_rdy <= (not gpr_busy_mask(to_integer(unsigned(prt1_tag)))) or (not in_reads_rs2_1);
    rs_lsu_port1.pr_flag_rdy <= '1';

    rs_br_port1.valid <= valid1_in and is_branch1 and (not stall_internal) and not(in_illegal_op1);
    rs_br_port1.pc <= pc1; rs_br_port1.op <= op1; rs_br_port1.imm <= imm1; rs_br_port1.comp_bit <= comp_bit1; rs_br_port1.cz_bits <= cz_bits1;
    rs_br_port1.prs_tag <= prs1_tag; rs_br_port1.prs_data <= prf_prs1_data; rs_br_port1.prt_tag <= prt1_tag; rs_br_port1.prt_data <= prf_prt1_data;
    rs_br_port1.pr_flag_tag <= pr_flag1_tag; rs_br_port1.pr_flag_data <= prf_flag1_data; rs_br_port1.pd_new <= pd1_new; rs_br_port1.pf_new <= pf1_new; rs_br_port1.rob_id <= live_rob_id1; rs_br_port1.we_gpr <= in_we_gpr1; rs_br_port1.we_flag <= in_we_flag1; rs_br_port1.pred_taken <= pred_taken1; rs_br_port1.pred_target <= pred_target1; rs_br_port1.arch_dest <= arch_dest1;
    rs_br_port1.prs_rdy <= (not gpr_busy_mask(to_integer(unsigned(prs1_tag)))) or (not in_reads_rs1_1);
    rs_br_port1.prt_rdy <= (not gpr_busy_mask(to_integer(unsigned(prt1_tag)))) or (not in_reads_rs2_1);
    rs_br_port1.pr_flag_rdy <= '1';

    -- =================================================================
    -- SLOT 2 LIVE PACKING 
    -- =================================================================
    rs_alu_port2.valid <= valid2_in and route_to_alu2 and (not stall_internal);
    rs_alu_port2.pc <= pc2; rs_alu_port2.op <= op2; rs_alu_port2.imm <= imm2; rs_alu_port2.comp_bit <= comp_bit2; rs_alu_port2.cz_bits <= cz_bits2;
    rs_alu_port2.prs_tag <= prs2_tag; rs_alu_port2.prs_data <= prf_prs2_data; rs_alu_port2.prt_tag <= prt2_tag; rs_alu_port2.prt_data <= prf_prt2_data;
    rs_alu_port2.pr_flag_tag <= pr_flag2_tag; rs_alu_port2.pr_flag_data<= prf_flag2_data; rs_alu_port2.pd_new <= pd2_new; rs_alu_port2.pf_new <= pf2_new; rs_alu_port2.rob_id <= live_rob_id2; 
    rs_alu_port2.we_gpr <= in_we_gpr2 when (is_alu2 = '1' and in_illegal_op2 = '0') else '0'; rs_alu_port2.we_flag <= in_we_flag2 when (is_alu2 = '1' and in_illegal_op2 = '0') else '0';
    rs_alu_port2.pred_taken <= pred_taken2; rs_alu_port2.pred_target <= pred_target2; rs_alu_port2.arch_dest <= arch_dest2;

    rs_alu_port2.prs_rdy     <= '1' when (op2 = OP_LLI) else 
                                '0' when (prs2_tag = pd1_new and in_we_gpr1 = '1' and in_reads_rs1_2 = '1') else
                                (not gpr_busy_mask(to_integer(unsigned(prs2_tag)))) or (not in_reads_rs1_2);
                                
    rs_alu_port2.prt_rdy     <= '1' when (op2 = OP_ADI or op2 = OP_LLI) else
                                '0' when (prt2_tag = pd1_new and in_we_gpr1 = '1' and in_reads_rs2_2 = '1') else
                                (not gpr_busy_mask(to_integer(unsigned(prt2_tag)))) or (not in_reads_rs2_2);
                                
    -- THE BUG FIX: Flawless Flag Dependency Logic
    rs_alu_port2.pr_flag_rdy <= 
        '1' when (op2 /= OP_ADD and op2 /= OP_NDU) else
        '1' when (op2 = OP_ADD and cz_bits2 = COND_AL) else
        '0' when (pr_flag2_tag = pf1_new and in_we_flag1 = '1') else
        not flag_busy_mask(to_integer(unsigned(pr_flag2_tag)));

    rs_lsu_port2.valid <= valid2_in and is_lsu2 and (not stall_internal) and not(in_illegal_op2);
    rs_lsu_port2.pc <= pc2; rs_lsu_port2.op <= op2; rs_lsu_port2.imm <= imm2; rs_lsu_port2.comp_bit <= comp_bit2; rs_lsu_port2.cz_bits <= cz_bits2;
    rs_lsu_port2.prs_tag <= prs2_tag; rs_lsu_port2.prs_data <= prf_prs2_data; rs_lsu_port2.prt_tag <= prt2_tag; rs_lsu_port2.prt_data <= prf_prt2_data;
    rs_lsu_port2.pr_flag_tag <= pr_flag2_tag; rs_lsu_port2.pr_flag_data <= prf_flag2_data; rs_lsu_port2.pd_new <= pd2_new; rs_lsu_port2.pf_new <= pf2_new; rs_lsu_port2.rob_id <= live_rob_id2; rs_lsu_port2.we_gpr <= in_we_gpr2; rs_lsu_port2.we_flag <= in_we_flag2; rs_lsu_port2.pred_taken <= pred_taken2; rs_lsu_port2.pred_target <= pred_target2; rs_lsu_port2.arch_dest <= arch_dest2;
    rs_lsu_port2.prs_rdy <= '0' when (prs2_tag = pd1_new and in_we_gpr1 = '1' and in_reads_rs1_2 = '1') else (not gpr_busy_mask(to_integer(unsigned(prs2_tag)))) or (not in_reads_rs1_2);
    rs_lsu_port2.prt_rdy <= '0' when (prt2_tag = pd1_new and in_we_gpr1 = '1' and in_reads_rs2_2 = '1') else (not gpr_busy_mask(to_integer(unsigned(prt2_tag)))) or (not in_reads_rs2_2);
    rs_lsu_port2.pr_flag_rdy <= '1';

    rs_br_port2.valid <= valid2_in and is_branch2 and (not stall_internal) and not(in_illegal_op2);
    rs_br_port2.pc <= pc2; rs_br_port2.op <= op2; rs_br_port2.imm <= imm2; rs_br_port2.comp_bit <= comp_bit2; rs_br_port2.cz_bits <= cz_bits2;
    rs_br_port2.prs_tag <= prs2_tag; rs_br_port2.prs_data <= prf_prs2_data; rs_br_port2.prt_tag <= prt2_tag; rs_br_port2.prt_data <= prf_prt2_data;
    rs_br_port2.pr_flag_tag <= pr_flag2_tag; rs_br_port2.pr_flag_data <= prf_flag2_data; rs_br_port2.pd_new <= pd2_new; rs_br_port2.pf_new <= pf2_new; rs_br_port2.rob_id <= live_rob_id2; rs_br_port2.we_gpr <= in_we_gpr2; rs_br_port2.we_flag <= in_we_flag2; rs_br_port2.pred_taken <= pred_taken2; rs_br_port2.pred_target <= pred_target2; rs_br_port2.arch_dest <= arch_dest2;
    rs_br_port2.prs_rdy <= '0' when (prs2_tag = pd1_new and in_we_gpr1 = '1' and in_reads_rs1_2 = '1') else (not gpr_busy_mask(to_integer(unsigned(prs2_tag)))) or (not in_reads_rs1_2);
    rs_br_port2.prt_rdy <= '0' when (prt2_tag = pd1_new and in_we_gpr1 = '1' and in_reads_rs2_2 = '1') else (not gpr_busy_mask(to_integer(unsigned(prt2_tag)))) or (not in_reads_rs2_2);
    rs_br_port2.pr_flag_rdy <= '1';

    -- X-Ray Logging
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                if stall_internal = '1' and (valid1_in = '1' or valid2_in = '1') then
                    write(l, string'("[ROUTER] STALLED -> Out of Reservation Station Slots!"));
                    writeline(output, l);
                else
                    if valid1_in = '1' then
                        write(l, string'("[ROUTER] Dispatched PC ")); write(l, integer'image(to_integer(unsigned(pc1))));
                        write(l, string'(" to "));
                        if route_to_alu1 = '1' then write(l, string'("ALU_RS | ROB ID: "));
                        elsif is_lsu1 = '1' then write(l, string'("LSU_RS | ROB ID: "));
                        elsif is_branch1 = '1' then write(l, string'("BR_RS | ROB ID: ")); end if;
                        write(l, integer'image(to_integer(unsigned(live_rob_id1)))); writeline(output, l);
                    end if;
                    if valid2_in = '1' then
                        write(l, string'("[ROUTER] Dispatched PC ")); write(l, integer'image(to_integer(unsigned(pc2))));
                        write(l, string'(" to "));
                        if route_to_alu2 = '1' then write(l, string'("ALU_RS | ROB ID: "));
                        elsif is_lsu2 = '1' then write(l, string'("LSU_RS | ROB ID: "));
                        elsif is_branch2 = '1' then write(l, string'("BR_RS | ROB ID: ")); end if;
                        write(l, integer'image(to_integer(unsigned(live_rob_id2)))); writeline(output, l);
                    end if;
                end if;
            end if;
        end if;
    end process;
end Combinational;