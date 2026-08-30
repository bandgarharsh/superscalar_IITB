library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

library STD;
use STD.TEXTIO.ALL;


entity instru_mem is
    Port (
        addr      : in  std_logic_vector(15 downto 0);

        instruct1 : out std_logic_vector(15 downto 0);
        instruct2 : out std_logic_vector(15 downto 0)
    );
end instru_mem;


architecture Behavioral of instru_mem is

    -- 256 words × 16 bits
    type mem_array is array (0 to 255)
        of std_logic_vector(15 downto 0);

    impure function init_mem
        return mem_array is

        file mem_file : text open read_mode is "instruction.mem";

        variable line_buf : line;
        variable temp_mem : mem_array := (
            others => (others => '0')
        );

        variable i : integer := 0;

    begin

        while not endfile(mem_file) and i < 256 loop

            readline(mem_file, line_buf);
            hread(line_buf, temp_mem(i));

            i := i + 1;

        end loop;

        return temp_mem;

    end function;


    signal mem : mem_array := init_mem;

    signal word_addr : unsigned(14 downto 0);

begin

    ----------------------------------------------------------------
    -- Byte address → instruction word address
    --
    -- 16-bit instruction = 2 bytes
    --
    -- addr = 0  → instruction 0
    -- addr = 2  → instruction 1
    -- addr = 4  → instruction 2
    ----------------------------------------------------------------

    word_addr <= unsigned(addr(15 downto 1));


    ----------------------------------------------------------------
    -- TWO INSTRUCTIONS FETCH
    ----------------------------------------------------------------

    process(word_addr, mem)
    begin

        if word_addr <= 255 then

            -- First instruction
            instruct1 <= mem(to_integer(word_addr));

            -- Second instruction
            if word_addr < 255 then
                instruct2 <= mem(to_integer(word_addr) + 1);
            else
                instruct2 <= (others => '0');
            end if;

        else

            instruct1 <= (others => '0');
            instruct2 <= (others => '0');

        end if;

    end process;

end Behavioral;