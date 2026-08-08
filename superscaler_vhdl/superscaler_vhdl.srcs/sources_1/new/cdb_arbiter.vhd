----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.08.2026 11:41:27
-- Design Name: 
-- Module Name: cdb_arbiter - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity cdb_arbiter is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        
        alu1_valid : in std_logic;
        alu1_tag : in std_logic_vector(4 downto 0);
        alu1_data : in std_logic_vector(15 downto 0);
        alu1_rob_tag : in std_logic_vector(4 downto 0);
        
        alu2_valid : in std_logic;
        alu2_tag : in std_logic_vector(4 downto 0);
        alu2_data : in std_logic_vector(15 downto 0);
        alu2_rob_tag : in std_logic_vector(4 downto 0);
        
        alu3_valid : in std_logic;
        alu3_tag : in std_logic_vector(4 downto 0);
        alu3_data : in std_logic_vector(15 downto 0);
        alu3_rob_tag : in std_logic_vector(4 downto 0);
        
        alu3_mispredict : in std_logic;
        alu3_target_pc : in std_logic_vector(15 downto 0); 
        
        cdb1_valid : out std_logic;
        cdb1_tag : out std_logic_vector(4 downto 0);
        cdb1_data : out std_logic_vector(15 downto 0);
        cdb1_rob_tag : out std_logic_vector(4 downto 0);
        cdb1_mispredict : out std_logic;
        cdb1_target_pc : out std_logic_vector(15 downto 0);
        
        cdb2_valid : out std_logic;
        cdb2_tag : out std_logic_vector(4 downto 0);
        cdb2_data : out std_logic_vector(15 downto 0);
        cdb2_rob_tag : out std_logic_vector(4 downto 0);
        cdb2_mispredict : out std_logic;
        cdb2_target_pc : out std_logic_vector(15 downto 0)
         
    );
end cdb_arbiter;

architecture Behavioral of cdb_arbiter is

    signal buf_valid : std_logic := '0';
    signal buf_tag : std_logic_vector(4 downto 0) := (others => '0');
    signal buf_data : std_logic_vector(15 downto 0) := (others => '0');
    signal buf_rob_tag : std_logic_vector(4 downto 0) := (others => '0');
    
    signal cdb1_tag_s : std_logic_vector(4 downto 0) := (others => '0');
    signal cdb1_data_s : std_logic_vector(15 downto 0) := (others => '0');
    signal cdb1_rob_tag_s : std_logic_vector(4 downto 0) := (others => '0');
    signal cdb2_tag_s : std_logic_vector(4 downto 0) := (others => '0');
    signal cdb2_data_s : std_logic_vector(15 downto 0) := (others => '0');
    signal cdb2_rob_tag_s : std_logic_vector(4 downto 0) := (others => '0');
    
begin

    cdb1_tag     <= cdb1_tag_s;
    cdb1_data    <= cdb1_data_s;
    cdb1_rob_tag <= cdb1_rob_tag_s;
    
    cdb2_tag     <= cdb2_tag_s;
    cdb2_data    <= cdb2_data_s;
    cdb2_rob_tag <= cdb2_rob_tag_s;
    
    process(clk, rst)
        variable active_count : integer range 0 to 4;
        
        
    begin

        
        if rst = '1' then
            buf_valid <= '0';
            cdb1_valid <= '0';
            cdb2_valid <= '0';
        
        elsif rising_edge(clk) then
            
            cdb1_valid <= '0';
            cdb2_valid <= '0';
            cdb1_mispredict <= '0';
            cdb2_mispredict <= '0';
            
            active_count := 0;
            
            if buf_valid = '1' then
                
                cdb1_valid <= '1';
                cdb1_tag_s <= buf_tag;
                cdb1_data_s <= buf_data;
                cdb1_rob_Tag_s <= buf_rob_tag;
                buf_valid <= '0';
                active_count := 1;
            
            elsif alu3_valid = '1' then
                
                cdb1_valid <= '1';
                cdb1_tag_s <= alu3_tag;
                cdb1_data_s <= alu3_data;
                cdb1_rob_Tag_s <= alu3_rob_tag;
                cdb1_mispredict <= alu3_mispredict;
                cdb1_target_pc <= alu3_target_pc;
                active_count := 1;
                
            elsif alu2_valid = '1' then
                
                cdb1_valid <= '1';
                cdb1_tag_s <= alu2_tag;
                cdb1_data_s <= alu2_data;
                cdb1_rob_tag_s <= alu2_rob_tag;
                active_count := 1;
                
                
            elsif alu1_valid = '1' then
                
                cdb1_valid <= '1';
                cdb1_tag_s <= alu1_tag;
                cdb1_data_s <= alu1_data;
                cdb1_rob_tag_s <= alu1_rob_tag;
                active_count := 1;
            
            end if;
            
            if active_count = 1 then
                
                if buf_valid = '1' and alu3_valid = '1' then
                    
                    cdb2_valid <= '1';
                    cdb2_tag_s <= alu3_tag;
                    cdb2_data_s <= alu3_data;
                    cdb2_rob_tag_s <= alu3_rob_tag;
                    cdb2_mispredict <= alu3_mispredict;
                    cdb2_target_pc <= alu3_target_pc;
                    active_count := 2;
                    
                elsif alu2_valid = '1' and (cdb1_tag_s /= alu2_tag) then
                    
                    cdb2_valid <= '1';
                    cdb2_tag_s <= alu2_tag;
                    cdb2_data_s <= alu2_data;
                    cdb2_rob_tag_s <= alu2_rob_tag;
                    active_count := 2;
                    
                    
                elsif alu1_valid = '1' and (cdb1_tag_s /= alu1_tag) then
                    
                    cdb2_valid <= '1';
                    cdb2_tag_s <= alu1_tag;
                    cdb2_data_s <= alu1_data;
                    cdb2_rob_tag_s <= alu1_rob_tag;
                    active_count := 2;
                
                end if;
            end if;  
            
            if active_count = 2 then
                
                if alu2_valid = '1' and  (cdb1_tag_s /= alu2_tag) and (cdb2_tag_s /= alu2_tag) then
                    buf_valid <= '1';
                    buf_tag <= alu2_tag;
                    buf_data <= alu2_data;
                    buf_rob_tag <= alu2_rob_tag;
                
                elsif alu1_valid = '1' and (cdb1_tag_s /= alu1_tag) and (cdb2_tag_s /= alu1_tag) then
                
                    buf_valid <= '1';
                    buf_tag <= alu1_tag;
                    buf_data <= alu1_data;
                    buf_rob_tag <= alu1_rob_tag;
                    
                end if;
                
            end if;
            
        end if;
    end process;          
end Behavioral;
