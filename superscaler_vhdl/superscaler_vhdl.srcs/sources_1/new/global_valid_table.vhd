library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity global_valid_table is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        -- Read addresses
        prs1_addr : in std_logic_vector(4 downto 0);
        prt1_addr : in std_logic_vector(4 downto 0);
        prs2_addr : in std_logic_vector(4 downto 0);
        prt2_addr : in std_logic_vector(4 downto 0);

        -- Ready outputs
        valid_rs1 : out std_logic;
        valid_rt1 : out std_logic;
        valid_rs2 : out std_logic;
        valid_rt2 : out std_logic;

        -- Allocation ports
        alloc_we1  : in std_logic;
        alloc_tag1 : in std_logic_vector(4 downto 0);

        alloc_we2  : in std_logic;
        alloc_tag2 : in std_logic_vector(4 downto 0);

        -- Common Data Bus (writeback)
        cbd_we1  : in std_logic;
        cbd_tag1 : in std_logic_vector(4 downto 0);

        cbd_we2  : in std_logic;
        cbd_tag2 : in std_logic_vector(4 downto 0)
    );
end global_valid_table;

architecture Behavioral of global_valid_table is

    signal ready_bits : std_logic_vector(31 downto 0);

begin

    ------------------------------------------------------------------
    -- Asynchronous Reads
    ------------------------------------------------------------------

    valid_rs1 <= ready_bits(to_integer(unsigned(prs1_addr)));
    valid_rt1 <= ready_bits(to_integer(unsigned(prt1_addr)));
    valid_rs2 <= ready_bits(to_integer(unsigned(prs2_addr)));
    valid_rt2 <= ready_bits(to_integer(unsigned(prt2_addr)));

    ------------------------------------------------------------------
    -- Update Ready Bits
    ------------------------------------------------------------------

    process(clk, rst)
    begin
        if rst = '1' then

            ready_bits <= (others => '1');

        elsif rising_edge(clk) then

            if alloc_we1 = '1' then
                ready_bits(to_integer(unsigned(alloc_tag1))) <= '0';
            end if;

            if alloc_we2 = '1' then
                ready_bits(to_integer(unsigned(alloc_tag2))) <= '0';
            end if;

            if cbd_we1 = '1' then
                ready_bits(to_integer(unsigned(cbd_tag1))) <= '1';
            end if;

            if cbd_we2 = '1' then
                ready_bits(to_integer(unsigned(cbd_tag2))) <= '1';
            end if;

        end if;
    end process;

end Behavioral;