----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04.08.2026 21:22:04
-- Design Name: 
-- Module Name: micro_op_cracker - Behavioral
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

entity micro_op_cracker is
  Port (
    clk : in std_logic;
    rst : in std_logic;
    
    valid_in : in std_logic;
    instr_in : in std_logic_vector(15 downto 0);
    pc_in : in std_logic_vector(15 downto 0);
    
    stall_fetch : out std_logic;
    
    uop1_valid : out std_logic;
    uop1_opcode : out std_logic_vector(3 downto 0);
    uop1_base_reg : out std_logic_vector(2 downto 0);
    uop1_target_reg : out std_logic_vector(3 downto 0);
    uop1_offset : out std_logic_vector(15 downto 0);
    uop1_pc : out std_logic_vector(15 downto 0);
    
    uop2_valid : out std_logic;
    uop2_opcode : out std_logic_vector(3 downto 0);
    uop2_base_reg : out std_logic_vector(2 downto 0);
    uop2_target_reg : out std_logic_vector(3 downto 0);
    uop2_offset : out std_logic_vector(15 downto 0);
    uop2_pc : out std_logic_vector(15 downto 0)
    
);
end micro_op_cracker;

architecture Behavioral of micro_op_cracker is

    constant OP_LW: std_logic_vector(3 downto 0) := "0100";
    constant OP_SW: std_logic_vector(3 downto 0) := "0101";
    constant OP_LM: std_logic_vector(3 downto 0) := "0110";
    constant OP_SM: std_logic_vector(3 downto 0) := "0111";
    constant OP_LMF: std_logic_vector(3 downto 0) := "1000";
    constant OP_SMF: std_logic_vector(3 downto 0) := "1001";
    
    constant REG_FLAGS : std_logic_vector(3 downto 0) := "1000";
    
    
    signal is_cracking : std_logic := '1';
    signal stored_base : std_logic_vector(2 downto 0);
    signal stored_mask : std_logic_vector(7 downto 0);
    signal stored_opcode : std_logic_vector(3 downto 0);
    signal stored_pc : std_logic_vector(15 downto 0);
    signal current_offset : unsigned(15 downto 0);
    signal handle_flags :std_logic := '0';
    
    
begin

    process(clk, rst)
        variable found_count : integer range 0 to 2;
        variable temp_mask : std_logic_vector(7 downto 0);
        variable reg_idx1 : integer range 0 to 7;
        variable reg_idx2 : integer range 0 to 7;
        
        variable incoming_op : std_logic_vector(3 downto 0);

    begin
        if rst = '1' then
            is_cracking <= '0';
            stall_fetch <= '0';
            handle_flags <= '0';
            uop1_valid <= '0';
            uop2_valid <= '0';
            current_offset <= (others => '0');
        elsif rising_edge(clk) then
        
            uop1_valid <= '0';
            uop2_valid <= '0';
            
            if is_cracking = '1' then
                stall_fetch <= '1';
                
                found_count := 0;
                temp_mask := stored_mask;
                
                if handle_flags = '1' then
                    uop1_valid <= '1';
                    uop2_opcode <= stored_opcode;
                    uop1_base_reg <= stored_base;
                    uop1_target_reg <= REG_FLAGS;
                    uop1_offset <= std_logic_vector(current_offset);
                    uop1_pc <= stored_pc;
                    
                    handle_flags <= '0';
                    found_count := 1;
                end if;
                
                for i in 0 to 7 loop
                    if temp_mask(i) = '1' then
                        if found_count = 0 then
                        
                            reg_idx1 := 7-i;
                            uop1_valid <= '1';
                            uop1_opcode <= stored_opcode;
                            uop1_base_reg <= stored_base;
                            uop1_target_reg <= '0' & std_logic_vector(to_unsigned(reg_idx1, 3));
                            uop1_offset <= std_logic_vector(current_offset);
                            uop1_pc <= stored_pc;
                        
                            temp_mask(i) := '0';
                            found_count := 1;
                        
                        elsif found_count = 1 then
                            reg_idx1 := 7-i;
                            uop2_valid <= '1';
                            uop2_opcode <= stored_opcode;
                            uop2_base_reg <= stored_base;
                            uop2_target_reg <= '0' & std_logic_vector(to_unsigned(reg_idx2, 3));
                            uop2_offset <= std_logic_vector(current_offset + 1);
                            uop2_pc <= stored_pc;
                            
                            temp_mask(i) := '0';
                            found_count := 2;
                            exit;
                        end if;
                    
                    end if;
                    
                end loop;
                
                stored_mask <= temp_mask;
                current_offset <= current_offset + found_count;
                
                if temp_mask = "00000000" and handle_flags = '0' then
                    is_cracking <= '0';
                    stall_fetch <= '0';
                end if;
            
            
            else
                if valid_in = '1' then
                    
                    incoming_op := instr_in(15 downto 0);
                    
                    if (incoming_op = OP_LM or incoming_op = OP_SM or incoming_op = OP_LMF or incoming_op = OP_SMF ) then
                        
                        is_Cracking <= '1';
                        stall_fetch <= '1';
                        stored_base <= instr_in(11 downto 0);
                        stored_mask <= instr_in(7 downto 0);
                        stored_pc <= pc_in;
                        current_offset <= (others => '0');
                        
                        
                        if incoming_op = OP_LM or incoming_op = OP_LMF then
                            stored_opcode <= OP_LW;
                        else
                            stored_opcode <= OP_SW;
                        end if;
                        
                        if incoming_op = OP_LMF or incoming_op = OP_SMF then
                            handle_flags <= '1';
                        else
                            handle_flags <= '0';
                        end if;
                        
                    end if;
                end if;
            end if;
            
            
        end if;
        
        
    end process;      
                    

end Behavioral;
