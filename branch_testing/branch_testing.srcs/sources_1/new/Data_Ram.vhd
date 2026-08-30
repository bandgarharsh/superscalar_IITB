library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Data_RAM is
    Port (
        clk             : in  std_logic;
        
        -- ==========================================
        -- LOAD QUEUE INTERFACE (Read Port)
        -- ==========================================
        ram_read_en     : in  std_logic;
        ram_read_addr   : in  std_logic_vector(15 downto 0);
        ram_data_out    : out std_logic_vector(15 downto 0);
        
        -- ==========================================
        -- STORE QUEUE INTERFACE (Write Port from Commit)
        -- ==========================================
        ram_write_en    : in  std_logic;
        ram_write_addr  : in  std_logic_vector(15 downto 0);
        ram_write_data  : in  std_logic_vector(15 downto 0)
    );
end Data_RAM;

architecture Behavioral of Data_RAM is

    -- Simple RAM array (Size reduced for fast simulation, expand for synthesis)
    type ram_type is array (0 to 511) of std_logic_vector(15 downto 0);
    signal RAM : ram_type := (others => x"0000");

begin

    process(clk)
    begin
        if rising_edge(clk) then
            
            -- WRITE: Store Queue physically commits data to RAM
            if ram_write_en = '1' then
                RAM(to_integer(unsigned(ram_write_addr))) <= ram_write_data;
            end if;
            
            -- READ: Load Queue requests data
            -- Data is available on the next clock cycle (Standard Block RAM behavior)
            if ram_read_en = '1' then
                ram_data_out <= RAM(to_integer(unsigned(ram_read_addr)));
            end if;
            
        end if;
    end process;

end Behavioral;