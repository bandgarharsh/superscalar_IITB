----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.08.2026 21:24:30
-- Design Name: 
-- Module Name: reorder_buffer - Behavioral
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

entity reorder_buffer is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        
        we1 : in std_logic;
        d1_arch_reg : in std_logic_vector(2 downto 0);
        d1_phys_reg : in std_logic_vector(4 downto 0);
        d1_is_store : in std_logic;
        d1_is_branch : in std_logic;
        out_rob_tag1 : out std_logic_vector(4 downto 0);
        
        we2 : in std_logic;
        d2_arch_reg : in std_logic_vector(2 downto 0);
        d2_phys_reg : in std_logic_vector(4 downto 0);
        d2_is_store : in std_logic;
        d2_is_branch : in std_logic;
        out_rob_tag2 : out std_logic_vector(4 downto 0);
        
        cdb1_valid : in std_logic;
        cdb1_rob_tag : in std_logic_vector(4 downto 0);
        cdb1_mispredict : in std_logic;
        cdb1_target_pc : in std_logic_vector(15 downto 0);
        
        cdb2_valid : in std_logic;
        cdb2_rob_tag : in std_logic_vector(4 downto 0);
        cdb2_mispredict : in std_logic;
        cdb2_target_pc : in std_logic_vector(15 downto 0);
        
        retire1_valid : out std_logic;
        retire1_arch_reg : out std_logic_vector(2 downto 0);
        retire1_phys_reg : out std_logic_vector(4 downto 0);
        retire1_is_store : out std_logic;
        
        retire2_valid : out std_logic;
        retire2_arch_reg : out std_logic_vector(2 downto 0);
        retire2_phys_reg : out std_logic_vector(4 downto 0);
        retire2_is_store : out std_logic;
        
        flush_pipeline : out std_logic;
        flush_pc : out std_logic_vector(15 downto 0);
        rob_full : out std_logic
  );
end reorder_buffer;

architecture Behavioral of reorder_buffer is
    
    constant DEPTH : integer := 8;
    
    type bit_arr is array (0 to DEPTH-1) of std_logic;
    type arch_arr is array (0 to DEPTH-1) of std_logic_vector(2 downto 0);
    type phys_arr is array (0 to DEPTH-1) of std_logic_vector(4 downto 0);
    type pc_arr is array (0 to DEPTH-1) of std_logic_vector(15 downto 0);
    
    signal valid : bit_arr := (others => '0');
    signal done : bit_arr := (others => '0');
    signal arch_reg : arch_arr := (others => (others => '0'));
    signal phys_reg : phys_arr := (others => (others => '0'));
    signal is_store : bit_arr := (others => '0');
    signal is_branch : bit_arr := (others => '0');
    signal mispredict : bit_arr := (others => '0');
    signal target_pc : pc_arr := (others => (others => '0'));
    
    signal head : integer range 0 to DEPTH-1 := 0;
    signal tail : integer range 0 to DEPTH-1 := 0;
    signal count : integer range 0 to DEPTH := 0;
    
begin
    
    out_rob_tag1 <= std_logic_vector(to_unsigned(tail,5));
    out_rob_tag2 <= std_logic_vector(to_unsigned((tail+1) mod DEPTH, 5));
    
    
    rob_full <= '1' when (DEPTH - count) < 2 else '0';
    
    process(clk, rst)
    
        variable next_head : integer range 0 to DEPTH-1;
        variable next_tail : integer range 0 to DEPTH-1;
        variable pops : integer range 0 to 2;
        variable pushes : integer range 0 to 2;
        variable head_plus1 : integer range 0 to DEPTH-1;
    
    begin
        if rst = '1' then
            head <= 0;
            tail <= 0;
            count <= 0;
            valid <= (others => '0');
            flush_pipeline <= '0';
       
        elsif rising_edge(clk) then
            
            pops := 0;
            pushes := 0;
            next_head := head;
            next_tail := tail;
            head_plus1 := (head + 1) mod DEPTH;
            flush_pipeline <= '0';
            
            retire1_valid <= '0';
            retire2_valid <= '0';
            
            
            if valid(head) = '1' and done(head) = '1' then
                
                if is_branch(head) = '1' and mispredict(head) = '1' then
                    flush_pipeline <= '1';
                    flush_pc <= target_pc(head);
                    
                    valid <= (others => '0');
                    head <= 0;
                    tail <= 0;
                    count <= 0;
                
                else
                    
                    retire1_valid <= '1';
                    retire1_arch_reg <= arch_reg(head);
                    retire1_phys_reg <= phys_reg(head);
                    retire1_is_store <= is_store(head);
                    valid(head) <= '0';
                    pops := 1;
                    next_head := head_plus1;
                    
                    if valid(head_plus1) = '1' and done(head_plus1) = '1' then
                        if is_branch(head_plus1) = '1' and mispredict(head_plus1) = '1' then
                            -- Let it fault on the NEXT cycle, don't retire it now
                            null;
                        
                        else
                            
                            retire2_valid <= '1';
                            retire2_arch_reg <= arch_reg(head_plus1);
                            retire2_phys_reg <= phys_reg(head_plus1);
                            retire2_is_store <= is_store(head_plus1);
                            valid(head_plus1) <= '0';
                            pops := 2;
                            next_head := (head + 2) mod DEPTH;
                            
                            
                        end if;
                    end if;
                end if;
            end if;
            
            if flush_pipeline = '0' then
                
                if we1 = '1' then
                    valid(next_tail) <= '1';
                    done(next_tail) <= '0';
                    arch_reg(next_tail) <= d1_arch_reg;
                    phys_reg(next_tail) <= d1_phys_reg;
                    is_store(next_tail) <= d1_is_store;
                    is_branch(next_tail) <= d1_is_branch;
                    
                    pushes := pushes + 1;
                    next_tail := (next_tail + 1) mod DEPTH;
                
                end if;
                
                if we2 = '1' then
                    valid(next_tail) <= '1';
                    done(next_tail) <= '0';
                    arch_reg(next_tail) <= d2_arch_reg;
                    phys_reg(next_tail) <= d2_phys_reg;
                    is_store(next_tail) <= d2_is_store;
                    is_branch(next_tail) <= d2_is_branch;
                    
                    pushes := pushes + 1;
                    next_tail := (next_tail + 1) mod DEPTH;
                
                end if;
                
                head <= next_head;
                tail <= next_tail;
                count <= count + pushes - pops;
            
            end if;
            
            
            if cdb1_valid = '1' then
                done(to_integer(unsigned(cdb1_rob_tag))) <= '1';
                mispredict(to_integer(unsigned(cdb1_rob_tag))) <= cdb1_mispredict;
                target_pc(to_integer(unsigned(cdb1_rob_tag))) <= cdb1_target_pc;
            end if;
            
            if cdb2_valid = '1' then
                done(to_integer(unsigned(cdb2_rob_tag))) <= '1';
                mispredict(to_integer(unsigned(cdb2_rob_tag))) <= cdb2_mispredict;
                target_pc(to_integer(unsigned(cdb2_rob_tag))) <= cdb2_target_pc;
            end if;
                
        end if;
    
    end process;             
                    
end Behavioral;
