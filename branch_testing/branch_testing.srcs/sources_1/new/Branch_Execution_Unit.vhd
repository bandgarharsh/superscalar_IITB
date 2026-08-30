library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; 
use work.iitb_risc_pkg.ALL; 

entity Branch_Execution_Unit is
    Port (
        clk                 : in std_logic; 
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
    signal internal_mispred : std_logic;
    signal internal_target  : std_logic_vector(15 downto 0);
begin

-- =========================================================
    -- PURE COMBINATIONAL DATA PATH (Instant Execution!)
    -- =========================================================
    process(issue_valid, issue_packet)
        variable v_actual_taken  : std_logic;
        variable v_actual_target : unsigned(15 downto 0);
        variable v_pc_plus_2     : unsigned(15 downto 0);
        variable v_mispredicted  : std_logic;
        
        -- Temporary signed variables for safe negative offsets
        variable v_signed_pc     : signed(15 downto 0);
        variable v_imm_x2        : signed(15 downto 0);
    begin
        -- Default assignments to prevent phantom latches
        cdb_gpr_en         <= '0';
        cdb_gpr_tag        <= (others => '0');
        cdb_gpr_data       <= (others => '0');
        rob_complete_en    <= '0';
        rob_id_out         <= (others => '0');
        rob_gpr_data       <= (others => '0');
        rob_is_branch      <= '0';
        
        internal_mispred   <= '0';
        internal_target    <= (others => '0');

        if issue_valid = '1' then
            v_pc_plus_2   := unsigned(issue_packet.pc) + 2; 
            v_signed_pc   := signed(issue_packet.pc);
            -- ISA MANUAL: Imm * 2 (Shift left by 1)
            v_imm_x2      := shift_left(signed(issue_packet.imm), 1); 
            
            -- =====================================================
            -- STEP 1: CALCULATE TARGET AND CONDITION
            -- =====================================================
            if issue_packet.op = OP_BEQ then
                v_actual_target := unsigned(v_signed_pc + v_imm_x2);
                if issue_packet.rs1_data = issue_packet.rs2_data then v_actual_taken := '1'; else v_actual_taken := '0'; end if;
            
            elsif issue_packet.op = OP_BLT then
                v_actual_target := unsigned(v_signed_pc + v_imm_x2);
                if signed(issue_packet.rs1_data) < signed(issue_packet.rs2_data) then v_actual_taken := '1'; else v_actual_taken := '0'; end if;
            
            elsif issue_packet.op = OP_BLE then
                v_actual_target := unsigned(v_signed_pc + v_imm_x2);
                if signed(issue_packet.rs1_data) <= signed(issue_packet.rs2_data) then v_actual_taken := '1'; else v_actual_taken := '0'; end if;
            
            elsif issue_packet.op = OP_JAL then
                v_actual_target := unsigned(v_signed_pc + v_imm_x2);
                v_actual_taken  := '1';
            
            elsif issue_packet.op = OP_JLR then
                -- ISA MANUAL: Jump to address in rb (rs1 port)
                v_actual_target := unsigned(issue_packet.rs1_data); 
                v_actual_taken  := '1';
                
            elsif issue_packet.op = OP_JRI then
                -- ISA MANUAL: Memory location given by RA + Imm*2
                v_actual_target := unsigned(signed(issue_packet.rs1_data) + v_imm_x2); 
                v_actual_taken  := '1';
                
            else
                v_actual_target := v_pc_plus_2; 
                v_actual_taken  := '0';
            end if;

            -- =====================================================
            -- STEP 2: MISPREDICT CHECK
            -- =====================================================
            v_mispredicted := '0';
            if v_actual_taken /= issue_packet.pred_taken then
                v_mispredicted := '1';
            elsif v_actual_taken = '1' and std_logic_vector(v_actual_target) /= issue_packet.pred_target then
                v_mispredicted := '1';
            end if;

            -- =====================================================
            -- STEP 3: BROADCAST JUMP & LINK (Save PC+2 to Dest)
            -- =====================================================
            -- If JAL/JLR/JRI have a valid destination register (we_gpr = '1')
            if issue_packet.we_gpr = '1' then 
                cdb_gpr_en   <= '1';
                cdb_gpr_tag  <= issue_packet.pd_new; 
                cdb_gpr_data <= std_logic_vector(v_pc_plus_2);
            end if;

            -- Send packet to ROB
            rob_complete_en <= '1';
            rob_id_out      <= issue_packet.rob_id;
            rob_gpr_data    <= std_logic_vector(v_pc_plus_2); -- Give ROB the link address
            rob_is_branch   <= '1';
            
            internal_mispred <= v_mispredicted;
            if v_actual_taken = '1' then 
                internal_target <= std_logic_vector(v_actual_target);
            else 
                internal_target <= std_logic_vector(v_pc_plus_2); 
            end if;
        end if;
    end process;

    rob_mispredicted   <= internal_mispred;
    rob_correct_target <= internal_target;

    -- =========================================================
    -- PROFESSIONAL X-RAY PROBE
    -- =========================================================
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' and issue_valid = '1' then
                write(l, string'("[BRANCH EXEC] PC: ")); write(l, integer'image(to_integer(unsigned(issue_packet.pc))));
                
                if issue_packet.op = OP_BEQ then write(l, string'(" | BEQ (")); write(l, integer'image(to_integer(signed(issue_packet.rs1_data)))); write(l, string'(" == ")); write(l, integer'image(to_integer(signed(issue_packet.rs2_data)))); write(l, string'(")"));
                elsif issue_packet.op = OP_BLT then write(l, string'(" | BLT (")); write(l, integer'image(to_integer(signed(issue_packet.rs1_data)))); write(l, string'(" < ")); write(l, integer'image(to_integer(signed(issue_packet.rs2_data)))); write(l, string'(")"));
                elsif issue_packet.op = OP_BLE then write(l, string'(" | BLE (")); write(l, integer'image(to_integer(signed(issue_packet.rs1_data)))); write(l, string'(" <= ")); write(l, integer'image(to_integer(signed(issue_packet.rs2_data)))); write(l, string'(")"));
                elsif issue_packet.op = OP_JAL then write(l, string'(" | JAL (+")); write(l, integer'image(to_integer(unsigned(issue_packet.imm)))); write(l, string'(")"));
                elsif issue_packet.op = OP_JLR then write(l, string'(" | JLR (Target Reg = ")); write(l, integer'image(to_integer(unsigned(issue_packet.rs1_data)))); write(l, string'(")"));
                elsif issue_packet.op = OP_JRI then write(l, string'(" | JRI (Reg+Imm = ")); write(l, integer'image(to_integer(unsigned(issue_packet.rs1_data)) + to_integer(unsigned(issue_packet.imm)))); write(l, string'(")"));
                end if;

                if internal_mispred = '1' then
                    write(l, string'(" -> MISPREDICTED! JUMP TO PC: ")); write(l, integer'image(to_integer(unsigned(internal_target))));
                else
                    write(l, string'(" -> Prediction Correct."));
                end if;
                writeline(output, l);
            end if;
        end if;
    end process;

end Behavioral;