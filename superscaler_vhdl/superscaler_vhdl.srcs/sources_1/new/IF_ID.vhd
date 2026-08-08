library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity IF_ID is
    Port (
        clk        : in  std_logic;
        rst        : in  std_logic;

        pc         : in  std_logic_vector(15 downto 0);
        instruct1  : in  std_logic_vector(15 downto 0);
        instruct2  : in  std_logic_vector(15 downto 0);

        instruct1_o : out std_logic_vector(15 downto 0);
        instruct2_o : out std_logic_vector(15 downto 0);
        pc_1o       : out std_logic_vector(15 downto 0);
        pc_2o       : out std_logic_vector(15 downto 0)
    );
end IF_ID;

architecture Behavioral of IF_ID is

    signal instruct1_reg : std_logic_vector(15 downto 0);
    signal instruct2_reg : std_logic_vector(15 downto 0);
    signal pc1_reg       : std_logic_vector(15 downto 0);
    signal pc2_reg       : std_logic_vector(15 downto 0);

begin

    process(clk, rst)
    begin
        if rst = '1' then

            instruct1_reg <= (others => '0');
            instruct2_reg <= (others => '0');
            pc1_reg <= (others => '0');
            pc2_reg <= (others => '0');

        elsif rising_edge(clk) then

            instruct1_reg <= instruct1;
            instruct2_reg <= instruct2;
            pc1_reg <= pc;
            pc2_reg <= std_logic_vector(unsigned(pc) + 2);

        end if;
    end process;

    instruct1_o <= instruct1_reg;
    instruct2_o <= instruct2_reg;
    pc_1o <= pc1_reg;
    pc_2o <= pc2_reg;

end Behavioral;