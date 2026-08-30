library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL; 

entity alu_execution_unit is
    Port (
        clk             : in std_logic; -- Kept ONLY for the X-Ray!
        rst             : in std_logic;
        
        issue_valid     : in std_logic;
        issue_in        : in issue_packet_t;
        
        cdb_gpr_en      : out std_logic;
        cdb_gpr_tag     : out std_logic_vector(4 downto 0);
        cdb_gpr_data    : out std_logic_vector(15 downto 0);
        
        cdb_flag_en     : out std_logic;
        cdb_flag_tag    : out std_logic_vector(4 downto 0);
        cdb_flag_data   : out std_logic_vector(1 downto 0); 
        
        rob_complete_en : out std_logic;
        rob_id_out      : out std_logic_vector(3 downto 0);
        rob_gpr_data    : out std_logic_vector(15 downto 0); 
        rob_flag_data   : out std_logic_vector(1 downto 0);
        rob_cond_fail   : out std_logic 
    );
end alu_execution_unit;

architecture Behavioral of alu_execution_unit is
begin

    -- =========================================================
    -- PURE COMBINATIONAL DATA PATH (Instant Math!)
    -- =========================================================
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
        variable v_c_flag_in   : std_logic;
        variable v_z_flag_in   : std_logic;
    begin
        -- Default assignments to prevent phantom latches
        cdb_gpr_en      <= '0';
        cdb_gpr_tag     <= (others => '0');
        cdb_gpr_data    <= (others => '0');
        cdb_flag_en     <= '0';
        cdb_flag_tag    <= (others => '0');
        cdb_flag_data   <= (others => '0');
        rob_complete_en <= '0';
        rob_id_out      <= (others => '0');
        rob_gpr_data    <= (others => '0');
        rob_flag_data   <= (others => '0');
        rob_cond_fail   <= '0';

        if issue_valid = '1' then
            v_op        := issue_in.op;
            v_rs1       := unsigned(issue_in.rs1_data);
            v_rs2       := unsigned(issue_in.rs2_data);
            v_c_flag_in := issue_in.flag_data(1);
            v_z_flag_in := issue_in.flag_data(0);
            
            v_result_ext:= (others => '0');
            v_final_c   := v_c_flag_in; 
            v_final_z   := v_z_flag_in; 
            
            -- STEP 1: PREDICATION
            v_cond_pass := true;
            if (issue_in.cz_bits = "10" and v_c_flag_in = '0') then v_cond_pass := false; end if;
            if (issue_in.cz_bits = "01" and v_z_flag_in = '0') then v_cond_pass := false; end if;

            -- STEP 2: OPERAND B
            if v_op = OP_ADI then v_actual_b := unsigned(issue_in.imm);
            else v_actual_b := v_rs2; end if;
            
            if issue_in.comp_bit = '1' then v_actual_b := not v_actual_b; end if;

            if issue_in.cz_bits = "11" then v_carry_in(0) := v_c_flag_in;
            else v_carry_in(0) := '0'; end if;

            -- STEP 3: THE MATH
            if v_op = OP_LLI then 
                v_result_ext := "0" & unsigned(issue_in.imm);
            elsif v_op = OP_ADD or v_op = OP_ADI then 
                v_result_ext := ("0" & v_rs1) + ("0" & v_actual_b) + ("0000000000000000" & v_carry_in);
                v_final_c    := v_result_ext(16); 
            elsif v_op = OP_NDU then 
                v_result_ext(15 downto 0) := not (v_rs1 and v_actual_b);
            end if;

            if v_result_ext(15 downto 0) = x"0000" then v_final_z := '1';
            else v_final_z := '0'; end if;

            -- STEP 4: OUTPUT (THE CONDITIONAL TRAP!)
            if v_cond_pass then
                cdb_gpr_en      <= issue_in.we_gpr;
                cdb_flag_en     <= issue_in.we_flag;
                rob_cond_fail   <= '0';
            else
                cdb_gpr_en      <= '0'; -- DO NOT CORRUPT REGISTERS!
                cdb_flag_en     <= '0'; -- DO NOT CORRUPT FLAGS!
                rob_cond_fail   <= '1'; -- TRIGGER THE FLUSH!
            end if;
            
            cdb_gpr_tag     <= issue_in.pd_new;
            cdb_gpr_data    <= std_logic_vector(v_result_ext(15 downto 0));
            cdb_flag_tag    <= issue_in.pf_new;
            cdb_flag_data   <= v_final_c & v_final_z;
            
            rob_complete_en <= '1';
            rob_id_out      <= issue_in.rob_id;
            rob_gpr_data    <= std_logic_vector(v_result_ext(15 downto 0));
            rob_flag_data   <= v_final_c & v_final_z;
--            if not v_cond_pass then rob_cond_fail <= '1'; else rob_cond_fail <= '0'; end if;
        end if;
    end process;

    -- =========================================================
    -- PURE CLOCKED X-RAY PROBE (Doesn't affect data)
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if issue_valid = '1' then
                report "[X-RAY ALU EXEC] PC: " & integer'image(to_integer(unsigned(issue_in.pc))) &
                       " | OP: " & integer'image(to_integer(unsigned(issue_in.op)));
            end if;
        end if;
    end process;

end Behavioral;