library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity IF_ID is
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Control Signals from ID_stage
        stall_fetch : in  std_logic;
        slide_inst2 : in  std_logic;

        -- Data from Fetch Stage
        pc          : in  std_logic_vector(15 downto 0);
        instruct1   : in  std_logic_vector(15 downto 0);
        instruct2   : in  std_logic_vector(15 downto 0);

        -- Data to Decode Stage
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
            pc1_reg       <= (others => '0');
            pc2_reg       <= (others => '0');

        elsif rising_edge(clk) then

            -- PRIORITY 1: SLIDE SLOT 2 INTO SLOT 1
            if slide_inst2 = '1' then
                instruct1_reg <= instruct2_reg;
                pc1_reg       <= pc2_reg;
                
                -- Insert a bubble into Slot 2 so it doesn't execute twice!
                instruct2_reg <= (others => '0');
                
            -- PRIORITY 2: FREEZE THE PIPELINE
            elsif stall_fetch = '1' then
                -- Do nothing. The registers will hold their current values.
                null;
                
            -- PRIORITY 3: NORMAL FETCH
            else
                instruct1_reg <= instruct1;
                instruct2_reg <= instruct2;
                pc1_reg       <= pc;
                pc2_reg       <= std_logic_vector(unsigned(pc) + 2);
            end if;

        end if;
    end process;

    instruct1_o <= instruct1_reg;
    instruct2_o <= instruct2_reg;
    pc_1o       <= pc1_reg;
    pc_2o       <= pc2_reg;

end Behavioral;