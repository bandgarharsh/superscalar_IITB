library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity arithmetic_rs is
    Port (
        clk         : in std_logic;
        rst         : in std_logic;
        flush       : in std_logic;

        -- --- 1. DISPATCH INTERFACE (Writing to RS) ---
        we1          : in std_logic;
        alloc_idx1   : in std_logic_vector(1 downto 0);
        d1_opcode    : in std_logic_vector(3 downto 0);
        d1_comp      : in std_logic;
        d1_cz        : in std_logic_vector(1 downto 0);
        d1_dest_pr   : in std_logic_vector(4 downto 0);
        d1_rob_tag   : in std_logic_vector(4 downto 0);

        -- Operand 1 (RA)
        d1_vj_valid  : in std_logic;
        d1_vj_data   : in std_logic_vector(15 downto 0);
        d1_qj_tag    : in std_logic_vector(4 downto 0);

        -- Operand 2 (RB or Immediate)
        d1_vk_valid  : in std_logic;
        d1_vk_data   : in std_logic_vector(15 downto 0);
        d1_qk_tag    : in std_logic_vector(4 downto 0);
        
        -- --- 1. DISPATCH INTERFACE (Writing to RS) ---
        we2          : in std_logic;
        alloc_idx2   : in std_logic_vector(1 downto 0);
        d2_opcode    : in std_logic_vector(3 downto 0);
        d2_comp      : in std_logic;
        d2_cz        : in std_logic_vector(1 downto 0);
        d2_dest_pr   : in std_logic_vector(4 downto 0);
        d2_rob_tag   : in std_logic_vector(4 downto 0);

        -- Operand 1 (RA)
        d2_vj_valid  : in std_logic;
        d2_vj_data   : in std_logic_vector(15 downto 0);
        d2_qj_tag    : in std_logic_vector(4 downto 0);

        -- Operand 2 (RB or Immediate)
        d2_vk_valid  : in std_logic;
        d2_vk_data   : in std_logic_vector(15 downto 0);
        d2_qk_tag    : in std_logic_vector(4 downto 0);

        -- --- 2. COMMON DATA BUS INTERFACE (Snooping) ---
        -- CDB Port 1
        cdb1_valid  : in std_logic;
        cdb1_tag    : in std_logic_vector(4 downto 0);
        cdb1_data   : in std_logic_vector(15 downto 0);

        -- CDB Port 2
        cdb2_valid  : in std_logic;
        cdb2_tag    : in std_logic_vector(4 downto 0);
        cdb2_data   : in std_logic_vector(15 downto 0);

        -- --- 3. ISSUE INTERFACE (To ALU) ---
        issue_valid   : out std_logic;
        issue_opcode  : out std_logic_vector(3 downto 0);
        issue_comp    : out std_logic;
        issue_cz      : out std_logic_vector(1 downto 0);
        issue_vj      : out std_logic_vector(15 downto 0);
        issue_vk      : out std_logic_vector(15 downto 0);
        issue_dest_pr : out std_logic_vector(4 downto 0);
        issue_rob_tag : out std_logic_vector(4 downto 0);

        -- Status to Dispatcher
        busy_slots    : out std_logic_vector(3 downto 0)
    );
end arithmetic_rs;

architecture Behavioral of arithmetic_rs is
    type bit_array is array (0 to 3) of std_logic;
    type opcode_array is array (0 to 3) of std_logic_vector(3 downto 0);
    type cz_array is array (0 to 3) of std_logic_vector(1 downto 0);
    type tag_array is array (0 to 3) of std_logic_vector(4 downto 0);
    type data_array is array (0 to 3) of std_logic_vector(15 downto 0);
    
    signal busy : bit_array := (others => '0');
    signal opcode : opcode_array := (others => (others => '0'));
    signal comp : bit_array := (others => '0');
    signal cz : cz_array := (others => (others => '0'));
    signal dest_pr : tag_array := (others => (others => '0'));
    signal rob_tag : tag_array := (others => (others => '0'));
    
    signal vj_valid : bit_array := (others => '0'); 
    signal vj : data_array := (others => (others => '0'));
    signal qj : tag_array := (others => (others => '0'));
    
    signal vk_valid : bit_array := (others => '0'); 
    signal vk : data_array := (others => (others => '0'));
    signal qk : tag_array := (others => (others => '0'));
    
    signal ready : bit_array;
    signal int_issue_v : std_logic;
    signal int_issue_i : integer range 0 to 3;
    
begin

    busy_slots <= busy(3) & busy(2) & busy(1) & busy(0);
    
    ready(0) <= busy(0) and vj_valid(0) and vk_valid(0);
    ready(1) <= busy(1) and vj_valid(1) and vk_valid(1);
    ready(2) <= busy(2) and vj_valid(2) and vk_valid(2);
    ready(3) <= busy(3) and vj_valid(3) and vk_valid(3);
    
    process(ready, opcode, comp, cz, vj, vk, dest_pr, rob_tag)
    begin
        
        int_issue_v <= '0';
        int_issue_i <= 0;
        issue_valid <= '0';
        issue_opcode <= (others => '0');
        issue_comp <= '0';
        issue_cz <= (others => '0');
        issue_vj <= (others => '0');
        issue_vk <= (others => '0');
        issue_dest_pr <= (others => '0');
        issue_rob_tag <= (others => '0');
        
        if(ready(0) = '1') then
            int_issue_v <= '1'; int_issue_i <=0; issue_valid <= '1';
            issue_opcode <= opcode(0); issue_comp <= comp(0);issue_cz <= cz(0);
            issue_vj <= vj(0); issue_vk <= vk(0); issue_dest_pr <= dest_pr(0);issue_rob_tag<= rob_tag(0);
        elsif (ready(1) = '1') then
            int_issue_v <= '1'; int_issue_i <=1; issue_valid <= '1';
            issue_opcode <= opcode(1); issue_comp <= comp(1);issue_cz <= cz(1);
            issue_vj <= vj(1); issue_vk <= vk(1); issue_dest_pr <= dest_pr(1);issue_rob_tag<= rob_tag(1);
        elsif (ready(2) = '1') then
            int_issue_v <= '1'; int_issue_i <=2; issue_valid <= '1';
            issue_opcode <= opcode(2); issue_comp <= comp(2);issue_cz <= cz(2);
            issue_vj <= vj(2); issue_vk <= vk(2); issue_dest_pr <= dest_pr(2);issue_rob_tag<= rob_tag(2);
        elsif (ready(3) = '1') then
            int_issue_v <= '1'; int_issue_i <=3; issue_valid <= '1';
            issue_opcode <= opcode(3); issue_comp <= comp(3);issue_cz <= cz(3);
            issue_vj <= vj(3); issue_vk <= vk(3); issue_dest_pr <= dest_pr(3);issue_rob_tag<= rob_tag(3);
        end if;
     end process;
     
     process(clk, rst, flush)
        variable a_idx1 : integer range 0 to 3;
        variable a_idx2 : integer range 0 to 3;
     begin
        if(rst = '1' or flush = '1') then
            busy <= (others => '0');
        elsif rising_edge(clk) then 
            a_idx1 := to_integer(unsigned(alloc_idx1));
            a_idx2 := to_integer(unsigned(alloc_idx2));
            
            if(int_issue_v = '1') then
                busy(int_issue_i) <= '0';
            end if;
            
            if (we1 = '1') then
                busy(a_idx1) <= '1';
                opcode(a_idx1) <= d1_opcode;
                comp(a_idx1) <= d1_comp;
                cz(a_idx1) <= d1_cz;
                dest_pr(a_idx1) <= d1_dest_pr;
                rob_tag(a_idx1) <= d1_rob_tag;
                
                vj_valid(a_idx1) <= d1_vj_valid;
                vj(a_idx1) <= d1_vj_data;
                qj(a_idx1) <= d1_qj_tag;
                
                vk_valid(a_idx1) <= d1_vk_valid;
                vk(a_idx1) <= d1_vk_data;
                qk(a_idx1) <= d1_qk_tag;
            end if;
            
            if (we2 = '1') then
                busy(a_idx2) <= '1';
                opcode(a_idx2) <= d2_opcode;
                comp(a_idx2) <= d2_comp;
                cz(a_idx2) <= d2_cz;
                dest_pr(a_idx2) <= d2_dest_pr;
                rob_tag(a_idx2) <= d2_rob_tag;
                
                vj_valid(a_idx2) <= d2_vj_valid;
                vj(a_idx2) <= d2_vj_data;
                qj(a_idx2) <= d2_qj_tag;
                
                vk_valid(a_idx2) <= d2_vk_valid;
                vk(a_idx2) <= d2_vk_data;
                qk(a_idx2) <= d2_qk_tag;
            end if;
            
            for i in 0 to 3 loop
                if(busy(i) = '1') then
                    
                    if(vj_valid(i) = '0') then
                        if(cdb1_valid = '1' and qj(i) = cdb1_tag) then
                            vj(i) <= cdb1_data;
                            vj_valid(i) <= '1';
                        elsif(cdb2_valid = '1' and qj(i) = cdb2_tag) then
                            vj(i) <= cdb2_data;
                            vj_valid(i) <= '1';
                        end if;
                    end if;
                    
                    if(vk_valid(i) = '0') then
                        if(cdb1_valid = '1' and qk(i) = cdb1_tag) then
                            vk(i) <= cdb1_data;
                            vk_valid(i) <= '1';
                        elsif(cdb2_valid = '1' and qk(i) = cdb2_tag) then
                            vk(i) <= cdb2_data;
                            vk_valid(i) <= '1';
                        end if;
                    end if;
                    
                end if;
                
            end loop;
        end if;
        
    end process;
                
            
end Behavioral;