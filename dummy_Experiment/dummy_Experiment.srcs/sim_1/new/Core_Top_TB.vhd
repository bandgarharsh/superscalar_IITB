library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity Core_Top_TB is
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

type expected_array_t is array (0 to 9) of std_logic_vector(15 downto 0);
    constant EXPECTED_RESULTS : expected_array_t := (
        0 => x"0064", -- I1: LLI R1, 100
        1 => x"002A", -- I2: LLI R2, 42
        2 => x"0000", -- I3: SW R2, R1, 2  (Mem[102] = 42)
        3 => x"002A", -- I4: LW R3, R1, 2  (R3 = 42)
        4 => x"0032", -- I5: ADI R4, R3, 8 (R4 = 50)
        5 => x"0000", -- I6: SW R4, R1, -2 (Mem[98] = 50)
        6 => x"0032", -- I7: LW R5, R1, -2 (R5 = 50)
        7 => x"005C", -- I8: ADD R6, R3, R5 (R6 = 92)
        8 => x"0005", -- I9: LLI R7, 5
        9 => x"0000"  -- I10: SW R6, R7, 0 (Mem[5] = 92)
    );

begin

    UUT: Core_Top port map (
        clk => clk, rst => rst, external_gpio_in => external_gpio_in, external_gpio_out => external_gpio_out,
        debug_fetch_pc => debug_fetch_pc, debug_commit_valid1 => debug_commit_valid1, debug_commit_valid2 => debug_commit_valid2,
        debug_commit_data1 => debug_commit_data1, debug_commit_data2 => debug_commit_data2, debug_commit_flag1 => debug_commit_flag1,
        debug_commit_flag2 => debug_commit_flag2, debug_global_flush => debug_global_flush, debug_stall_signals => debug_stall_signals
    );

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for clk_period/2;
            clk <= '1'; wait for clk_period/2;
        end loop;
        wait;
    end process;

    tracker_proc: process
        variable L : line;
        variable cycle_count : integer := 0;
    begin
        wait until rising_edge(clk);
        if rst = '0' then
            cycle_count := cycle_count + 1;
            write(L, string'("")); writeline(output, L);
            write(L, string'("[CYCLE ")); write(L, cycle_count); write(L, string'("] ----------------------------------------------------"));
            writeline(output, L);
            if cycle_count > 150 then 
                write(L, string'("!!! FATAL: Pipeline is deadlocked. Check the X-Ray traces above. !!!")); writeline(output, L);
                assert false severity failure;
            end if;
        end if;
    end process;

    stim_proc: process
        variable L : line;
        variable commits_seen : integer := 0;
    begin
        write(L, string'("==========================================================")); writeline(output, L);
        write(L, string'("--- SIMULATION STARTED: Resetting Core                 ---")); writeline(output, L);
        write(L, string'("==========================================================")); writeline(output, L);
        rst <= '1'; wait for clk_period * 5; rst <= '0';
        write(L, string'("--- CORE ONLINE: Tracking Commits                      ---")); writeline(output, L);

        -- THE MAGIC FIX: Automatically loop exactly EXPECTED_RESULTS'length times!
        while commits_seen < EXPECTED_RESULTS'length loop
            wait until rising_edge(clk);
            wait for 1 ns; 

            if debug_commit_valid1 = '1' and commits_seen < EXPECTED_RESULTS'length then
                write(L, string'("Commit #")); write(L, commits_seen + 1);
                write(L, string'(" (Slot 1) | Expected: ")); write(L, integer'image(to_integer(signed(EXPECTED_RESULTS(commits_seen)))));
                write(L, string'(" | Output: ")); write(L, integer'image(to_integer(signed(debug_commit_data1))));
                if debug_commit_data1 = EXPECTED_RESULTS(commits_seen) then
                    write(L, string'("  >>>  [PASS]")); writeline(output, L);
                else
                    write(L, string'("  >>>  [FAIL]")); writeline(output, L);
                end if;
                commits_seen := commits_seen + 1;
            end if;

            if debug_commit_valid2 = '1' and commits_seen < EXPECTED_RESULTS'length then
                write(L, string'("Commit #")); write(L, commits_seen + 1);
                write(L, string'(" (Slot 2) | Expected: ")); write(L, integer'image(to_integer(signed(EXPECTED_RESULTS(commits_seen)))));
                write(L, string'(" | Output: ")); write(L, integer'image(to_integer(signed(debug_commit_data2))));
                if debug_commit_data2 = EXPECTED_RESULTS(commits_seen) then
                    write(L, string'("  >>>  [PASS]")); writeline(output, L);
                else
                    write(L, string'("  >>>  [FAIL]")); writeline(output, L);
                end if;
                commits_seen := commits_seen + 1;
            end if;
        end loop;

        write(L, string'("")); writeline(output, L);
        write(L, string'("=====================================================")); writeline(output, L);
        write(L, string'("  ALL INSTRUCTIONS COMMITTED SUCCESSFULLY!           ")); writeline(output, L);
        write(L, string'("=====================================================")); writeline(output, L);
        
        sim_done <= true;
        std.env.stop;
        wait;
    end process;
end Behavior;