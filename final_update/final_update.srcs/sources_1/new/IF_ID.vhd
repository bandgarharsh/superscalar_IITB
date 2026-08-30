library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity IF_ID is
    Port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        flush        : in  std_logic; -- Pipeline flush on mispredict
        stall_fetch  : in  std_logic; -- Hold state when downstream stalls

        -- Inputs from Fetch Stage
        valid1_in    : in  std_logic;
        valid2_in    : in  std_logic;
        pc1_in       : in  std_logic_vector(15 downto 0);
        pc2_in       : in  std_logic_vector(15 downto 0);
        instruct1_in : in  std_logic_vector(15 downto 0);
        instruct2_in : in  std_logic_vector(15 downto 0);

        -- Outputs to Decode Stage
        valid1_out   : out std_logic;
        valid2_out   : out std_logic;
        pc1_out      : out std_logic_vector(15 downto 0);
        pc2_out      : out std_logic_vector(15 downto 0);
        instruct1_out: out std_logic_vector(15 downto 0);
        instruct2_out: out std_logic_vector(15 downto 0)
    );
end IF_ID;

architecture Behavioral of IF_ID is
    signal valid1_reg, valid2_reg       : std_logic;
    signal pc1_reg, pc2_reg             : std_logic_vector(15 downto 0);
    signal instruct1_reg, instruct2_reg : std_logic_vector(15 downto 0);
begin

    process(clk, rst)
    begin
        if rst = '1' then
            valid1_reg    <= '0';
            valid2_reg    <= '0';
            pc1_reg       <= (others => '0');
            pc2_reg       <= (others => '0');
            instruct1_reg <= (others => '0');
            instruct2_reg <= (others => '0');
        elsif rising_edge(clk) then
            if flush = '1' then
                -- Convert pipeline entries into bubbles on flush
                valid1_reg <= '0';
                valid2_reg <= '0';
            elsif stall_fetch = '0' then
                -- Normal pipeline advance
                valid1_reg    <= valid1_in;
                valid2_reg    <= valid2_in;
                pc1_reg       <= pc1_in;
                pc2_reg       <= pc2_in;
                instruct1_reg <= instruct1_in;
                instruct2_reg <= instruct2_in;
            end if;
            -- If stall_fetch = '1', registers maintain current state
        end if;
    end process;

    valid1_out    <= valid1_reg;
    valid2_out    <= valid2_reg;
    pc1_out       <= pc1_reg;
    pc2_out       <= pc2_reg;
    instruct1_out <= instruct1_reg;
    instruct2_out <= instruct2_reg;

end Behavioral;