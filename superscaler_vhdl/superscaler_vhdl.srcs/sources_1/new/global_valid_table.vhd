library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity global_valid_table is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        -- --- MISPREDICTION RECOVERY ---
        flush         : in std_logic;
        rrat_map_flat : in std_logic_vector(44 downto 0);

        prs1_addr, prt1_addr, prs2_addr, prt2_addr : in std_logic_vector(4 downto 0);
        valid_rs1, valid_rt1, valid_rs2, valid_rt2 : out std_logic;

        alloc_we1  : in std_logic; alloc_tag1 : in std_logic_vector(4 downto 0);
        alloc_we2  : in std_logic; alloc_tag2 : in std_logic_vector(4 downto 0);

        cbd_we1  : in std_logic; cbd_tag1 : in std_logic_vector(4 downto 0);
        cbd_we2  : in std_logic; cbd_tag2 : in std_logic_vector(4 downto 0)
    );
end global_valid_table;

architecture Behavioral of global_valid_table is
    signal ready_bits : std_logic_vector(31 downto 0);
begin
    valid_rs1 <= ready_bits(to_integer(unsigned(prs1_addr)));
    valid_rt1 <= ready_bits(to_integer(unsigned(prt1_addr)));
    valid_rs2 <= ready_bits(to_integer(unsigned(prs2_addr)));
    valid_rt2 <= ready_bits(to_integer(unsigned(prt2_addr)));

    process(clk, rst)
    begin
        if rst = '1' then
            ready_bits <= (others => '1');

        elsif rising_edge(clk) then
            -- 1. Flush Recovery: RRAT tags are Valid, everything else is Invalid
            if flush = '1' then
                ready_bits <= (others => '0');
                for j in 0 to 8 loop
                    ready_bits(to_integer(unsigned(rrat_map_flat((j*5)+4 downto j*5)))) <= '1';
                end loop;

            -- 2. Normal Pipeline Operation
            else
                if alloc_we1 = '1' then ready_bits(to_integer(unsigned(alloc_tag1))) <= '0'; end if;
                if alloc_we2 = '1' then ready_bits(to_integer(unsigned(alloc_tag2))) <= '0'; end if;
                
                -- Writeback strictly overrides allocation in case of single-cycle timing
                if cbd_we1 = '1' then ready_bits(to_integer(unsigned(cbd_tag1))) <= '1'; end if;
                if cbd_we2 = '1' then ready_bits(to_integer(unsigned(cbd_tag2))) <= '1'; end if;
            end if;
        end if;
    end process;
end Behavioral;