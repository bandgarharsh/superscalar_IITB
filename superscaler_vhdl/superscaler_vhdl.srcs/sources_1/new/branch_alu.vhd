----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.08.2026 21:00:54
-- Design Name: 
-- Module Name: branch_alu - Behavioral
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

entity branch_alu is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        
        issue_valid : in std_logic;
        issue_opcode : in std_logic_vector(3 downto 0);
        issue_pc : in std_logic_vector(15 downto 0);
        issue_imm : in std_logic_vector(15 downto 0);
        issue_vj : in std_logic_vector(15 downto 0);
        issue_vk : in std_logic_vector(15 downto 0);
        issue_dest_pr : in std_logic_vector(4 downto 0);
        issue_rob_tag : in std_logic_vector(4 downto 0);
        
        cdb_valid : out std_logic;
        cdb_tag : out std_logic_vector(4 downto 0);
        cdb_data : out std_logic_vector(15 downto 0);
        cdb_rob_tag : out std_logic_vector(4 downto 0);
        
        branch_taken : out std_logic;
        target_pc : out std_logic_vector(15 downto 0)
  );
end branch_alu;

architecture Behavioral of branch_alu is
    
    constant OP_BEQ : std_logic_vector(3 downto 0) := "1010";
    constant OP_BLT : std_logic_vector(3 downto 0) := "1011";
    constant OP_JAL : std_logic_vector(3 downto 0) := "1100";
    
begin
    
    process(clk, rst)
        variable v_target_pc : unsigned(15 downto 0);
        variable v_taken : std_logic;
    
    begin
        if rst = '1' then
            cdb_valid <= '0';
            cdb_tag <= (others => '0');
            cdb_data <= (others => '0');
            cdb_rob_tag <= (others => '0');
            branch_taken <= '0';
            target_pc <= (others => '0');
        
        elsif rising_edge(clk) then
            
            cdb_valid <= '0';
            
            if issue_valid = '1' then
                cdb_valid <= '1';
                cdb_tag <= issue_dest_pr;
                cdb_rob_tag <= issue_rob_tag;
                
                v_taken := '0';
                v_target_pc := unsigned(issue_pc) + unsigned(issue_imm);
                
                case issue_opcode is
                    
                    when OP_BEQ =>
                        if issue_vj = issue_vk then
                            v_taken := '1';
                        end if;
                        
                        cdb_data <= (others => '0');
                    
                    when OP_BLT =>
                        if signed(issue_vj) < signed(issue_vk) then
                            v_taken := '1';
                        end if;
                        cdb_data <= (others => '0');
                        
                    when OP_JAL => 
                        if signed(issue_vj) < signed(issue_vk) then
                            v_taken := '1';
                        end if;
                        
                        cdb_data <= (others => '0');
                    
                    when others =>
                        v_taken := '0';
                        cdb_data <= (others => '0');
                end case;
                
                branch_taken <= v_taken;
                
                if v_taken = '1' then
                    target_pc <= std_logic_vector(v_target_pc);
                else
                    target_pc <= std_logic_vector(unsigned(issue_pc) + 1);
                end if;
                
                
            end if;
        end if;
    end process;
                        
end Behavioral;
