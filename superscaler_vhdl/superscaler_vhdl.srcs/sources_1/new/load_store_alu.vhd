----------------------------------------------------------------------------------
-- Module Name: load_store_alu - Behavioral
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity load_store_alu is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        
        issue_valid   : in std_logic;
        issue_is_st   : in std_logic;
        issue_addr    : in std_logic_vector(15 downto 0);
        issue_data    : in std_logic_vector(15 downto 0);
        issue_dest_pr : in std_logic_vector(4 downto 0);
        issue_rob_tag : in std_logic_vector(2 downto 0); -- CHANGED: 3-bit tag
        
        mem_we       : out std_logic;
        mem_addr     : out std_logic_vector(15 downto 0);
        mem_data_out : out std_logic_vector(15 downto 0);
        mem_data_in  : in std_logic_vector(15 downto 0);
        
        cdb_valid   : out std_logic;
        cdb_tag     : out std_logic_vector(4 downto 0);
        cdb_data    : out std_logic_vector(15 downto 0);
        cdb_rob_tag : out std_logic_vector(2 downto 0)   -- CHANGED: 3-bit tag
  );
end load_store_alu;

architecture Behavioral of load_store_alu is

    signal pending_valid   : std_logic := '0';
    signal pending_is_st   : std_logic := '0';
    signal pending_dest_pr : std_logic_vector(4 downto 0) := (others => '0');
    signal pending_rob_tag : std_logic_vector(2 downto 0) := (others => '0'); -- CHANGED: 3-bit tag
    
begin

    -- Left as combinational per reviewer recommendation (pending RAM type)
    mem_we <= '1' when (issue_valid = '1' and issue_is_st = '1') else '0';
    mem_addr <= issue_addr;
    mem_data_out <= issue_data;
    
    process(clk ,rst)
    begin
        if rst = '1' then
            pending_valid   <= '0';
            pending_is_st   <= '0';
            pending_dest_pr <= (others => '0');
            pending_rob_tag <= (others => '0');
            
            -- FIXED: Explicitly reset all CDB outputs
            cdb_valid   <= '0';
            cdb_tag     <= (others => '0');
            cdb_data    <= (others => '0');
            cdb_rob_tag <= (others => '0');
        
        elsif rising_edge(clk) then
            
            pending_valid   <= issue_valid;
            pending_is_st   <= issue_is_st;
            pending_dest_pr <= issue_dest_pr;
            pending_rob_tag <= issue_rob_tag;
            
            if pending_valid = '1' then
                cdb_valid   <= '1';
                cdb_tag     <= pending_dest_pr;
                cdb_rob_tag <= pending_rob_tag;
                
                if pending_is_st = '1' then
                    cdb_data <= (others => '0');
                else
                    cdb_data <= mem_data_in;
                end if;
            
            else
                cdb_valid <= '0';
            end if;
            
        end if;
        
    end process;
    
end Behavioral;