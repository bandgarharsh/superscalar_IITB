library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL; 

entity AGU is
    Port (
        clk             : in std_logic; -- Kept ONLY for the X-Ray!
        rst             : in std_logic;
        flush           : in std_logic; 
        
        -- ==========================================
        -- INPUTS: From RS_LSU
        -- ==========================================
        issue_valid     : in std_logic;
        issue_is_store  : in std_logic;
        issue_packet    : in lsu_issue_packet_t; 
        
        -- ==========================================
        -- OUTPUTS: To Load Queue (LQ) & Store Queue (SQ)
        -- ==========================================
        agu_valid       : out std_logic;
        agu_is_store    : out std_logic;
        agu_addr        : out std_logic_vector(15 downto 0);
        agu_packet      : out lsu_issue_packet_t 
    );
end AGU;

architecture Behavioral of AGU is
begin

    -- =========================================================
    -- PURE COMBINATIONAL DATA PATH (Instant Address Math!)
    -- =========================================================
    process(rst, flush, issue_valid, issue_is_store, issue_packet)
        variable v_base : unsigned(15 downto 0);
        variable v_imm  : unsigned(15 downto 0);
        variable v_addr : unsigned(15 downto 0);
    begin
        -- Default assignments to prevent phantom latches
        agu_valid    <= '0';
        agu_is_store <= '0';
        agu_addr     <= (others => '0');
        agu_packet   <= issue_packet; -- Just pass the wires straight through
        
        if rst = '1' or flush = '1' then
            agu_valid    <= '0';
            agu_is_store <= '0';
            agu_addr     <= (others => '0');
        else
            if issue_valid = '1' then
                
                -- Extract directly from the new packet
                v_base := unsigned(issue_packet.base_data);
                v_imm  := unsigned(issue_packet.imm);
                
                -- The Instant AGU Math
                v_addr := v_base + v_imm;
                
                -- Pass instantly to LQ/SQ
                agu_valid    <= '1';
                agu_is_store <= issue_is_store;
                agu_addr     <= std_logic_vector(v_addr);
                
            end if;
        end if;
    end process;

    -- =========================================================
    -- PURE CLOCKED X-RAY PROBE (Doesn't delay the data!)
    -- =========================================================
    process(clk)
        variable v_base : unsigned(15 downto 0);
        variable v_imm  : unsigned(15 downto 0);
        variable v_addr : unsigned(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '0' and flush = '0' and issue_valid = '1' then
                v_base := unsigned(issue_packet.base_data);
                v_imm  := unsigned(issue_packet.imm);
                v_addr := v_base + v_imm;

                report "[X-RAY AGU] PC: " & integer'image(to_integer(unsigned(issue_packet.pc))) &
                       " | BASE: " & integer'image(to_integer(v_base)) &
                       " | IMM: " & integer'image(to_integer(v_imm)) &
                       " | CALC_ADDR: " & integer'image(to_integer(v_addr)) &
                       " | IS_STORE: " & std_logic'image(issue_is_store);
            end if;
        end if;
    end process;

end Behavioral;