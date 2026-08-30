library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; 

----------------------------------------------------------------------------------
-- MODULE: Retirement Register Alias Table (RRAT)
-- DESCRIPTION:
--   Tracks the fully committed architectural state. Maps the 8 architectural
--   registers to the physical registers that were successfully retired by the ROB.
--   On a pipeline flush, this entire table is copied into the Speculative RAT 
--   to restore the CPU to a known-good state.
----------------------------------------------------------------------------------
entity RRAT is
    Port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        
        -- Commit Updates (From ROB)
        commit_valid_1      : in std_logic;
        commit_arch_dest_1  : in std_logic_vector(2 downto 0);
        commit_pd_1         : in std_logic_vector(4 downto 0);
        commit_flag_valid_1 : in std_logic;
        commit_pf_1         : in std_logic_vector(4 downto 0);
        
        commit_valid_2      : in std_logic;
        commit_arch_dest_2  : in std_logic_vector(2 downto 0);
        commit_pd_2         : in std_logic_vector(4 downto 0);
        commit_flag_valid_2 : in std_logic;
        commit_pf_2         : in std_logic_vector(4 downto 0);
        
        -- Deallocation Signals (To Free List)
        free_gpr1_en        : out std_logic;
        free_gpr1_tag       : out std_logic_vector(4 downto 0);
        free_gpr2_en        : out std_logic;
        free_gpr2_tag       : out std_logic_vector(4 downto 0);
        free_f1_en          : out std_logic;
        free_f1_tag         : out std_logic_vector(4 downto 0);
        free_f2_en          : out std_logic;
        free_f2_tag         : out std_logic_vector(4 downto 0);
        
        -- Recovery State Broadcast
        commit_rat_flat     : out std_logic_vector(39 downto 0);
        commit_flag_tag     : out std_logic_vector(4 downto 0);
        commit_gpr_mask     : out std_logic_vector(31 downto 0);
        commit_flag_mask    : out std_logic_vector(31 downto 0)
    );
end RRAT;

architecture Behavioral of RRAT is
    type rrat_array is array (0 to 7) of std_logic_vector(4 downto 0);
    signal rrat_map : rrat_array;
    signal rrat_flag : std_logic_vector(4 downto 0);
begin

    ------------------------------------------------------------------------------
    -- COMBINATIONAL MASK GENERATION
    -- Inverts the current mapping to build a "Busy Mask" for the Free List
    ------------------------------------------------------------------------------
    process(rrat_map, rrat_flag)
        variable v_gpr_mask  : std_logic_vector(31 downto 0);
        variable v_flag_mask : std_logic_vector(31 downto 0);
    begin
        v_gpr_mask  := (others => '1'); 
        v_flag_mask := (others => '1'); 
        
        -- Mark currently mapped GPRs as busy (0)
        for i in 0 to 7 loop
            v_gpr_mask(to_integer(unsigned(rrat_map(i)))) := '0'; 
        end loop;
        
        -- Mark currently mapped Flag as busy (0)
        v_flag_mask(to_integer(unsigned(rrat_flag))) := '0'; 
        
        commit_gpr_mask  <= v_gpr_mask;
        commit_flag_mask <= v_flag_mask;
    end process;
    
    ------------------------------------------------------------------------------
    -- COMBINATIONAL COMMIT BYPASS
    -- Instantly forwards new mappings to the Spec_RAT during a flush, 
    -- bypassing the clock boundary to prevent race conditions.
    ------------------------------------------------------------------------------
    process(rrat_map, rrat_flag, commit_valid_1, commit_arch_dest_1, commit_pd_1, commit_valid_2, commit_arch_dest_2, commit_pd_2, commit_flag_valid_1, commit_pf_1, commit_flag_valid_2, commit_pf_2)
        variable v_map : rrat_array;
        variable v_flag : std_logic_vector(4 downto 0);
    begin
        v_map := rrat_map;
        v_flag := rrat_flag;

        if commit_valid_1 = '1' then
            v_map(to_integer(unsigned(commit_arch_dest_1))) := commit_pd_1;
        end if;
        if commit_valid_2 = '1' then
            v_map(to_integer(unsigned(commit_arch_dest_2))) := commit_pd_2;
        end if;

        if commit_flag_valid_1 = '1' then v_flag := commit_pf_1; end if;
        if commit_flag_valid_2 = '1' then v_flag := commit_pf_2; end if;

        -- Flatten the mapping for easy transport to the Spec_RAT
        commit_rat_flat <= v_map(7) & v_map(6) & v_map(5) & v_map(4) &
                           v_map(3) & v_map(2) & v_map(1) & v_map(0);
        commit_flag_tag <= v_flag;
    end process;

    ------------------------------------------------------------------------------
    -- SYNCHRONOUS RETIREMENT LOGIC
    ------------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                for i in 0 to 7 loop rrat_map(i) <= std_logic_vector(to_unsigned(i, 5)); end loop;
                rrat_flag <= (others => '0');
                free_gpr1_en <= '0'; free_gpr2_en <= '0';
                free_f1_en <= '0'; free_f2_en <= '0';
            else
                free_gpr1_en <= '0'; free_gpr2_en <= '0';
                free_f1_en <= '0'; free_f2_en <= '0';
                
                -- Process Slot 1 Commit
                if commit_valid_1 = '1' then
                    free_gpr1_tag <= rrat_map(to_integer(unsigned(commit_arch_dest_1)));
                    free_gpr1_en  <= '1';
                    rrat_map(to_integer(unsigned(commit_arch_dest_1))) <= commit_pd_1;
                end if;
                
                if commit_flag_valid_1 = '1' then
                    free_f1_tag <= rrat_flag;
                    free_f1_en  <= '1';
                    rrat_flag   <= commit_pf_1;
                end if;
                
                -- Process Slot 2 Commit
                if commit_valid_2 = '1' then
                    -- Intra-cycle Overwrite protection: If both slots write to the same register,
                    -- release the mapping that Slot 1 just created!
                    if commit_valid_1 = '1' and commit_arch_dest_1 = commit_arch_dest_2 then
                        free_gpr2_tag <= commit_pd_1;
                    else
                        free_gpr2_tag <= rrat_map(to_integer(unsigned(commit_arch_dest_2)));
                    end if;
                    free_gpr2_en <= '1';
                    rrat_map(to_integer(unsigned(commit_arch_dest_2))) <= commit_pd_2;
                end if;

                if commit_flag_valid_2 = '1' then
                    if commit_flag_valid_1 = '1' then
                        free_f2_tag <= commit_pf_1;
                    else
                        free_f2_tag <= rrat_flag;
                    end if;
                    free_f2_en <= '1';
                    rrat_flag  <= commit_pf_2;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- DIAGNOSTICS LOGGING
    ------------------------------------------------------------------------------
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                if commit_valid_1 = '1' then
                    write(l, string'("[RRAT] Retired Arch R")); write(l, integer'image(to_integer(unsigned(commit_arch_dest_1))));
                    write(l, string'(" -> Phys P")); write(l, integer'image(to_integer(unsigned(commit_pd_1))));
                    writeline(output, l);
                end if;
                if commit_valid_2 = '1' then
                    write(l, string'("[RRAT] Retired Arch R")); write(l, integer'image(to_integer(unsigned(commit_arch_dest_2))));
                    write(l, string'(" -> Phys P")); write(l, integer'image(to_integer(unsigned(commit_pd_2))));
                    writeline(output, l);
                end if;
            end if;
        end if;
    end process;
end Behavioral;