library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PRF is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        -- ==========================================
        -- Read Addresses (Tags from RAT)
        -- ==========================================
        -- Slot 1
        prs1_addr     : in std_logic_vector(4 downto 0);
        prt1_addr     : in std_logic_vector(4 downto 0);
        pr_flag1_addr : in std_logic_vector(4 downto 0); -- NEW: Tag for Flag 1

        -- Slot 2
        prs2_addr     : in std_logic_vector(4 downto 0);
        prt2_addr     : in std_logic_vector(4 downto 0);
        pr_flag2_addr : in std_logic_vector(4 downto 0); -- NEW: Tag for Flag 2

        -- ==========================================
        -- Read Data Outputs
        -- ==========================================
        -- Slot 1 Data
        data_rs1  : out std_logic_vector(15 downto 0);
        data_rt1  : out std_logic_vector(15 downto 0);
        flag1_out : out std_logic_vector(1 downto 0);    -- NEW: Extracted Flags

        -- Slot 2 Data
        data_rs2  : out std_logic_vector(15 downto 0);
        data_rt2  : out std_logic_vector(15 downto 0);
        flag2_out : out std_logic_vector(1 downto 0);    -- NEW: Extracted Flags

        -- ==========================================
        -- Write Ports (From Common Data Bus)
        -- ==========================================
        -- Write port 1
        we1          : in std_logic;
        p_dest1_addr : in std_logic_vector(4 downto 0);
        data_in1     : in std_logic_vector(15 downto 0);
        flags_in1    : in std_logic_vector(1 downto 0);  -- NEW: Flags from ALU

        -- Write port 2
        we2          : in std_logic;
        p_dest2_addr : in std_logic_vector(4 downto 0);
        data_in2     : in std_logic_vector(15 downto 0);
        flags_in2    : in std_logic_vector(1 downto 0)   -- NEW: Flags from ALU
    );
end PRF;

architecture Behavioral of PRF is

    -- The array is 18 bits wide: [17:16] Flags, [15:0] Data
    type reg_file_type is array (0 to 31) of std_logic_vector(17 downto 0);
    signal registers : reg_file_type;

begin

    ------------------------------------------------------------------
    -- Asynchronous Read Ports
    ------------------------------------------------------------------
    -- Read the bottom 16 bits for normal GPR data
    data_rs1 <= registers(to_integer(unsigned(prs1_addr)))(15 downto 0);
    data_rt1 <= registers(to_integer(unsigned(prt1_addr)))(15 downto 0);
    
    data_rs2 <= registers(to_integer(unsigned(prs2_addr)))(15 downto 0);
    data_rt2 <= registers(to_integer(unsigned(prt2_addr)))(15 downto 0);

    -- Read the top 2 bits for the Flags
    flag1_out <= registers(to_integer(unsigned(pr_flag1_addr)))(17 downto 16);
    flag2_out <= registers(to_integer(unsigned(pr_flag2_addr)))(17 downto 16);

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
            
            -- Concatenate the 2 flag bits and the 16 data bits into the 18-bit slot
            if we1 = '1' then
                registers(to_integer(unsigned(p_dest1_addr))) <= flags_in1 & data_in1;
            end if;

            if we2 = '1' then
                registers(to_integer(unsigned(p_dest2_addr))) <= flags_in2 & data_in2;
            end if;

        end if;
    end process;

end Behavioral;