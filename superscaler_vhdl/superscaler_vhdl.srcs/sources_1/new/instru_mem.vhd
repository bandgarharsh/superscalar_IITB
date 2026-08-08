library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity instru_mem is
    Port (
        clk       : in  std_logic;
        addr      : in  std_logic_VECTOR(15 downto 0);
        instruct1 : out std_logic_vector(15 downto 0);
        instruct2 : out std_logic_vector(15 downto 0)
    );
end instru_mem;

architecture Behavioral of instru_mem is

    type mem_array is array (0 to 255) of std_logic_vector(15 downto 0);

    signal mem : mem_array := (
        others => (others => '0')
    );

    signal word_addr : unsigned(14 downto 0);

begin

    word_addr <= unsigned(addr(15 downto 1));

    process(word_addr, mem)
    begin

        if word_addr <= 255 then
            instruct1 <= mem(to_integer(word_addr));

            if word_addr < 255 then
                instruct2 <= mem(to_integer(word_addr)+1);
            else
                instruct2 <= (others => '0');
            end if;

        else
            instruct1 <= (others => '0');
            instruct2 <= (others => '0');
        end if;

    end process;

end Behavioral;