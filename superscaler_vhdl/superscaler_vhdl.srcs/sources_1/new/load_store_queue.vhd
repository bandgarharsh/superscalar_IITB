----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.08.2026 19:24:55
-- Design Name: 
-- Module Name: load_store_queue - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity load_store_queue is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        flush : in std_logic;
        
        we1 : in std_logic;
        we2 : in std_logic;
        
        d1_is_store : in std_logic;
        d1_offset : in std_logic_vector(15 downto 0);
        d1_dest_pr : in std_logic_vector(4 downto 0);
        d1_rob_tag : in std_logic_vector(4 downto 0);
        d1_base_val : in std_logic;
        d1_base_data : in std_logic_vector(15 downto 0);
        d1_base_tag : in std_logic_vector(4 downto 0);
        d1_data_val : in std_logic;
        d1_data_data : in std_logic_vector(15 downto 0);
        d1_data_tag : in std_logic_vector(4 downto 0);
        
        d2_is_store : in std_logic;
        d2_offset : in std_logic_vector(15 downto 0);
        d2_dest_pr : in std_logic_vector(4 downto 0);
        d2_rob_tag : in std_logic_vector(4 downto 0);
        d2_base_val : in std_logic;
        d2_base_data : in std_logic_vector(15 downto 0);
        d2_base_tag : in std_logic_vector(4 downto 0);
        d2_data_val : in std_logic;
        d2_data_data : in std_logic_vector(15 downto 0);
        d2_data_tag : in std_logic_vector(4 downto 0);
        
        cdb1_valid : in std_logic;
        cdb1_tag : in std_logic_vector(4 downto 0);
        cdb1_data : in std_logic_vector(15 downto 0);
        
        cdb2_valid : in std_logic;
        cdb2_tag : in std_logic_vector(4 downto 0);
        cdb2_data : in std_logic_vector(15 downto 0);
        
        issue_valid : out std_logic;
        issue_is_st : out std_logic;
        issue_addr : out std_logic_vector(15 downto 0);
        issue_data : out std_logic_vector(15 downto 0);
        issue_dest : out std_logic_vector(4 downto 0);
        issue_rob : out std_logic_vector(4 downto 0);
        
        available_slots : out std_logic_vector(2 downto 0)
  );
end load_store_queue;

architecture Behavioral of load_store_queue is
    
    constant DEPTH : integer := 4;
    
    type bit_arr is array (0 to DEPTH-1) of std_logic;
    type data_arr is array (0 to DEPTH-1) of std_logic_vector(15 downto 0);
    type tag_arr is array (0 to DEPTH-1) of std_logic_vector(4 downto 0);
    
    signal valid : bit_arr := (others => '0');
    signal is_store : bit_arr := (others => '0');
    signal offset : data_arr := (others => (others => '0'));
    signal dest_pr : tag_arr := (others => (others => '0'));
    signal rob_tag : tag_arr := (others => (others => '0'));
    
    signal base_v_val : bit_arr := (others => '0');
    signal base_v : data_arr := (others => (others => '0'));
    signal base_q : tag_arr := (others => (others => '0'));
    
    signal data_v_val : bit_arr := (others => '0');
    signal data_v : data_arr := (others => (others => '0'));
    signal data_q : tag_arr := (others => (others => '0'));
    
    signal head : integer range 0 to DEPTH-1 := 0;
    signal tail : integer range 0 to DEPTH-1 := 0;
    signal count : integer range 0 to DEPTH-1 := 0;
    
    signal head_ready : std_logic;
    
begin


    available_slots <= std_logic_vector(to_unsigned(DEPTH - count, 3));
    
    head_Ready <= '1' when (valid(head) = '1' and
                            base_v_val(head) = '1' and
                            (is_store(head) = '0' or data_v_val(head) = '1'))
                      else '0';
                      
    issue_valid <= head_ready;
    issue_is_st <= is_store(head);
    
    issue_addr <= std_logic_vector(unsigned(base_v(head)) + unsigned(offset(head)));
    issue_data <= data_v(head);
    issue_dest <= dest_pr(head);
    issue_rob <= rob_tag(head);
    
    
    process(clk, rst, flush)
        variable next_count : integer range 0 to DEPTH+2;
        variable next_tail : integer range 0 to DEPTH-1;
        variable next_head : integer range 0 to DEPTH-1;
        variable pops : integer range 0 to 1;
        variable pushes : integer range 0 to 2;
    begin
        if rst = '1' or flush = '1' then
            head <= 0;
            tail <= 0;
            count <= 0;
            valid <= (others => '0');
        elsif rising_edge(clk) then
            
            pops := 0;
            pushes := 0;
            next_tail := tail;
            next_head := head;
            
            if head_ready = '1' then
                valid(head) <= '0';
                pops := 1;
                if head = DEPTH-1 then next_head := 0; else next_head := head + 1; end if;
            end if;
            
            if we1 = '1' then
                valid(next_tail) <= '1';
                is_store(next_tail) <= d1_is_store;
                offset(next_tail) <= d1_offset;
                dest_pr(next_tail) <= d1_dest_pr;
                rob_tag(next_tail) <= d1_rob_tag;
                base_v_val(next_tail) <= d1_base_val;
                base_v(next_tail) <= d1_base_data;
                base_q(next_tail) <= d1_base_tag;
                data_v_val(next_tail) <= d1_data_val;
                data_v(next_tail) <= d1_data_data;
                data_q(next_tail) <= d1_data_tag;
                
                pushes := pushes + 1;
                if next_tail = DEPTH-1 then next_tail := 0; else next_tail := next_tail + 1; end if;
            end if;
            
            if we2 = '1' then
                valid(next_tail) <= '1';
                is_store(next_tail) <= d2_is_store;
                offset(next_tail) <= d2_offset;
                dest_pr(next_tail) <= d2_dest_pr;
                rob_tag(next_tail) <= d2_rob_tag;
                base_v_val(next_tail) <= d2_base_val;
                base_v(next_tail) <= d2_base_data;
                base_q(next_tail) <= d2_base_tag;
                data_v_val(next_tail) <= d2_data_val;
                data_v(next_tail) <= d2_data_data;
                data_q(next_tail) <= d2_data_tag;
                
                pushes := pushes + 1;
                if next_tail = DEPTH-1 then next_tail := 0; else next_tail := next_tail + 1; end if;
            end if;
            
            
            head <= next_head;
            tail <= next_tail;
            count <= count + pushes - pops;
            
            for i in 0 to DEPTH-1 loop
                if valid(i) = '1' then
                    
                    if base_v_val(i) = '0' then
                        if cdb1_valid = '1' and base_q(i) = cdb1_tag then
                            base_v(i) <= cdb1_data;
                            base_v_val(i) <= '1'; 
                        elsif cdb2_valid = '1' and base_q(i) = cdb2_tag then
                            base_v(i) <= cdb2_data;
                            base_v_val(i) <= '1';       
                        end if;
                    end if;
                    
                    if is_store(i) = '1' and data_v_val(i) = '0' then
                        if cdb1_valid = '1' and base_q(i) = cdb1_tag then
                            data_v(i) <= cdb1_data;
                            data_v_val(i) <= '1'; 
                        elsif cdb2_valid = '1' and data_q(i) = cdb2_tag then
                            data_v(i) <= cdb2_data;
                            data_v_val(i) <= '1';       
                        end if;
                    end if;
                    
                    
                end if;
            end loop;
        end if; 
    end process;
end Behavioral;
