library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity instruction_decoder is
    Port (
        instr      : in  std_logic_vector(15 downto 0);

        valid_inst : out std_logic;
        opcode     : out std_logic_vector(3 downto 0);

        ra         : out std_logic_vector(2 downto 0);
        rb         : out std_logic_vector(2 downto 0);
        rc         : out std_logic_vector(2 downto 0);

        imm_ext    : out std_logic_vector(15 downto 0);

        comp_bit   : out std_logic;
        cz_bits    : out std_logic_vector(1 downto 0)
    );
end instruction_decoder;

architecture Behavioral of instruction_decoder is

begin

    opcode <= instr(15 downto 12);

    valid_inst <= '1' when instr /= x"0000" else '0';

    process(instr)
    begin

        -- Default assignments
        ra <= instr(11 downto 9);
        rb <= instr(8 downto 6);
        rc <= "000";

        imm_ext <= (others => '0');

        comp_bit <= '0';
        cz_bits  <= "00";

        case instr(15 downto 12) is

            --------------------------------------------------------
            -- I-Type
            --------------------------------------------------------
            when "0000" | "0100" | "0101" | "1000" | "1001" =>

                imm_ext <= std_logic_vector(
                    resize(signed(instr(5 downto 0)),16)
                );

            --------------------------------------------------------
            -- R-Type
            --------------------------------------------------------
            when "0001" | "0010" =>

                rc <= instr(5 downto 3);
                comp_bit <= instr(2);
                cz_bits <= instr(1 downto 0);

            --------------------------------------------------------
            -- JLR
            --------------------------------------------------------
            when "1101" =>

                null;

            --------------------------------------------------------
            -- J-Type
            --------------------------------------------------------
            when "1100" | "1111" =>

                rb <= "000";

                imm_ext <= std_logic_vector(
                    resize(signed(instr(8 downto 0)),16)
                );

            --------------------------------------------------------
            -- LLI,
            --------------------------------------------------------
            when "0011" =>

                rb <= "000";

                imm_ext <= std_logic_vector(
                    resize(unsigned(instr(8 downto 0)),16)
                );
                
--                 LM, SM
            when "0110" | "0111" =>

                rb <= "000";

                imm_ext <= (others => '0');
            --------------------------------------------------------
            -- Default
            --------------------------------------------------------
            when others =>

                rb <= "000";
                rc <= "000";
                imm_ext <= (others => '0');
                comp_bit <= '0';
                cz_bits <= "00";

        end case;

    end process;

end Behavioral;