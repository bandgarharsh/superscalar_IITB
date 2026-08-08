library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAT is
    Port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- --- MISPREDICTION RECOVERY INTERFACE ---
        flush         : in std_logic;
        -- Flat 40-bit vector from the Retirement RAT (8 registers * 5 bits)
        rrat_map_flat : in std_logic_vector(39 downto 0);

        -- --- READ PORTS ---
        rs1 : in std_logic_vector(2 downto 0);
        rt1 : in std_logic_vector(2 downto 0);
        rs2 : in std_logic_vector(2 downto 0);
        rt2 : in std_logic_vector(2 downto 0);

        -- --- DEPENDENCY FLAGS ---
        route_rs2_from_inst1 : in std_logic;
        route_rt2_from_inst1 : in std_logic;
        
        -- Physical register outputs
        prs1 : out std_logic_vector(4 downto 0);
        prt1 : out std_logic_vector(4 downto 0);
        prs2 : out std_logic_vector(4 downto 0);
        prt2 : out std_logic_vector(4 downto 0);

        -- --- WRITE PORT 1 ---
        we1     : in std_logic;
        rd1     : in std_logic_vector(2 downto 0);
        new_pr1 : in std_logic_vector(4 downto 0);

        -- --- WRITE PORT 2 ---
        we2     : in std_logic;
        rd2     : in std_logic_vector(2 downto 0);
        new_pr2 : in std_logic_vector(4 downto 0)
    );
end RAT;

architecture Behavioral of RAT is

    type rat_array is array (0 to 7) of std_logic_vector(4 downto 0);
    signal rat_map : rat_array;

begin

    ------------------------------------------------------------------
    -- RAT Update (Sequential)
    ------------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            for i in 0 to 7 loop
                rat_map(i) <= std_logic_vector(to_unsigned(i,5));
            end loop;

        elsif rising_edge(clk) then
            
            -- If the ROB detects a misprediction, instantly overwrite 
            -- the speculative map with the safe RRAT map.
            if flush = '1' then
                rat_map(0) <= rrat_map_flat(4 downto 0);
                rat_map(1) <= rrat_map_flat(9 downto 5);
                rat_map(2) <= rrat_map_flat(14 downto 10);
                rat_map(3) <= rrat_map_flat(19 downto 15);
                rat_map(4) <= rrat_map_flat(24 downto 20);
                rat_map(5) <= rrat_map_flat(29 downto 25);
                rat_map(6) <= rrat_map_flat(34 downto 30);
                rat_map(7) <= rrat_map_flat(39 downto 35);
                
            else
                -- Port 1 update
                if we1 = '1' then
                    rat_map(to_integer(unsigned(rd1))) <= new_pr1;
                end if;

                -- Port 2 update
                -- Because this is evaluated second, if rd2 == rd1 (a WAW hazard), 
                -- this assignment safely overwrites Port 1's assignment.
                if we2 = '1' then
                    rat_map(to_integer(unsigned(rd2))) <= new_pr2;
                end if;
            end if;

        end if;
    end process;

    ------------------------------------------------------------------
    -- Read Logic (Combinational Forwarding)
    ------------------------------------------------------------------
    prs1 <= rat_map(to_integer(unsigned(rs1)));
    prt1 <= rat_map(to_integer(unsigned(rt1)));

    prs2 <= new_pr1 when route_rs2_from_inst1 = '1' else 
            rat_map(to_integer(unsigned(rs2)));

    prt2 <= new_pr1 when route_rt2_from_inst1 = '1' else 
            rat_map(to_integer(unsigned(rt2)));

end Behavioral;