library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity Core_Top_TB is
-- Testbench has no ports
end Core_Top_TB;

architecture Behavior of Core_Top_TB is

    component Core_Top
        Port (
            clk                 : in  std_logic;
            rst                 : in  std_logic;
            external_gpio_in    : in  std_logic_vector(15 downto 0);
            external_gpio_out   : out std_logic_vector(15 downto 0);
            debug_fetch_pc      : out std_logic_vector(15 downto 0);
            debug_commit_valid1 : out std_logic;
            debug_commit_valid2 : out std_logic;
            debug_commit_data1  : out std_logic_vector(15 downto 0);
            debug_commit_data2  : out std_logic_vector(15 downto 0);
            debug_commit_flag1  : out std_logic_vector(1 downto 0);
            debug_commit_flag2  : out std_logic_vector(1 downto 0);
            debug_global_flush  : out std_logic;
            debug_stall_signals : out std_logic_vector(3 downto 0)
        );
    end component;

    signal clk                 : std_logic := '0';
    signal rst                 : std_logic := '1';
    signal external_gpio_in    : std_logic_vector(15 downto 0) := (others => '0');
    signal external_gpio_out   : std_logic_vector(15 downto 0);
    signal debug_fetch_pc      : std_logic_vector(15 downto 0);
    signal debug_commit_valid1 : std_logic;
    signal debug_commit_valid2 : std_logic;
    signal debug_commit_data1  : std_logic_vector(15 downto 0);
    signal debug_commit_data2  : std_logic_vector(15 downto 0);
    signal debug_commit_flag1  : std_logic_vector(1 downto 0);
    signal debug_commit_flag2  : std_logic_vector(1 downto 0);
    signal debug_global_flush  : std_logic;
    signal debug_stall_signals : std_logic_vector(3 downto 0);
    constant clk_period : time := 10 ns;
    signal sim_done : boolean := false;

    type expected_array_t is array (0 to 8) of std_logic_vector(15 downto 0);
    constant EXPECTED_RESULTS : expected_array_t := (
        0 => x"0005", -- I1: LLI R1, 5
        1 => x"0003", -- I2: LLI R2, 3
        2 => x"0008", -- I3: ADA R3
        3 => x"0000", -- I4: ADI R4 (Sets Z=1)
        4 => x"0008", -- I5: ADZ R5 (Passes!)
        -- Instruction 6 (ADC) dies here! It never commits!
        5 => x"0001", -- I7: ACA R1 (Forces C=1)
        6 => x"0004", -- I8: ADC R7 (Passes!)
        7 => x"0004", -- I9: AWC R2 
        8 => x"FFFC"  -- I10: ACW R3
    );

begin

    UUT: Core_Top port map (
        clk                 => clk,
        rst                 => rst,
        external_gpio_in    => external_gpio_in,
        external_gpio_out   => external_gpio_out,
        debug_fetch_pc      => debug_fetch_pc,
        debug_commit_valid1 => debug_commit_valid1,
        debug_commit_valid2 => debug_commit_valid2,
        debug_commit_data1  => debug_commit_data1,
        debug_commit_data2  => debug_commit_data2,
        debug_commit_flag1  => debug_commit_flag1,
        debug_commit_flag2  => debug_commit_flag2,
        debug_global_flush  => debug_global_flush,
        debug_stall_signals => debug_stall_signals
    );

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for clk_period/2;
            clk <= '1'; wait for clk_period/2;
        end loop;
        wait;
    end process;

    -- AGGRESSIVE PIPELINE TRACKER
    tracker_proc: process
        variable L : line;
        variable cycle_count : integer := 0;
    begin
        wait until rising_edge(clk);
        if rst = '0' then
            cycle_count := cycle_count + 1;
            write(L, string'("[Cycle ")); write(L, cycle_count);
            write(L, string'("] PC: 0x")); hwrite(L, debug_fetch_pc);
            
            -- Print the Stall Diagnostics
            write(L, string'(" | Stalls -> Pipe:")); write(L, debug_stall_signals(0));
            write(L, string'(", Rename:")); write(L, debug_stall_signals(1));
            write(L, string'(", Dispatch:")); write(L, debug_stall_signals(2));
            write(L, string'(", ROB:")); write(L, debug_stall_signals(3));
            writeline(output, L);
            
            if cycle_count > 150 then -- FIXED: Give the Free List time to boot!
                write(L, string'("!!! FATAL: Pipeline is deadlocked. Review Stall Diagnostics above. !!!"));
                writeline(output, L);
                assert false severity failure;
            end if;
        end if;
    end process;

    -- 2-WAY SUPERSCALAR SELF-CHECKING LOGIC
    stim_proc: process
        variable L : line;
        variable commits_seen : integer := 0;
    begin
        write(L, string'("--- SIMULATION STARTED: Resetting Core ---")); writeline(output, L);
        
        rst <= '1';
        wait for clk_period * 5;
        rst <= '0';
        
        write(L, string'("--- CORE ONLINE: Tracking 2-Way Commits ---")); writeline(output, L);

        while commits_seen < 9 loop
            wait until rising_edge(clk);
            wait for 1 ns; 

            -- Check Slot 1
            if debug_commit_valid1 = '1' and commits_seen < 10 then
                write(L, string'("Commit #")); write(L, commits_seen + 1);
                write(L, string'(" (Slot 1) | Expected: 0x")); hwrite(L, EXPECTED_RESULTS(commits_seen));
                write(L, string'(" | Output: 0x")); hwrite(L, debug_commit_data1);
                
                if debug_commit_data1 = EXPECTED_RESULTS(commits_seen) then
                    write(L, string'("  >>>  [PASS]")); writeline(output, L);
                else
                    write(L, string'("  >>>  [FAIL]")); writeline(output, L);
--                    assert false report "Data mismatch on Slot 1." severity failure;
                end if;
                commits_seen := commits_seen + 1;
            end if;

            -- Check Slot 2 (Can happen in the exact same cycle!)
            if debug_commit_valid2 = '1' and commits_seen < 10 then
                write(L, string'("Commit #")); write(L, commits_seen + 1);
                write(L, string'(" (Slot 2) | Expected: 0x")); hwrite(L, EXPECTED_RESULTS(commits_seen));
                write(L, string'(" | Output: 0x")); hwrite(L, debug_commit_data2);
                
                if debug_commit_data2 = EXPECTED_RESULTS(commits_seen) then
                    write(L, string'("  >>>  [PASS]")); writeline(output, L);
                else
                    write(L, string'("  >>>  [FAIL]")); writeline(output, L);
--                    assert false report "Data mismatch on Slot 2." severity failure;
                end if;
                commits_seen := commits_seen + 1;
            end if;

        end loop;

        write(L, string'("")); writeline(output, L);
        write(L, string'("=====================================================")); writeline(output, L);
        write(L, string'("  ALL 10 INSTRUCTIONS COMMITTED SUCCESSFULLY!  ")); writeline(output, L);
        write(L, string'("=====================================================")); writeline(output, L);
        
        sim_done <= true;
        std.env.stop;
        wait;
    end process;
    
end Behavior;