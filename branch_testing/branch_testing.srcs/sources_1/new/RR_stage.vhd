library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; -- NEW: Clean Logging

entity RR_stage is
    Port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        flush               : in  std_logic;
        stall_out           : out std_logic; 

        -- SLOT 1
        op1_valid_in        : in  std_logic;
        pc1_in              : in  std_logic_vector(15 downto 0);
        op1_in              : in  std_logic_vector(3 downto 0);
        imm1_in             : in  std_logic_vector(15 downto 0);
        comp_bit1_in        : in  std_logic;
        cz_bits1_in         : in  std_logic_vector(1 downto 0);
        src1_reg1_in        : in  std_logic_vector(2 downto 0);
        src2_reg1_in        : in  std_logic_vector(2 downto 0);
        dest_reg1_in        : in  std_logic_vector(2 downto 0);
        reads_rs1_1_in      : in  std_logic;
        reads_rs2_1_in      : in  std_logic;
        we_gpr1_in          : in  std_logic;
        dest_is_r0_1_in     : in  std_logic;
        we_flag1_in         : in  std_logic;
        is_alu1_in          : in  std_logic;
        is_lsu1_in          : in  std_logic;
        is_branch1_in       : in  std_logic;
        is_multimem1_in     : in  std_logic;
        is_store1_in        : in  std_logic;
        illegal_op1_in      : in  std_logic;
        in_pred_taken1      : in std_logic;
        in_pred_target1     : in std_logic_vector(15 downto 0);
        
        -- SLOT 2
        op2_valid_in        : in  std_logic;
        pc2_in              : in  std_logic_vector(15 downto 0);
        op2_in              : in  std_logic_vector(3 downto 0);
        imm2_in             : in  std_logic_vector(15 downto 0);
        comp_bit2_in        : in  std_logic;
        cz_bits2_in         : in  std_logic_vector(1 downto 0);
        src1_reg2_in        : in  std_logic_vector(2 downto 0);
        src2_reg2_in        : in  std_logic_vector(2 downto 0);
        dest_reg2_in        : in  std_logic_vector(2 downto 0);
        reads_rs1_2_in      : in  std_logic;
        reads_rs2_2_in      : in  std_logic;
        we_gpr2_in          : in  std_logic;
        dest_is_r0_2_in     : in  std_logic;
        we_flag2_in         : in  std_logic;
        is_alu2_in          : in  std_logic;
        is_lsu2_in          : in  std_logic;
        is_branch2_in       : in  std_logic;
        is_multimem2_in     : in  std_logic;
        is_store2_in        : in  std_logic;
        illegal_op2_in      : in  std_logic;
        in_pred_taken2      : in std_logic;
        in_pred_target2     : in std_logic_vector(15 downto 0);

        -- ROB & COMMIT
        rob_tail_id1_in     : in  std_logic_vector(3 downto 0);
        rob_tail_id2_in     : in  std_logic_vector(3 downto 0);
        rob_free_count      : in  unsigned(4 downto 0); 
        commit_rat_flat     : in  std_logic_vector(39 downto 0);
        commit_flag_tag     : in  std_logic_vector(4 downto 0);
        commit_gpr_mask     : in  std_logic_vector(31 downto 0);
        commit_flag_mask    : in  std_logic_vector(31 downto 0);

        -- DEALLOCATION
        free_gpr1_en        : in  std_logic;
        free_gpr1_tag       : in  std_logic_vector(4 downto 0);
        free_gpr2_en        : in  std_logic;
        free_gpr2_tag       : in  std_logic_vector(4 downto 0);
        free_f1_en          : in  std_logic;
        free_f1_tag         : in  std_logic_vector(4 downto 0);
        free_f2_en          : in  std_logic;
        free_f2_tag         : in  std_logic_vector(4 downto 0);

        -- WRITEBACK
        wb_gpr1_en, wb_gpr2_en, wb_gpr3_en : in std_logic;
        wb_gpr1_tag, wb_gpr2_tag, wb_gpr3_tag : in std_logic_vector(4 downto 0);
        wb_f1_en, wb_f2_en : in std_logic;
        wb_f1_tag, wb_f2_tag : in std_logic_vector(4 downto 0);

        -- OUTPUTS SLOT 1
        dispatch_valid1_out : out std_logic; 
        pc1_out             : out std_logic_vector(15 downto 0);
        op1_out             : out std_logic_vector(3 downto 0);
        imm1_out            : out std_logic_vector(15 downto 0);
        comp_bit1_out       : out std_logic;
        cz_bits1_out        : out std_logic_vector(1 downto 0);
        reads_rs1_1_out     : out std_logic;
        reads_rs2_1_out     : out std_logic;
        dest_is_r0_1_out    : out std_logic;
        we_gpr1_out         : out std_logic;
        we_flag1_out        : out std_logic;
        is_alu1_out         : out std_logic;
        is_lsu1_out         : out std_logic;
        is_branch1_out      : out std_logic;
        is_multimem1_out    : out std_logic;
        is_store1_out       : out std_logic;
        illegal_op1_out     : out std_logic;
        prs1_out, prt1_out  : out std_logic_vector(4 downto 0);
        prs1_rdy, prt1_rdy  : out std_logic;
        pr_flag1_out        : out std_logic_vector(4 downto 0);
        pr_flag1_rdy        : out std_logic;
        pd1_new, pd1_old    : out std_logic_vector(4 downto 0); 
        pf1_new, pf1_old    : out std_logic_vector(4 downto 0);
        rob_id1_out         : out std_logic_vector(3 downto 0);
        arch_dest1          : out std_logic_vector(2 downto 0);
        out_pred_taken1     : out std_logic;
        out_pred_target1    : out std_logic_vector(15 downto 0);
        
        -- OUTPUTS SLOT 2
        dispatch_valid2_out : out std_logic;
        pc2_out             : out std_logic_vector(15 downto 0);
        op2_out             : out std_logic_vector(3 downto 0);
        imm2_out            : out std_logic_vector(15 downto 0);
        comp_bit2_out       : out std_logic;
        cz_bits2_out        : out std_logic_vector(1 downto 0);
        reads_rs1_2_out     : out std_logic;
        reads_rs2_2_out     : out std_logic;
        dest_is_r0_2_out    : out std_logic;
        we_gpr2_out         : out std_logic;
        we_flag2_out        : out std_logic;
        is_alu2_out         : out std_logic;
        is_lsu2_out         : out std_logic;
        is_branch2_out      : out std_logic;
        is_multimem2_out    : out std_logic;
        is_store2_out       : out std_logic;
        illegal_op2_out     : out std_logic;
        prs2_out, prt2_out  : out std_logic_vector(4 downto 0);
        prs2_rdy, prt2_rdy  : out std_logic;
        pr_flag2_out        : out std_logic_vector(4 downto 0);
        pr_flag2_rdy        : out std_logic;
        pd2_new, pd2_old    : out std_logic_vector(4 downto 0); 
        pf2_new, pf2_old    : out std_logic_vector(4 downto 0);
        rob_id2_out         : out std_logic_vector(3 downto 0);
        arch_dest2          : out std_logic_vector(2 downto 0);
        out_pred_taken2     : out std_logic;
        out_pred_target2    : out std_logic_vector(15 downto 0);
        
        gpr_busy_out  : out std_logic_vector(31 downto 0);
        flag_busy_out : out std_logic_vector(31 downto 0)
    );
end RR_stage;

architecture Structural of RR_stage is

    signal alloc_gpr1, alloc_gpr2 : std_logic_vector(4 downto 0);
    signal alloc_f1, alloc_f2     : std_logic_vector(4 downto 0);
    signal req_gpr1, req_gpr2 : std_logic;
    signal req_f1, req_f2     : std_logic;
    signal needed_gprs, needed_flags, needed_robs : unsigned(1 downto 0);
    signal avail_gprs, avail_flags : unsigned(1 downto 0);
    signal dispatch_fire : std_logic;
    signal dispatch_gpr1, dispatch_gpr2, dispatch_f1, dispatch_f2 : std_logic;
    signal prs1_sig, prt1_sig, pr_flag1_sig : std_logic_vector(4 downto 0);
    signal prs2_sig, prt2_sig, pr_flag2_sig : std_logic_vector(4 downto 0);
    signal real_valid_1, real_valid_2 : std_logic;
    
    -- NEW SIGNALS FOR FLAG FILTER INTERCEPT
    signal pr_flag1_rdy_sig, pr_flag2_rdy_sig : std_logic;
    
begin

    real_valid_1 <= op1_valid_in and (is_alu1_in or is_lsu1_in or is_branch1_in) and not illegal_op1_in;
    real_valid_2 <= op2_valid_in and (is_alu2_in or is_lsu2_in or is_branch2_in) and not illegal_op2_in;

    req_gpr1 <= '1' when (real_valid_1 = '1' and we_gpr1_in = '1') else '0';
    req_gpr2 <= '1' when (real_valid_2 = '1' and we_gpr2_in = '1') else '0';
    req_f1   <= '1' when (real_valid_1 = '1' and we_flag1_in = '1') else '0';
    req_f2   <= '1' when (real_valid_2 = '1' and we_flag2_in = '1') else '0';

    process(req_gpr1, req_gpr2) begin
        if req_gpr1 = '1' and req_gpr2 = '1' then needed_gprs <= "10";
        elsif req_gpr1 = '1' or req_gpr2 = '1' then needed_gprs <= "01";
        else needed_gprs <= "00"; end if;
    end process;

    process(req_f1, req_f2) begin
        if req_f1 = '1' and req_f2 = '1' then needed_flags <= "10";
        elsif req_f1 = '1' or req_f2 = '1' then needed_flags <= "01";
        else needed_flags <= "00"; end if;
    end process;

    process(real_valid_1, real_valid_2) begin
        if real_valid_1 = '1' and real_valid_2 = '1' then needed_robs <= "10";
        elsif real_valid_1 = '1' or real_valid_2 = '1' then needed_robs <= "01";
        else needed_robs <= "00"; end if;
    end process;

    process(needed_gprs, avail_gprs, needed_flags, avail_flags, needed_robs, rob_free_count, flush) begin
        if (flush = '0') and (avail_gprs >= needed_gprs) and (avail_flags >= needed_flags) and (rob_free_count >= needed_robs) then
            dispatch_fire <= '1';
        else
            dispatch_fire <= '0';
        end if;
    end process;

    stall_out <= not dispatch_fire;

    dispatch_gpr1 <= req_gpr1 and dispatch_fire;
    dispatch_gpr2 <= req_gpr2 and dispatch_fire;
    dispatch_f1   <= req_f1 and dispatch_fire;
    dispatch_f2   <= req_f2 and dispatch_fire;

    dispatch_valid1_out <= real_valid_1 and dispatch_fire;
    dispatch_valid2_out <= real_valid_2 and dispatch_fire;

    pc1_out <= pc1_in; op1_out <= op1_in; imm1_out <= imm1_in; comp_bit1_out <= comp_bit1_in; cz_bits1_out <= cz_bits1_in;
    reads_rs1_1_out <= reads_rs1_1_in; reads_rs2_1_out <= reads_rs2_1_in; dest_is_r0_1_out <= dest_is_r0_1_in; we_gpr1_out <= we_gpr1_in; we_flag1_out <= we_flag1_in;
    is_alu1_out <= is_alu1_in; is_lsu1_out <= is_lsu1_in; is_branch1_out <= is_branch1_in; is_multimem1_out <= is_multimem1_in; is_store1_out <= is_store1_in; illegal_op1_out <= illegal_op1_in;
    rob_id1_out <= rob_tail_id1_in; arch_dest1 <= dest_reg1_in; out_pred_taken1 <= in_pred_taken1; out_pred_target1 <= in_pred_target1;
    
    pc2_out <= pc2_in; op2_out <= op2_in; imm2_out <= imm2_in; comp_bit2_out <= comp_bit2_in; cz_bits2_out <= cz_bits2_in;
    reads_rs1_2_out <= reads_rs1_2_in; reads_rs2_2_out <= reads_rs2_2_in; dest_is_r0_2_out <= dest_is_r0_2_in; we_gpr2_out <= we_gpr2_in; we_flag2_out <= we_flag2_in;
    is_alu2_out <= is_alu2_in; is_lsu2_out <= is_lsu2_in; is_branch2_out <= is_branch2_in; is_multimem2_out <= is_multimem2_in; is_store2_out <= is_store2_in; illegal_op2_out <= illegal_op2_in;
    rob_id2_out <= rob_tail_id2_in; arch_dest2 <= dest_reg2_in; out_pred_taken2 <= in_pred_taken2; out_pred_target2 <= in_pred_target2;   
    
    FL_inst : entity work.free_list port map (
            clk => clk, rst => rst, flush => flush, commit_gpr_mask => commit_gpr_mask, commit_flag_mask => commit_flag_mask,
            req_gpr1 => dispatch_gpr1, req_gpr2 => dispatch_gpr2, alloc_gpr1 => alloc_gpr1, alloc_gpr2 => alloc_gpr2, avail_gprs => avail_gprs,
            req_flag1 => dispatch_f1, req_flag2 => dispatch_f2, alloc_flag1 => alloc_f1, alloc_flag2 => alloc_f2, avail_flags => avail_flags,
            free_gpr1_en => free_gpr1_en, free_gpr1_tag => free_gpr1_tag, free_gpr2_en => free_gpr2_en, free_gpr2_tag => free_gpr2_tag,
            free_flag1_en => free_f1_en, free_flag1_tag => free_f1_tag, free_flag2_en => free_f2_en, free_flag2_tag => free_f2_tag
        );

    RAT_inst : entity work.spec_rat port map (
            clk => clk, rst => rst, flush => flush, commit_rat_flat => commit_rat_flat, commit_flag_tag => commit_flag_tag,
            rs1 => src1_reg1_in, rt1 => src2_reg1_in, rd1 => dest_reg1_in, we_gpr1 => dispatch_gpr1, we_flag1 => dispatch_f1, alloc_gpr1 => alloc_gpr1, alloc_f1 => alloc_f1, prs1 => prs1_sig, prt1 => prt1_sig, old_pr1 => pd1_old, pr_flag1 => pr_flag1_sig, old_pr_flag1 => pf1_old, 
            rs2 => src1_reg2_in, rt2 => src2_reg2_in, rd2 => dest_reg2_in, we_gpr2 => dispatch_gpr2, we_flag2 => dispatch_f2, alloc_gpr2 => alloc_gpr2, alloc_f2 => alloc_f2, prs2 => prs2_sig, prt2 => prt2_sig, old_pr2 => pd2_old, pr_flag2 => pr_flag2_sig, old_pr_flag2 => pf2_old  
        );

    BT_inst : entity work.busy_table port map (
            clk => clk, rst => rst, flush => flush, prs1 => prs1_sig, prt1 => prt1_sig, pr_flag1 => pr_flag1_sig, prs2 => prs2_sig, prt2 => prt2_sig, pr_flag2 => pr_flag2_sig,
            prs1_ready => prs1_rdy, prt1_ready => prt1_rdy, pr_flag1_ready => pr_flag1_rdy_sig, prs2_ready => prs2_rdy, prt2_ready => prt2_rdy, pr_flag2_ready => pr_flag2_rdy_sig, 
            gpr_busy_out => gpr_busy_out, flag_busy_out => flag_busy_out, alloc_gpr1_en => dispatch_gpr1, alloc_gpr1 => alloc_gpr1, alloc_gpr2_en => dispatch_gpr2, alloc_gpr2 => alloc_gpr2, alloc_f1_en => dispatch_f1, alloc_f1 => alloc_f1, alloc_f2_en => dispatch_f2, alloc_f2 => alloc_f2,
            wb_gpr1_en => wb_gpr1_en, wb_gpr1_tag => wb_gpr1_tag, wb_gpr2_en => wb_gpr2_en, wb_gpr2_tag => wb_gpr2_tag, wb_gpr3_en => wb_gpr3_en, wb_gpr3_tag => wb_gpr3_tag, wb_f1_en => wb_f1_en, wb_f1_tag => wb_f1_tag, wb_f2_en => wb_f2_en, wb_f2_tag => wb_f2_tag
        );

    prs1_out <= prs1_sig; prt1_out <= prt1_sig; pr_flag1_out <= pr_flag1_sig; pd1_new  <= alloc_gpr1; pf1_new  <= alloc_f1;
    prs2_out <= prs2_sig; prt2_out <= prt2_sig; pr_flag2_out <= pr_flag2_sig; pd2_new  <= alloc_gpr2; pf2_new  <= alloc_f2;

    -- Only ADD ("0001") and NDU ("0010") with condition bits actually read the flag!
    pr_flag1_rdy <= pr_flag1_rdy_sig when ((op1_in = "0001" or op1_in = "0010") and cz_bits1_in /= "00") else '1';
    pr_flag2_rdy <= pr_flag2_rdy_sig when ((op2_in = "0001" or op2_in = "0010") and cz_bits2_in /= "00") else '1';
    
    -- =================================================================
    -- PROFESSIONAL X-RAY: STALL TRACKER
    -- =================================================================
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                if flush = '1' then
                    write(l, string'("[RR STAGE] FLUSHED -> Wiping Allocations"));
                    writeline(output, l);
                elsif dispatch_fire = '0' and (real_valid_1 = '1' or real_valid_2 = '1') then
                    -- If we are stalled, print EXACTLY why!
                    write(l, string'("[RR STAGE] STALLED -> Need GPRs: "));
                    write(l, integer'image(to_integer(needed_gprs)));
                    write(l, string'(" | Avail GPRs: "));
                    write(l, integer'image(to_integer(avail_gprs)));
                    write(l, string'(" | Need Flags: "));
                    write(l, integer'image(to_integer(needed_flags)));
                    write(l, string'(" | Avail Flags: "));
                    write(l, integer'image(to_integer(avail_flags)));
                    write(l, string'(" | Free ROBs: "));
                    write(l, integer'image(to_integer(rob_free_count)));
                    writeline(output, l);
                end if;
            end if;
        end if;
    end process;
end Structural;