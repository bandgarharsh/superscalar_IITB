----------------------------------------------------------------------------------
-- Module Name: execution_alu - Behavioral
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity execution_alu is
  Port ( 
    clk : in std_logic;
    rst : in std_logic;
    
    issue_valid   : in std_logic;
    issue_opcode  : in std_logic_vector(3 downto 0);
    issue_comp    : in std_logic;
    issue_cz      : in std_logic_vector(1 downto 0);
    issue_imm     : in std_logic_vector(15 downto 0); -- NEW: Immediate input
    issue_vj      : in std_logic_vector(15 downto 0);
    issue_vk      : in std_logic_vector(15 downto 0);
    issue_dest_pr : in std_logic_vector(4 downto 0);
    issue_rob_tag : in std_logic_vector(2 downto 0);  -- CHANGED: 3-bit tag
    
    cdb_valid   : out std_logic;
    cdb_tag     : out std_logic_vector(4 downto 0);
    cdb_data    : out std_logic_vector(15 downto 0);
    cdb_rob_tag : out std_logic_vector(2 downto 0);   -- CHANGED: 3-bit tag
    
    cdb_c_flag : out std_logic;
    cdb_z_flag : out std_logic
  );
end execution_alu;

architecture Behavioral of execution_alu is
    
    -- FIXED: Aligned with ISA definitions
    constant OP_ADI  : std_logic_vector(3 downto 0) := "0000"; 
    constant OP_ADD  : std_logic_vector(3 downto 0) := "0001"; 
    constant OP_NAND : std_logic_vector(3 downto 0) := "0010";
    constant OP_LHI  : std_logic_vector(3 downto 0) := "0011";
    
    signal op2_mux  : std_logic_vector(15 downto 0);
    signal carry_in : unsigned(0 downto 0);
    
begin

    op2_mux <= not issue_vk when issue_comp = '1' else issue_vk;
    carry_in <= "1" when issue_comp = '1' else "0";
    
    process(clk ,rst)
        variable math_result : unsigned(16 downto 0);
        variable nand_result : std_logic_vector(15 downto 0);
    begin
        if rst = '1' then
            cdb_valid   <= '0';
            cdb_tag     <= (others => '0');
            cdb_data    <= (others => '0');
            cdb_rob_tag <= (others => '0');
            cdb_c_flag  <= '0';
            cdb_z_flag  <= '0';
        
        elsif rising_edge(clk) then
        
            cdb_valid <= '0';
            
            if issue_valid = '1' then
                
                cdb_valid   <= '1';
                cdb_tag     <= issue_dest_pr;
                cdb_rob_tag <= issue_rob_tag;
                
                case issue_opcode is
                    
                    when OP_ADI =>
                        -- ADI utilizes the immediate
                        math_result := unsigned("0" & issue_vj) + unsigned("0" & issue_imm) + carry_in;
                        
                        cdb_data   <= std_logic_vector(math_result(15 downto 0));
                        cdb_c_flag <= math_result(16);
                        
                        if (math_result(15 downto 0) = x"0000") then
                            cdb_z_flag <= '1';
                        else 
                            cdb_z_flag <= '0';
                        end if;

                    when OP_ADD =>
                        math_result := unsigned("0" & issue_vj) + unsigned("0" & op2_mux) + carry_in;
                        
                        cdb_data   <= std_logic_vector(math_result(15 downto 0));
                        cdb_c_flag <= math_result(16);
                        
                        if (math_result(15 downto 0) = x"0000") then
                            cdb_z_flag <= '1';
                        else 
                            cdb_z_flag <= '0';
                        end if;
                    
                    when OP_NAND =>
                        -- FIXED: Calculate result first, then strictly check the output for the Z flag
                        nand_result := not (issue_vj and op2_mux);
                        
                        cdb_data   <= nand_result;
                        cdb_c_flag <= '0';
                        
                        if (nand_result = x"0000") then
                            cdb_z_flag <= '1';
                        else 
                            cdb_z_flag <= '0';
                        end if;
                        
                    when OP_LHI =>
                        -- FIXED: Explicitly draw from issue_imm instead of issue_vk
                        cdb_data   <= issue_imm(7 downto 0) & x"00";
                        cdb_c_flag <= '0';
                        cdb_z_flag <= '0';
                    
                    when others =>
                        cdb_data   <= issue_vk;
                        cdb_c_flag <= '0';
                        cdb_z_flag <= '0';
                    
                end case;
            end if;
        end if;
    end process;
                
end Behavioral;