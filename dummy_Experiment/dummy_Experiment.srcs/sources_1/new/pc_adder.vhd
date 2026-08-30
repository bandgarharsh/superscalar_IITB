library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pc_adder is
    Port (
        pc     : in  std_logic_vector(15 downto 0);
        pc_out : out std_logic_vector(15 downto 0)
    );
end pc_adder;

architecture Behavioral of pc_adder is
begin

    pc_out <= std_logic_vector(unsigned(pc) + 4);

end Behavioral;