library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spec_rat is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- ==========================================
        -- RECOVERY INTERFACE (From Commit RRAT)
        -- ==========================================
        flush           : in  std_logic;
        commit_rat_flat : in  std_logic_vector(39 downto 0); -- 8 GPRs * 5 bits 
        commit_flag_tag : in  std_logic_vector(4 downto 0);  -- Unified Flag Tag

        -- ==========================================
        -- SLOT 1 (Older Instruction)
        -- ==========================================
        rs1             : in  std_logic_vector(2 downto 0);
        rt1             : in  std_logic_vector(2 downto 0);
        rd1             : in  std_logic_vector(2 downto 0);
        we_gpr1         : in  std_logic;
        we_flag1        : in  std_logic; -- 1 if writing C, Z, or both
        
        alloc_gpr1      : in  std_logic_vector(4 downto 0);
        alloc_f1        : in  std_logic_vector(4 downto 0);

        prs1            : out std_logic_vector(4 downto 0);
        prt1            : out std_logic_vector(4 downto 0);
        old_pr1         : out std_logic_vector(4 downto 0); -- Stale GPR tag to ROB
        
        pr_flag1        : out std_logic_vector(4 downto 0);
        old_pr_flag1    : out std_logic_vector(4 downto 0); -- Stale Flag tag to ROB

        -- ==========================================
        -- SLOT 2 (Younger Instruction)
        -- ==========================================
        rs2             : in  std_logic_vector(2 downto 0);
        rt2             : in  std_logic_vector(2 downto 0);
        rd2             : in  std_logic_vector(2 downto 0);
        we_gpr2         : in  std_logic;
        we_flag2        : in  std_logic; -- 1 if writing C, Z, or both
        
        alloc_gpr2      : in  std_logic_vector(4 downto 0);
        alloc_f2        : in  std_logic_vector(4 downto 0);

        prs2            : out std_logic_vector(4 downto 0);
        prt2            : out std_logic_vector(4 downto 0);
        old_pr2         : out std_logic_vector(4 downto 0);
        
        pr_flag2        : out std_logic_vector(4 downto 0);
        old_pr_flag2    : out std_logic_vector(4 downto 0)
    );
end spec_rat;

architecture Behavioral of spec_rat is

    -- GPR Mapping Array (Architectural R0-R7 to Physical P0-P31)
    type rat_array is array (0 to 7) of std_logic_vector(4 downto 0); 
    signal rat_map : rat_array;
    
    -- Single Unified Flag Pointer
    signal rat_flag : std_logic_vector(4 downto 0);

begin

    -- =================================================================
    -- 1. SLOT 1 READ NETWORK 
    -- =================================================================
    prs1         <= rat_map(to_integer(unsigned(rs1)));
    prt1         <= rat_map(to_integer(unsigned(rt1)));
    old_pr1      <= rat_map(to_integer(unsigned(rd1)));
    
    pr_flag1     <= rat_flag;
    old_pr_flag1 <= rat_flag;

    -- =================================================================
    -- 2. SLOT 2 READ NETWORK (RAW and WAW Bypassing)
    -- =================================================================
    
    -- GPR RAW Bypassing (Read-After-Write)
    prs2 <= alloc_gpr1 when (we_gpr1 = '1' and rs2 = rd1) else rat_map(to_integer(unsigned(rs2)));
    prt2 <= alloc_gpr1 when (we_gpr1 = '1' and rt2 = rd1) else rat_map(to_integer(unsigned(rt2)));
    
    -- GPR WAW Bypassing (Write-After-Write - crucial for Stale Tags)
    old_pr2 <= alloc_gpr1 when (we_gpr1 = '1' and rd2 = rd1) else rat_map(to_integer(unsigned(rd2))); 
    
    -- Flag RAW & WAW Bypassing
    pr_flag2     <= alloc_f1 when (we_flag1 = '1') else rat_flag;
    old_pr_flag2 <= alloc_f1 when (we_flag1 = '1') else rat_flag;


    -- =================================================================
    -- 3. SEQUENTIAL WRITE & RECOVERY NETWORK
    -- =================================================================
    process(clk, rst)
    begin
        if rst = '1' then
            -- Default Mapping: R0->P0, R1->P1 ... R7->P7
            for i in 0 to 7 loop
                rat_map(i) <= std_logic_vector(to_unsigned(i, 5));
            end loop;
            rat_flag <= (others => '0');

        elsif rising_edge(clk) then
            if flush = '1' then
                -- INSTANT RECOVERY: Overwrite with safe RRAT state
                rat_map(0) <= commit_rat_flat(4 downto 0); 
                rat_map(1) <= commit_rat_flat(9 downto 5);
                rat_map(2) <= commit_rat_flat(14 downto 10);
                rat_map(3) <= commit_rat_flat(19 downto 15);
                rat_map(4) <= commit_rat_flat(24 downto 20);
                rat_map(5) <= commit_rat_flat(29 downto 25);
                rat_map(6) <= commit_rat_flat(34 downto 30);
                rat_map(7) <= commit_rat_flat(39 downto 35);
                
                rat_flag <= commit_flag_tag;
                
            else
                -- NORMAL SUPERSCALAR WRITES
                -- Note: Since we use dispatch_we from RR_stage, these only update if the bundle was accepted!
                if we_gpr1 = '1' then
                    rat_map(to_integer(unsigned(rd1))) <= alloc_gpr1;
                end if;
                if we_gpr2 = '1' then
                    rat_map(to_integer(unsigned(rd2))) <= alloc_gpr2;
                end if;
                
                if we_flag1 = '1' then 
                    rat_flag <= alloc_f1; 
                end if;
                if we_flag2 = '1' then 
                    rat_flag <= alloc_f2; 
                end if;
                
            end if;
        end if;
    end process;
    -- =========================================================
    -- X-RAY: RAT RENAMING TRACKER
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' and flush = '0' then
                if we_gpr1 = '1' then
                    report "[X-RAY RAT] Renamed Arch R" & integer'image(to_integer(unsigned(rd1))) & 
                           " -> Phys P" & integer'image(to_integer(unsigned(alloc_gpr1)));
                end if;
                if we_gpr2 = '1' then
                    report "[X-RAY RAT] Renamed Arch R" & integer'image(to_integer(unsigned(rd2))) & 
                           " -> Phys P" & integer'image(to_integer(unsigned(alloc_gpr2)));
                end if;
            end if;
        end if;
    end process;
end Behavioral;