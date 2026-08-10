library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity branch_alu is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        
        issue_valid   : in std_logic;
        issue_opcode  : in std_logic_vector(3 downto 0);
        issue_pc      : in std_logic_vector(15 downto 0);
        issue_imm     : in std_logic_vector(15 downto 0);
        issue_vj      : in std_logic_vector(15 downto 0);
        issue_vk      : in std_logic_vector(15 downto 0);
        issue_dest_pr : in std_logic_vector(4 downto 0);
        issue_rob_tag : in std_logic_vector(2 downto 0); -- 7. CHANGED: 3-bit ROB tag
        
        pred_taken    : in std_logic; -- 4. NEW: Prediction input from frontend
        
        cdb_valid       : out std_logic;
        cdb_tag         : out std_logic_vector(4 downto 0);
        cdb_data        : out std_logic_vector(15 downto 0);
        cdb_rob_tag     : out std_logic_vector(2 downto 0); -- 7. CHANGED: 3-bit ROB tag
        
        cdb_mispredict  : out std_logic; -- 4. NEW: Tell ROB if flush is needed
        cdb_target_pc   : out std_logic_vector(15 downto 0); -- 4. NEW: Recovery PC for ROB
        
        branch_taken  : out std_logic;
        target_pc     : out std_logic_vector(15 downto 0)
  );
end branch_alu;

architecture Behavioral of branch_alu is
    
    -- 1. FIXED: Opcodes now perfectly match Dispatch stage
    constant OP_BEQ : std_logic_vector(3 downto 0) := "1000";
    constant OP_BLT : std_logic_vector(3 downto 0) := "1001";
    constant OP_JAL : std_logic_vector(3 downto 0) := "1100";
    
begin
    
    process(clk, rst)
        variable v_target_pc  : unsigned(15 downto 0);
        variable v_taken      : std_logic;
        variable v_mispredict : std_logic;
    begin
        if rst = '1' then
            cdb_valid       <= '0';
            cdb_tag         <= (others => '0');
            cdb_data        <= (others => '0');
            cdb_rob_tag     <= (others => '0');
            cdb_mispredict  <= '0';
            cdb_target_pc   <= (others => '0');
            branch_taken    <= '0';
            target_pc       <= (others => '0');
        
        elsif rising_edge(clk) then
            
            cdb_valid <= '0';
            cdb_mispredict <= '0';
            
            if issue_valid = '1' then
                cdb_valid   <= '1';
                cdb_rob_tag <= issue_rob_tag;
                
                v_taken := '0';
                
                -- 3. JAL/Branch target is PC + immediate
                v_target_pc := unsigned(issue_pc) + unsigned(issue_imm);
                
                case issue_opcode is
                    
                    when OP_BEQ =>
                        if issue_vj = issue_vk then
                            v_taken := '1';
                        end if;
                        cdb_data <= (others => '0');
                        cdb_tag  <= (others => '0'); -- 6. FIXED: No PR result for standard branch
                    
                    when OP_BLT =>
                        if signed(issue_vj) < signed(issue_vk) then
                            v_taken := '1';
                        end if;
                        cdb_data <= (others => '0');
                        cdb_tag  <= (others => '0'); -- 6. FIXED: No PR result for standard branch
                        
                    when OP_JAL => 
                        -- 2. FIXED: Unconditional jump, no vj/vk comparison
                        v_taken := '1';
                        cdb_data <= std_logic_vector(unsigned(issue_pc) + 1); -- Save Return Address
                        cdb_tag  <= issue_dest_pr; -- JAL writes to PR
                    
                    when others =>
                        v_taken := '0';
                        cdb_data <= (others => '0');
                        cdb_tag  <= (others => '0');
                end case;
                
                -- 4. Calculate actual Misprediction
                v_mispredict := v_taken xor pred_taken;
                cdb_mispredict <= v_mispredict;
                
                -- 5. Output actual taken status
                branch_taken <= v_taken;
                
                if v_taken = '1' then
                    target_pc     <= std_logic_vector(v_target_pc);
                    cdb_target_pc <= std_logic_vector(v_target_pc);
                else
                    target_pc     <= std_logic_vector(unsigned(issue_pc) + 1);
                    cdb_target_pc <= std_logic_vector(unsigned(issue_pc) + 1);
                end if;
                
            end if;
        end if;
    end process;
                        
end Behavioral;