library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; -- NEW: Clean Logging!
use work.iitb_risc_pkg.ALL; 

entity AGU is
    Port (
        clk             : in std_logic; 
        rst             : in std_logic;
        flush           : in std_logic; 
        
        issue_valid     : in std_logic;
        issue_is_store  : in std_logic;
        issue_packet    : in lsu_issue_packet_t; 
        
        agu_valid       : out std_logic;
        agu_is_store    : out std_logic;
        agu_addr        : out std_logic_vector(15 downto 0);
        agu_packet      : out lsu_issue_packet_t 
    );
end AGU;

architecture Behavioral of AGU is
begin
    process(rst, flush, issue_valid, issue_is_store, issue_packet)
        variable v_base : unsigned(15 downto 0);
        variable v_imm  : unsigned(15 downto 0);
        variable v_addr : unsigned(15 downto 0);
    begin
        agu_valid    <= '0';
        agu_is_store <= '0';
        agu_addr     <= (others => '0');
        agu_packet   <= issue_packet; 
        
        if rst = '1' or flush = '1' then
            agu_valid    <= '0';
        elsif issue_valid = '1' then
            v_base := unsigned(issue_packet.base_data);
            v_imm  := unsigned(issue_packet.imm);
            v_addr := v_base + v_imm;
            
            agu_valid    <= '1';
            agu_is_store <= issue_is_store;
            agu_addr     <= std_logic_vector(v_addr);
        end if;
    end process;

    -- =========================================================
    -- PROFESSIONAL X-RAY: AGU
    -- =========================================================
    process(clk)
        variable l : line;
        variable v_addr : unsigned(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '0' and flush = '0' and issue_valid = '1' then
                v_addr := unsigned(issue_packet.base_data) + unsigned(issue_packet.imm);
                write(l, string'("[AGU] Calculated Address: "));
                write(l, integer'image(to_integer(v_addr)));
                if issue_is_store = '1' then write(l, string'(" (STORE)")); else write(l, string'(" (LOAD)")); end if;
                write(l, string'(" | ROB ID: "));
                write(l, integer'image(to_integer(unsigned(issue_packet.rob_id))));
                writeline(output, l);
            end if;
        end if;
    end process;
end Behavioral;