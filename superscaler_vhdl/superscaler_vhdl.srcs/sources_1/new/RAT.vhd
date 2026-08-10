library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAT is
    Port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- --- MISPREDICTION RECOVERY ---
        flush         : in std_logic;
        rrat_map_flat : in std_logic_vector(44 downto 0); 

        -- --- READ PORTS (Sources) ---
        rs1 : in std_logic_vector(2 downto 0);
        rt1 : in std_logic_vector(2 downto 0);
        rs2 : in std_logic_vector(2 downto 0);
        rt2 : in std_logic_vector(2 downto 0);
        
        -- --- READ PORTS (Old Destinations for ROB) ---
        rd1 : in std_logic_vector(2 downto 0);
        rd2 : in std_logic_vector(2 downto 0);

        -- --- DEPENDENCY FLAGS ---
        route_rs2_from_inst1 : in std_logic;
        route_rt2_from_inst1 : in std_logic;
        
        -- --- PHYSICAL REGISTER OUTPUTS ---
        prs1 : out std_logic_vector(4 downto 0);
        prt1 : out std_logic_vector(4 downto 0);
        prs2 : out std_logic_vector(4 downto 0);
        prt2 : out std_logic_vector(4 downto 0);
        
        old_pr1 : out std_logic_vector(4 downto 0);
        old_pr2 : out std_logic_vector(4 downto 0);

        pr_flag1 : out std_logic_vector(4 downto 0);
        pr_flag2 : out std_logic_vector(4 downto 0);
        
        old_pr_flag1 : out std_logic_vector(4 downto 0);
        old_pr_flag2 : out std_logic_vector(4 downto 0);

        -- --- WRITE PORT 1 ---
        we1       : in std_logic;
        we_flag1  : in std_logic; 
        rd1_in    : in std_logic_vector(2 downto 0);
        new_gpr1  : in std_logic_vector(4 downto 0); -- Independent GPR PR
        new_flag1 : in std_logic_vector(4 downto 0); -- Independent Flag PR

        -- --- WRITE PORT 2 ---
        we2       : in std_logic;
        we_flag2  : in std_logic; 
        rd2_in    : in std_logic_vector(2 downto 0); 
        new_gpr2  : in std_logic_vector(4 downto 0);
        new_flag2 : in std_logic_vector(4 downto 0)
    );
end RAT;

architecture Behavioral of RAT is

    type rat_array is array (0 to 8) of std_logic_vector(4 downto 0);
    signal rat_map : rat_array;

begin

    process(clk, rst)
    begin
        if rst = '1' then
            for i in 0 to 8 loop
                rat_map(i) <= std_logic_vector(to_unsigned(i,5));
            end loop;

        elsif rising_edge(clk) then
            if flush = '1' then
                rat_map(0) <= rrat_map_flat(4 downto 0);
                rat_map(1) <= rrat_map_flat(9 downto 5);
                rat_map(2) <= rrat_map_flat(14 downto 10);
                rat_map(3) <= rrat_map_flat(19 downto 15);
                rat_map(4) <= rrat_map_flat(24 downto 20);
                rat_map(5) <= rrat_map_flat(29 downto 25);
                rat_map(6) <= rrat_map_flat(34 downto 30);
                rat_map(7) <= rrat_map_flat(39 downto 35);
                rat_map(8) <= rrat_map_flat(44 downto 40);
            else
                if we1 = '1' then rat_map(to_integer(unsigned(rd1_in))) <= new_gpr1; end if;
                if we2 = '1' then rat_map(to_integer(unsigned(rd2_in))) <= new_gpr2; end if;
                
                if we_flag1 = '1' then rat_map(8) <= new_flag1; end if;
                if we_flag2 = '1' then rat_map(8) <= new_flag2; end if;
            end if;
        end if;
    end process;

    prs1 <= rat_map(to_integer(unsigned(rs1)));
    prt1 <= rat_map(to_integer(unsigned(rt1)));

    -- GPR Forwarding
    prs2 <= new_gpr1 when route_rs2_from_inst1 = '1' else rat_map(to_integer(unsigned(rs2)));
    prt2 <= new_gpr1 when route_rt2_from_inst1 = '1' else rat_map(to_integer(unsigned(rt2)));
            
    old_pr1 <= rat_map(to_integer(unsigned(rd1)));
    old_pr2 <= new_gpr1 when (we1 = '1' and rd1 = rd2) else rat_map(to_integer(unsigned(rd2)));
    
    -- Flag Forwarding
    pr_flag1 <= rat_map(8);
    old_pr_flag1 <= rat_map(8);
    
    pr_flag2 <= new_flag1 when we_flag1 = '1' else rat_map(8);
    old_pr_flag2 <= new_flag1 when we_flag1 = '1' else rat_map(8);

end Behavioral;