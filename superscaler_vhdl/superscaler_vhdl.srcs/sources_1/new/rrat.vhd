----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.08.2026 11:25:31
-- Design Name: 
-- Module Name: rrat - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity rrat is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        
        retire1_valid : in std_logic;
        retire1_arch_reg : in std_logic_vector(2 downto 0);
        retire1_phys_reg : in std_logic_vector(4 downto 0);
        
        retire2_valid : in std_logic;
        retire2_arch_reg : in std_logic_vector(2 downto 0);
        retire2_phys_reg : in std_logic_vector(4 downto 0);
        
        rrat_map_flat : out std_logic_vector(39 downto 0)
    );
end rrat;

architecture Behavioral of rrat is
    
    type rrat_array is array (0 to 7) of std_logic_vector(4 downto 0);
    signal rrat_map : rrat_array;
    
begin
    
    rrat_map_flat <= rrat_map(7) & rrat_map(6)& rrat_map(5)& rrat_map(4)& 
                     rrat_map(3)& rrat_map(2)& rrat_map(1)& rrat_map(0);
                     
    process(clk, rst)
    begin
        if rst = '1' then
            for i in 0 to 7 loop 
                rrat_map(i) <= std_logic_vector(to_unsigned(i,5));
            end loop;
        
        elsif rising_edge(clk) then
            
            if retire1_valid = '1' then
                rrat_map(to_integer(unsigned(retire1_arch_reg))) <= retire1_phys_reg;
            end if;


            if retire2_valid = '1' then
                rrat_map(to_integer(unsigned(retire2_arch_reg))) <= retire2_phys_reg;
            end if;
            
        end if;
        
    end process;
end Behavioral;
