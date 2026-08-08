library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pc_reg is
    Port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        pc_in  : in  std_logic_vector(15 downto 0);
        pc_out : out std_logic_vector(15 downto 0)
    );
end pc_reg;

architecture Behavioral of pc_reg is
    signal pc_out_reg : std_logic_vector(15 downto 0);
begin

    process(clk, rst)
    begin
        if rst = '1' then
            pc_out_reg <= (others => '0');
        elsif rising_edge(clk) then
            pc_out_reg <= pc_in;
        end if;
    end process;

    pc_out <= pc_out_reg;

end Behavioral;