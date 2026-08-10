library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rrat is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        
        -- Slot 1 Retirement
        retire1_valid    : in std_logic;
        retire1_we_flag  : in std_logic; -- NEW: Does retiring inst 1 update flags?
        retire1_arch_reg : in std_logic_vector(2 downto 0);
        retire1_phys_reg : in std_logic_vector(4 downto 0);
        
        -- Slot 2 Retirement
        retire2_valid    : in std_logic;
        retire2_we_flag  : in std_logic; -- NEW: Does retiring inst 2 update flags?
        retire2_arch_reg : in std_logic_vector(2 downto 0);
        retire2_phys_reg : in std_logic_vector(4 downto 0);
        
        -- Expanded to 45 bits (9 entries * 5 bits)
        rrat_map_flat    : out std_logic_vector(44 downto 0)
    );
end rrat;

architecture Behavioral of rrat is
    
    -- 9 Entries (0 to 7 = GPRs, 8 = Flags)
    type rrat_array is array (0 to 8) of std_logic_vector(4 downto 0);
    signal rrat_map : rrat_array;
    
begin
    
    rrat_map_flat <= rrat_map(8) & rrat_map(7) & rrat_map(6) & rrat_map(5) & 
                     rrat_map(4) & rrat_map(3) & rrat_map(2) & rrat_map(1) & rrat_map(0);
                     
    process(clk, rst)
    begin
        if rst = '1' then
            for i in 0 to 8 loop 
                rrat_map(i) <= std_logic_vector(to_unsigned(i,5));
            end loop;
        
        elsif rising_edge(clk) then
            
            -- Slot 1 Commit
            if retire1_valid = '1' then
                rrat_map(to_integer(unsigned(retire1_arch_reg))) <= retire1_phys_reg;
                if retire1_we_flag = '1' then
                    rrat_map(8) <= retire1_phys_reg;
                end if;
            end if;

            -- Slot 2 Commit (Safely overrides Slot 1 if both update flags)
            if retire2_valid = '1' then
                rrat_map(to_integer(unsigned(retire2_arch_reg))) <= retire2_phys_reg;
                if retire2_we_flag = '1' then
                    rrat_map(8) <= retire2_phys_reg;
                end if;
            end if;
            
        end if;
    end process;
end Behavioral;