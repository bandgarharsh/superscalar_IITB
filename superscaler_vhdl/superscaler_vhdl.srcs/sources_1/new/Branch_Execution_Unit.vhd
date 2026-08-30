library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL; 

entity Branch_Execution_Unit is
    Port (
        clk                 : in std_logic; -- Kept ONLY for the X-Ray!
        rst                 : in std_logic;
        
        issue_valid         : in std_logic;
        issue_packet        : in branch_issue_packet_t;
        
        cdb_gpr_en          : out std_logic;
        cdb_gpr_tag         : out std_logic_vector(4 downto 0);
        cdb_gpr_data        : out std_logic_vector(15 downto 0);
        
        rob_complete_en     : out std_logic;
        rob_id_out          : out std_logic_vector(3 downto 0);
        rob_gpr_data        : out std_logic_vector(15 downto 0); 
        
        rob_is_branch       : out std_logic;
        rob_mispredicted    : out std_logic;
        rob_correct_target  : out std_logic_vector(15 downto 0)
    );
end Branch_Execution_Unit;

architecture Behavioral of Branch_Execution_Unit is
begin

    -- =========================================================
    -- PURE COMBINATIONAL DATA PATH (Instant Execution!)
    -- =========================================================
    process(issue_valid, issue_packet)
        variable v_actual_taken  : std_logic;
        variable v_actual_target : unsigned(15 downto 0);
        variable v_pc_plus_2     : unsigned(15 downto 0);
        variable v_mispredicted  : std_logic;
    begin
        -- Default assignments to prevent phantom latches
        cdb_gpr_en         <= '0';
        cdb_gpr_tag        <= (others => '0');
        cdb_gpr_data       <= (others => '0');
        rob_complete_en    <= '0';
        rob_id_out         <= (others => '0');
        rob_gpr_data       <= (others => '0');
        rob_is_branch      <= '0';
        rob_mispredicted   <= '0';
        rob_correct_target <= (others => '0');

        if issue_valid = '1' then
            v_pc_plus_2 := unsigned(issue_packet.pc) + 2; 
            
            -- STEP 1: CALCULATE TARGET
            if issue_packet.op = OP_BEQ then
                v_actual_target := unsigned(issue_packet.pc) + unsigned(issue_packet.imm);
                if issue_packet.rs1_data = issue_packet.rs2_data then v_actual_taken := '1'; else v_actual_taken := '0'; end if;
            elsif issue_packet.op = OP_BLT then
                v_actual_target := unsigned(issue_packet.pc) + unsigned(issue_packet.imm);
                if signed(issue_packet.rs1_data) < signed(issue_packet.rs2_data) then v_actual_taken := '1'; else v_actual_taken := '0'; end if;
            elsif issue_packet.op = OP_BLE then
                v_actual_target := unsigned(issue_packet.pc) + unsigned(issue_packet.imm);
                if signed(issue_packet.rs1_data) <= signed(issue_packet.rs2_data) then v_actual_taken := '1'; else v_actual_taken := '0'; end if;
            elsif issue_packet.op = OP_JAL then
                v_actual_target := unsigned(issue_packet.pc) + unsigned(issue_packet.imm);
                v_actual_taken  := '1';
            elsif issue_packet.op = OP_JLR then
                v_actual_target := unsigned(issue_packet.rs1_data) + unsigned(issue_packet.imm);
                v_actual_taken  := '1';
            else
                v_actual_target := unsigned(issue_packet.pc) + 1;
                v_actual_taken  := '0';
            end if;

            -- STEP 2: MISPREDICT CHECK
            v_mispredicted := '0';
            if v_actual_taken /= issue_packet.pred_taken then
                v_mispredicted := '1';
            elsif v_actual_taken = '1' and std_logic_vector(v_actual_target) /= issue_packet.pred_target then
                v_mispredicted := '1';
            end if;

            -- STEP 3: BROADCAST
            if issue_packet.we_gpr = '1' then 
                cdb_gpr_en   <= '1';
                cdb_gpr_tag  <= issue_packet.pd_new; 
                cdb_gpr_data <= std_logic_vector(v_pc_plus_2);
            end if;

            rob_complete_en <= '1';
            rob_id_out      <= issue_packet.rob_id;
            rob_gpr_data    <= std_logic_vector(v_pc_plus_2);
            rob_is_branch   <= '1';
            rob_mispredicted <= v_mispredicted;
            
            if v_actual_taken = '1' then rob_correct_target <= std_logic_vector(v_actual_target);
            else rob_correct_target <= std_logic_vector(v_pc_plus_2); end if;
        end if;
    end process;

    -- =========================================================
    -- PURE CLOCKED X-RAY PROBE
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if issue_valid = '1' then
                report "[X-RAY BRANCH EXEC] PC: " & integer'image(to_integer(unsigned(issue_packet.pc)));
            end if;
        end if;
    end process;

end Behavioral;