library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity instruction_fetch is
    Port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        
        stall_fetch: in  std_logic;  -- ADDED: Stall signal from ID stage
        
        pc_bran    : in  std_logic_vector(15 downto 0);
        sel        : in  std_logic_vector(1 downto 0);

        instruct1  : out std_logic_vector(15 downto 0);
        instruct2  : out std_logic_vector(15 downto 0);
        pc         : out std_logic_vector(15 downto 0)
    );
end instruction_fetch;

architecture Behavioral of instruction_fetch is

    signal pc_in  : std_logic_vector(15 downto 0);
    signal pc_4   : std_logic_vector(15 downto 0);
    signal pc_int : std_logic_vector(15 downto 0);

begin

    ------------------------------------------------------------------
    -- PC Register
    ------------------------------------------------------------------

    pc_Reg : entity work.pc_reg
        port map(
            clk    => clk,
            rst    => rst,
            pc_in  => pc_in,
            pc_out => pc_int
        );

    ------------------------------------------------------------------
    -- PC Adder
    ------------------------------------------------------------------

    pc_Adder : entity work.pc_adder
        port map(
            pc     => pc_int,
            pc_out => pc_4
        );

    ------------------------------------------------------------------
    -- Instruction Memory
    ------------------------------------------------------------------

    instru_Mem : entity work.instru_mem
        port map(
            clk       => clk,
            addr      => pc_int,
            instruct1 => instruct1,
            instruct2 => instruct2
        );

    ------------------------------------------------------------------
    -- Next PC Selection
    ------------------------------------------------------------------

    -- ADDED stall_fetch to the sensitivity list
    process(sel, pc_4, pc_bran, pc_int, stall_fetch)
    begin
        -- PRIORITY: If stalled, freeze the PC where it is!
        if stall_fetch = '1' then
            pc_in <= pc_int;
        else
            case sel is
                when "00" =>
                    pc_in <= pc_4;

                when "01" =>
                    pc_in <= pc_bran;

                when others =>
                    pc_in <= pc_int;
            end case;
        end if;
    end process;

    pc <= pc_int;

end Behavioral;