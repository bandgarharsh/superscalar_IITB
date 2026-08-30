library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_RR_stage is
end tb_RR_stage;

architecture Behavioral of tb_RR_stage is

    -- Clock & Control
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal flush : std_logic := '0';
    signal stall_out : std_logic;

    -- Slot 1 Inputs
    signal valid1  : std_logic := '0';
    signal rs1, rt1, rd1 : std_logic_vector(2 downto 0) := (others => '0');
    signal we_gpr1, we_flag1: std_logic := '0';

    -- Slot 2 Inputs
    signal valid2  : std_logic := '0';
    signal rs2, rt2, rd2 : std_logic_vector(2 downto 0) := (others => '0');
    signal we_gpr2, we_flag2 : std_logic := '0';

    -- ROB Inputs
    signal rob_tail_id1_in : std_logic_vector(3 downto 0) := "0000";
    signal rob_tail_id2_in : std_logic_vector(3 downto 0) := "0001";
    signal rob_free_count  : unsigned(4 downto 0) := to_unsigned(16, 5);

    -- Commit/Recovery Inputs
    signal commit_rat_flat  : std_logic_vector(39 downto 0) := (others => '0');
    signal commit_flag_tag  : std_logic_vector(4 downto 0) := (others => '0');
    signal commit_c_tag     : std_logic_vector(4 downto 0) := (others => '0');
    signal commit_z_tag     : std_logic_vector(4 downto 0) := (others => '0');
    -- x"FFFFFF00" means P8-P31 are free. x"FFFFFFFE" means F1-F31 are free.
    signal commit_gpr_mask  : std_logic_vector(31 downto 0) := x"FFFFFF00"; 
    signal commit_flag_mask : std_logic_vector(31 downto 0) := x"FFFFFFFE";

    -- Free List Dealloc
    signal free_gpr1_en, free_gpr2_en : std_logic := '0';
    signal free_gpr1_tag, free_gpr2_tag : std_logic_vector(4 downto 0) := (others => '0');
    signal free_f1_en, free_f2_en : std_logic := '0';
    signal free_f1_tag, free_f2_tag : std_logic_vector(4 downto 0) := (others => '0');

    -- Writebacks
    signal wb_gpr1_en, wb_gpr2_en, wb_gpr3_en, wb_gpr4_en : std_logic := '0';
    signal wb_gpr1_tag, wb_gpr2_tag, wb_gpr3_tag, wb_gpr4_tag : std_logic_vector(4 downto 0) := (others => '0');
    signal wb_f1_en, wb_f2_en : std_logic := '0';
    signal wb_f1_tag, wb_f2_tag : std_logic_vector(4 downto 0) := (others => '0');

    -- Outputs Slot 1
    signal prs1_out, prt1_out, pd1_new, pd1_old, pf1_new, pf1_old : std_logic_vector(4 downto 0);
    signal pr_flag1_out : std_logic_vector(4 downto 0);
    signal prs1_rdy, prt1_rdy, pr_flag1_rdy : std_logic;
    signal rob_id1_out : std_logic_vector(3 downto 0);

    -- Outputs Slot 2
    signal prs2_out, prt2_out, pd2_new, pd2_old, pf2_new, pf2_old : std_logic_vector(4 downto 0);
    signal pr_flag2_out : std_logic_vector(4 downto 0);
    signal prs2_rdy, prt2_rdy, pr_flag2_rdy : std_logic;
    signal rob_id2_out : std_logic_vector(3 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    -- Helper to print integer values from vectors
    function to_str(vec : std_logic_vector) return string is
    begin
        return integer'image(to_integer(unsigned(vec)));
    end function;

begin

    uut: entity work.RR_stage
        port map (
            clk => clk, rst => rst, flush => flush, stall_out => stall_out,
            valid1 => valid1, rs1 => rs1, rt1 => rt1, rd1 => rd1, we_gpr1 => we_gpr1, we_flag1 => we_flag1,
            valid2 => valid2, rs2 => rs2, rt2 => rt2, rd2 => rd2, we_gpr2 => we_gpr2, we_flag2 => we_flag2,
            
            rob_tail_id1_in => rob_tail_id1_in, rob_tail_id2_in => rob_tail_id2_in, rob_free_count => rob_free_count,
            commit_rat_flat => commit_rat_flat, commit_flag_tag => commit_flag_tag,
            commit_gpr_mask => commit_gpr_mask, commit_flag_mask => commit_flag_mask,
            
            free_gpr1_en => free_gpr1_en, free_gpr1_tag => free_gpr1_tag, free_gpr2_en => free_gpr2_en, free_gpr2_tag => free_gpr2_tag,
            free_f1_en => free_f1_en, free_f1_tag => free_f1_tag, free_f2_en => free_f2_en, free_f2_tag => free_f2_tag,
            
            wb_gpr1_en => wb_gpr1_en, wb_gpr1_tag => wb_gpr1_tag, wb_gpr2_en => wb_gpr2_en, wb_gpr2_tag => wb_gpr2_tag,
            wb_gpr3_en => wb_gpr3_en, wb_gpr3_tag => wb_gpr3_tag,
            wb_f1_en => wb_f1_en, wb_f1_tag => wb_f1_tag, wb_f2_en => wb_f2_en, wb_f2_tag => wb_f2_tag,
            
            prs1_out => prs1_out, prt1_out => prt1_out, prs1_rdy => prs1_rdy, prt1_rdy => prt1_rdy,
            pr_flag1_out => pr_flag1_out, pr_flag1_rdy => pr_flag1_rdy, 
            pd1_new => pd1_new, pd1_old => pd1_old, pf1_new => pf1_new, pf1_old => pf1_old, rob_id1_out => rob_id1_out,
            
            prs2_out => prs2_out, prt2_out => prt2_out, prs2_rdy => prs2_rdy, prt2_rdy => prt2_rdy,
            pr_flag2_out => pr_flag2_out, pr_flag2_rdy => pr_flag2_rdy,
            pd2_new => pd2_new, pd2_old => pd2_old, pf2_new => pf2_new, pf2_old => pf2_old, rob_id2_out => rob_id2_out
        );

    clk_process : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    stim_proc: process
    begin
        report "=================================================";
        report "STARTING RR_STAGE VERIFICATION";
        report "=================================================";

        -- =========================================================
        report "--- RESET ---";
        rst <= '1';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD;

        -- =========================================================
        report "--- TEST 1: Single GPR Instruction ---";
        valid1 <= '1'; we_gpr1 <= '1'; rd1 <= "001";
        valid2 <= '0';
        wait for 2 ns; 
        assert (stall_out = '0') report "FAIL T1: Stalled incorrectly" severity error;
        assert (pd1_new = "01000") report "FAIL T1: Expected P8 for I1 alloc" severity error;
        wait for CLK_PERIOD - 2 ns; -- clock edge

        -- =========================================================
        report "--- TEST 2: Dual GPR Instructions ---";
        valid1 <= '1'; we_gpr1 <= '1'; rd1 <= "010"; 
        valid2 <= '1'; we_gpr2 <= '1'; rd2 <= "011";
        wait for 2 ns;
        assert (stall_out = '0') report "FAIL T2: Stalled incorrectly" severity error;
        assert (pd1_new = "01001") report "FAIL T2: Expected P9" severity error;
        assert (pd2_new = "01010") report "FAIL T2: Expected P10" severity error;
        wait for CLK_PERIOD - 2 ns;

        -- =========================================================
        report "--- TEST 3: WAW Hazard (Same-Cycle Overwrite) ---";
        valid1 <= '1'; we_gpr1 <= '1'; rd1 <= "100"; -- Writes R4
        valid2 <= '1'; we_gpr2 <= '1'; rd2 <= "100"; -- Writes R4
        wait for 2 ns;
        -- I1 allocates P11, I2 allocates P12. 
        -- I2's "Old Tag" MUST be I1's "New Tag" (P11) so it gets freed properly later.
        assert (pd2_old = pd1_new) report "FAIL T3: WAW Bypass Failed! old_pr2 != alloc_gpr1" severity error;
        wait for CLK_PERIOD - 2 ns;

        -- =========================================================
        report "--- TEST 4: RAW Hazard (Same-Cycle Forwarding) ---";
        valid1 <= '1'; we_gpr1 <= '1'; rd1 <= "101"; -- Writes R5
        valid2 <= '1'; we_gpr2 <= '0'; rs2 <= "101"; -- Reads R5
        wait for 2 ns;
        assert (prs2_out = pd1_new) report "FAIL T4: RAW Bypass Failed! prs2_out != alloc_gpr1" severity error;
        assert (prs2_rdy = '0') report "FAIL T4: RAW Ready Bit should be 0 (Busy)" severity error;
        wait for CLK_PERIOD - 2 ns;

        -- =========================================================
        report "--- TEST 5: Unified C/Z Flag Overwrite ---";
        valid1 <= '1'; we_gpr1 <= '0'; we_flag1 <= '1'; -- 
        valid2 <= '1'; we_gpr2 <= '0'; we_flag2 <= '0'; --
        wait for 2 ns;
        -- Both write to the Unified Flag. I1 allocates F1. I2 allocates F2. 
        -- I2's old flag tag must be F1.
        assert (pf1_new = "00001") report "FAIL T5: Expected F1 for I1" severity error;
        assert (pf2_new = "00010") report "FAIL T5: Expected F2 for I2" severity error;
        assert (pf2_old = pf1_new) report "FAIL T5: WAW Flag Bypass Failed" severity error;
        wait for CLK_PERIOD - 2 ns;

        -- =========================================================
        report "--- TEST 6: ROB Full (Stall Propagation) ---";
        valid1 <= '1'; we_gpr1 <= '1'; rd1 <= "111"; 
        valid2 <= '1'; we_gpr2 <= '1'; rd2 <= "000"; 
        rob_free_count <= to_unsigned(1, 5); -- Only 1 ROB slot left!
        wait for 2 ns;
        assert (stall_out = '1') report "FAIL T6: Should have stalled because bundle needs 2 ROBs" severity error;
        
        -- Drop to 1 instruction, stall should resolve
        valid2 <= '0'; we_gpr2 <= '0';
        wait for 2 ns;
        assert (stall_out = '0') report "FAIL T6: Stall should resolve for 1 valid instruction" severity error;
        rob_free_count <= to_unsigned(16, 5); -- Restore
        wait for CLK_PERIOD - 4 ns;

        -- =========================================================
        report "--- TEST 7: Insufficient Free Registers ---";
        -- Force the free list to be empty via a flush
        flush <= '1';
        commit_gpr_mask <= (others => '0'); -- NO registers available
        valid1 <= '0'; valid2 <= '0';
        wait for CLK_PERIOD;
        flush <= '0';
        
        -- Now try to allocate
        valid1 <= '1'; we_gpr1 <= '1'; 
        wait for 2 ns;
        assert (stall_out = '1') report "FAIL T7: Should stall due to empty Free List" severity error;
        
        -- Restore Free List
        flush <= '1';
        commit_gpr_mask <= x"FFFFFF00"; 
        valid1 <= '0';
        wait for CLK_PERIOD;
        flush <= '0';

        -- =========================================================
        report "--- TEST 8: Writeback (CDB Readiness) ---";
        -- Allocate P8 to make it busy
        valid1 <= '1'; we_gpr1 <= '1'; rd1 <= "001";
        wait for CLK_PERIOD;
        
        -- P8 is now busy. Read it to verify.
        valid1 <= '1'; we_gpr1 <= '0'; rs1 <= "001";
        wait for 2 ns;
        assert (prs1_rdy = '0') report "FAIL T8: P8 should be busy" severity error;
        
        -- Broadcast Writeback for P8
        wb_gpr1_en <= '1'; wb_gpr1_tag <= "01000"; 
        wait for CLK_PERIOD;
        wb_gpr1_en <= '0';
        
        -- Read again, should be ready
        wait for 2 ns;
        assert (prs1_rdy = '1') report "FAIL T8: P8 should have been marked ready by Writeback" severity error;
        wait for CLK_PERIOD - 2 ns;

        -- =========================================================
        report "--- TEST 9: Flush / Recovery ---";
        -- Point everything to P0 in the committed state
        flush <= '1';
        commit_rat_flat <= (others => '0'); 
        valid1 <= '0';
        wait for CLK_PERIOD;
        flush <= '0';
        
        -- Read architectural R1, should point to P0 now
        valid1 <= '1'; we_gpr1 <= '0'; rs1 <= "001";
        wait for 2 ns;
        assert (prs1_out = "00000") report "FAIL T9: Flush did not overwrite Speculative RAT" severity error;

        report "=================================================";
        report "SIMULATION COMPLETE - IF NO FAILS, EVERYTHING PASSES!";
        report "=================================================";
        wait;
    end process;

end Behavioral;