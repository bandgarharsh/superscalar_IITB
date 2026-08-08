library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PRF is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        -- Read addresses
        prs1_addr : in std_logic_vector(4 downto 0);
        prt1_addr : in std_logic_vector(4 downto 0);
        prs2_addr : in std_logic_vector(4 downto 0);
        prt2_addr : in std_logic_vector(4 downto 0);

        -- Read data
        data_rs1 : out std_logic_vector(15 downto 0);
        data_rt1 : out std_logic_vector(15 downto 0);
        data_rs2 : out std_logic_vector(15 downto 0);
        data_rt2 : out std_logic_vector(15 downto 0);

        -- Write port 1
        we1          : in std_logic;
        p_dest1_addr : in std_logic_vector(4 downto 0);
        data_in1     : in std_logic_vector(15 downto 0);

        -- Write port 2
        we2          : in std_logic;
        p_dest2_addr : in std_logic_vector(4 downto 0);
        data_in2     : in std_logic_vector(15 downto 0)
    );
end PRF;

architecture Behavioral of PRF is

    type reg_file_type is array (0 to 31) of std_logic_vector(15 downto 0);
    signal registers : reg_file_type;

begin

    ------------------------------------------------------------------
    -- Asynchronous Read Ports
    ------------------------------------------------------------------

    data_rs1 <= registers(to_integer(unsigned(prs1_addr)));
    data_rt1 <= registers(to_integer(unsigned(prt1_addr)));
    data_rs2 <= registers(to_integer(unsigned(prs2_addr)));
    data_rt2 <= registers(to_integer(unsigned(prt2_addr)));

    ------------------------------------------------------------------
    -- Write Ports
    ------------------------------------------------------------------

    process(clk, rst)
    begin
        if rst = '1' then

            for i in 0 to 31 loop
                registers(i) <= (others => '0');
            end loop;

        elsif rising_edge(clk) then

            if we1 = '1' then
                registers(to_integer(unsigned(p_dest1_addr))) <= data_in1;
            end if;

            if we2 = '1' then
                registers(to_integer(unsigned(p_dest2_addr))) <= data_in2;
            end if;

        end if;
    end process;

end Behavioral;