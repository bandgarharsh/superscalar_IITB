library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; 
use work.iitb_risc_pkg.ALL; 

----------------------------------------------------------------------------------
-- MODULE: ALU Execution Unit
-- DESCRIPTION:
--   Purely combinational Arithmetic Logic Unit. Evaluates standard integer
--   math, logical operations, and condition flags. Masks Common Data Bus (CDB) 
--   writeback if conditional instructions (like ADC/ADZ) fail their condition check.
----------------------------------------------------------------------------------
entity alu_execution_unit is
    Port (
        clk             : in std_logic; 
        rst             : in std_logic;
        issue_valid     : in std_logic; 
        issue_in        : in issue_packet_t;
        
        -- CDB Broadcast Interface
        cdb_gpr_en      : out std_logic; 
        cdb_gpr_tag     : out std_logic_vector(4 downto 0); 
        cdb_gpr_data    : out std_logic_vector(15 downto 0);
        cdb_flag_en     : out std_logic; 
        cdb_flag_tag    : out std_logic_vector(4 downto 0); 
        cdb_flag_data   : out std_logic_vector(1 downto 0); 
        
        -- ROB Commit Interface
        rob_complete_en : out std_logic; 
        rob_id_out      : out std_logic_vector(3 downto 0); 
        rob_gpr_data    : out std_logic_vector(15 downto 0); 
        rob_flag_data   : out std_logic_vector(1 downto 0);
        rob_cond_fail   : out std_logic 
    );
end alu_execution_unit;

architecture Behavioral of alu_execution_unit is
    signal internal_cond_fail : std_logic;
    signal diag_gpr_data      : std_logic_vector(15 downto 0);
    signal diag_flag_data     : std_logic_vector(1 downto 0);
begin
    
    ------------------------------------------------------------------------------
    -- COMBINATIONAL EXECUTION PATH
    ------------------------------------------------------------------------------
    process(issue_valid, issue_in)
        variable v_op          : std_logic_vector(3 downto 0);
        variable v_rs1         : unsigned(15 downto 0);
        variable v_rs2         : unsigned(15 downto 0);
        variable v_actual_b    : unsigned(15 downto 0);
        variable v_carry_in    : unsigned(0 downto 0);
        variable v_result_ext  : unsigned(16 downto 0); 
        variable v_final_z     : std_logic;
        variable v_final_c     : std_logic;
        variable v_cond_pass   : boolean;
    begin
        -- Default assignments to prevent latches
        cdb_gpr_en <= '0'; cdb_gpr_tag <= (others => '0'); cdb_gpr_data <= (others => '0');
        cdb_flag_en <= '0'; cdb_flag_tag <= (others => '0'); cdb_flag_data <= (others => '0');
        rob_complete_en <= '0'; rob_id_out <= (others => '0');
        rob_gpr_data <= (others => '0'); rob_flag_data <= (others => '0'); 
        internal_cond_fail <= '0';
        diag_gpr_data <= (others => '0'); diag_flag_data <= (others => '0');

        if issue_valid = '1' then
            v_op         := issue_in.op;
            v_rs1        := unsigned(issue_in.rs1_data);
            v_rs2        := unsigned(issue_in.rs2_data);
            v_result_ext := (others => '0');
            v_final_c    := issue_in.flag_data(1); 
            v_final_z    := issue_in.flag_data(0); 
            v_cond_pass  := true;
            
            -- STRICT PREDICATION: Only ADD and NDU can be conditional
            if (v_op = OP_ADD or v_op = OP_NDU) then
                -- "00" = Unconditional
                -- "10" = If Carry = 1
                -- "01" = If Zero = 1
                -- "11" = Unconditional (Add with carry)
                if (issue_in.cz_bits = "10" and issue_in.flag_data(1) = '0') then 
                    v_cond_pass := false; 
                end if;
                if (issue_in.cz_bits = "01" and issue_in.flag_data(0) = '0') then 
                    v_cond_pass := false; 
                end if;
            end if;

            -- IMM & CARRY ROUTING
            if v_op = OP_ADI then 
                v_actual_b := unsigned(issue_in.imm); 
                v_carry_in(0) := '0';
            elsif v_op = OP_LLI then
                v_actual_b := unsigned(issue_in.imm); 
                v_carry_in(0) := '0';
            else 
                v_actual_b := v_rs2; 
                if issue_in.comp_bit = '1' then 
                    v_actual_b := not v_actual_b; 
                end if;
                
                -- Route Carry-in bit for AWC/NCW
                if issue_in.cz_bits = "11" then 
                    v_carry_in(0) := issue_in.flag_data(1); 
                else 
                    v_carry_in(0) := '0'; 
                end if;
            end if;

            -- MATH EXECUTION
            if v_op = OP_LLI then 
                v_result_ext := "0" & unsigned(issue_in.imm);
            elsif v_op = OP_ADD or v_op = OP_ADI then 
                v_result_ext := ("0" & v_rs1) + ("0" & v_actual_b) + ("0000000000000000" & v_carry_in);
                v_final_c    := v_result_ext(16); 
            elsif v_op = OP_NDU then 
                v_result_ext(15 downto 0) := not (v_rs1 and v_actual_b);
            end if;

            -- Zero Flag evaluation
            if v_result_ext(15 downto 0) = x"0000" then 
                v_final_z := '1'; 
            else 
                v_final_z := '0'; 
            end if;

            -- Output Masking (Kill writebacks if condition failed)
            if v_cond_pass then
                cdb_gpr_en <= issue_in.we_gpr; 
                cdb_flag_en <= issue_in.we_flag; 
                internal_cond_fail <= '0';
            else
                cdb_gpr_en <= '0'; 
                cdb_flag_en <= '0'; 
                internal_cond_fail <= '1'; 
            end if;
            
            -- Route Data out
            cdb_gpr_tag <= issue_in.pd_new; 
            cdb_gpr_data <= std_logic_vector(v_result_ext(15 downto 0));
            cdb_flag_tag <= issue_in.pf_new; 
            cdb_flag_data <= v_final_c & v_final_z;
            
            rob_complete_en <= '1'; 
            rob_id_out <= issue_in.rob_id;
            rob_gpr_data <= std_logic_vector(v_result_ext(15 downto 0)); 
            rob_flag_data <= v_final_c & v_final_z;
            
            -- Diagnostic taps
            diag_gpr_data <= std_logic_vector(v_result_ext(15 downto 0));
            diag_flag_data <= v_final_c & v_final_z;
        end if;
    end process;

    rob_cond_fail <= internal_cond_fail;

    ------------------------------------------------------------------------------
    -- DIAGNOSTICS LOGGING
    ------------------------------------------------------------------------------
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' and issue_valid = '1' then
                write(l, string'("------------------------------------------------------------------")); writeline(output, l);
                write(l, string'("[ALU INPUTS] PC: ")); write(l, integer'image(to_integer(unsigned(issue_in.pc))));
                write(l, string'(" | OP: ")); write(l, integer'image(to_integer(unsigned(issue_in.op))));
                write(l, string'(" | RS1: ")); write(l, integer'image(to_integer(signed(issue_in.rs1_data))));
                write(l, string'(" | RS2: ")); write(l, integer'image(to_integer(signed(issue_in.rs2_data))));
                write(l, string'(" | IMM: ")); write(l, integer'image(to_integer(signed(issue_in.imm))));
                write(l, string'(" | COMP: ")); write(l, std_logic'image(issue_in.comp_bit));
                write(l, string'(" | CZ: ")); write(l, integer'image(to_integer(unsigned(issue_in.cz_bits))));
                write(l, string'(" | FLAGS_IN: ")); write(l, integer'image(to_integer(unsigned(issue_in.flag_data))));
                writeline(output, l);
                
                write(l, string'("    [RESULT] "));
                if internal_cond_fail = '1' then 
                    write(l, string'("-> CONDITION FAILED! Masking CDB."));
                else 
                    write(l, string'("-> PASSED! Data: "));
                    write(l, integer'image(to_integer(signed(diag_gpr_data))));
                    write(l, string'(" | FLAGS_OUT: ")); write(l, integer'image(to_integer(unsigned(diag_flag_data))));
                end if;
                writeline(output, l);
                write(l, string'("------------------------------------------------------------------")); writeline(output, l);
            end if;
        end if;
    end process;
end Behavioral;