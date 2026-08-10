library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ID_stage is
    Port (
        clk : in std_logic;
        rst : in std_logic;
        stall_fetch : out std_logic;
        
        pc1_in : in  std_logic_vector(15 downto 0);
        pc2_in : in  std_logic_vector(15 downto 0);
        
        instruct1_in : in  std_logic_vector(15 downto 0);
        instruct2_in : in  std_logic_vector(15 downto 0);

        op1          : out std_logic_vector(3 downto 0);
        ra1          : out std_logic_vector(2 downto 0);
        rb1          : out std_logic_vector(2 downto 0);
        rc1          : out std_logic_vector(2 downto 0);
        imm1         : out std_logic_vector(15 downto 0);
        comp_bit1    : out std_logic;
        cz_bits1     : out std_logic_vector(1 downto 0);
        op1_valid    : out std_logic;
        pc1_out      : out std_logic_vector(15 downto 0);
        
        op2          : out std_logic_vector(3 downto 0);
        ra2          : out std_logic_vector(2 downto 0);
        rb2          : out std_logic_vector(2 downto 0);
        rc2          : out std_logic_vector(2 downto 0);
        imm2         : out std_logic_vector(15 downto 0);
        comp_bit2    : out std_logic;
        cz_bits2     : out std_logic_vector(1 downto 0);
        op2_valid    : out std_logic;
        pc2_out      : out std_logic_vector(15 downto 0);
        
        slide_inst2  : out std_logic;
        
        route_inst1_tag_to_inst2_rb : out std_logic;
        route_inst1_tag_to_inst2_rc : out std_logic;
        inst2_overrides_rat         : out std_logic
    );
end ID_stage;

architecture Behavioral of ID_stage is

    signal valid1, valid2 : std_logic;

    -- Raw Decoder Outputs
    signal op1_s, op2_s : std_logic_vector(3 downto 0);
    signal ra1_s, rb1_s, rc1_s : std_logic_vector(2 downto 0);
    signal ra2_s, rb2_s, rc2_s : std_logic_vector(2 downto 0);
    signal imm1_s, imm2_s : std_logic_vector(15 downto 0);
    signal comp_bit1_s, comp_bit2_s : std_logic;
    signal cz_bits1_s, cz_bits2_s : std_logic_vector(1 downto 0);
    
    -- Cracker Outputs
    signal crack_valid1, crack_valid2 : std_logic;
    signal crack_op1, crack_op2 : std_logic_vector(3 downto 0);
    signal crack_ra1, crack_ra2 : std_logic_vector(2 downto 0);
    signal crack_rb1, crack_rb2 : std_logic_vector(2 downto 0);
    signal crack_imm1, crack_imm2 : std_logic_vector(15 downto 0);
    signal crack_pc1, crack_pc2 : std_logic_vector(15 downto 0);
    signal crack_cz1, crack_cz2 : std_logic_vector(1 downto 0);
    signal is_cracking : std_logic;
    
    -- Routing Controls
    signal inst1_is_complex : std_logic;
    signal inst2_is_complex : std_logic;
    signal use_cracker      : std_logic;
    signal slide_inst2_s    : std_logic;
    
    -- FINAL OUTPUT SIGNALS (Internal wires to read from for dependency check)
    signal final_valid1, final_valid2 : std_logic;
    signal final_op1, final_op2       : std_logic_vector(3 downto 0);
    signal final_ra1, final_ra2       : std_logic_vector(2 downto 0);
    signal final_rb1, final_rb2       : std_logic_vector(2 downto 0);
    signal final_rc1, final_rc2       : std_logic_vector(2 downto 0);

    -- Dependency detection intermediate flags
    -- Dependency detection intermediate flags
    signal inst1_writes_reg : std_logic;
    signal inst2_reads_rb   : std_logic;
    signal inst2_reads_rc   : std_logic;
    signal inst2_writes_reg : std_logic;

    -- ADD THESE 3 LINES:
    signal route_inst1_tag_to_inst2_rb_s : std_logic;
    signal route_inst1_tag_to_inst2_rc_s : std_logic;
    signal inst2_overrides_rat_s         : std_logic;
    
    signal cracker_done_s : std_logic;
    signal stall_fetch_s : std_logic;
begin

    -- ------------------------------------------------------------------
    -- 1. DECODERS
    -- ------------------------------------------------------------------
    decoder_inst1 : entity work.instruction_decoder port map(
            instr => instruct1_in, valid_inst => valid1, opcode => op1_s,
            ra => ra1_s, rb => rb1_s, rc => rc1_s, imm_ext => imm1_s,
            comp_bit => comp_bit1_s, cz_bits => cz_bits1_s
        );

    decoder_inst2 : entity work.instruction_decoder port map(
            instr => instruct2_in, valid_inst => valid2, opcode => op2_s,
            ra => ra2_s, rb => rb2_s, rc => rc2_s, imm_ext => imm2_s,
            comp_bit => comp_bit2_s, cz_bits => cz_bits2_s
        );
        
    -- ------------------------------------------------------------------
    -- 2. MICRO-OP CRACKER
    -- ------------------------------------------------------------------
    cracker_inst : entity work.micro_op_cracker port map(
            clk => clk, rst => rst,
            valid_in => valid1, instr_in => instruct1_in, pc_in => pc1_in,
            stall_fetch => is_cracking,
            cracker_done => cracker_done_s,
            
            uop1_valid => crack_valid1, uop1_opcode => crack_op1,
            uop1_base_reg => crack_ra1, uop1_target_reg => crack_rb1,
            uop1_offset => crack_imm1, uop1_pc => crack_pc1, uop1_cz => crack_cz1,
            
            uop2_valid => crack_valid2, uop2_opcode => crack_op2,
            uop2_base_reg => crack_ra2, uop2_target_reg => crack_rb2,
            uop2_offset => crack_imm2, uop2_pc => crack_pc2, uop2_cz => crack_cz2
        );
        
    -- ------------------------------------------------------------------
    -- 3. MUX ROUTING
    -- ------------------------------------------------------------------
    inst1_is_complex <= '1' when (valid1 = '1' and (op1_s = "0110" or op1_s = "0111")) else '0';
    inst2_is_complex <= '1' when (valid2 = '1' and (op2_s = "0110" or op2_s = "0111")) else '0';
    use_cracker <= is_cracking or inst1_is_complex;
    slide_inst2_s <= '1' when (inst1_is_complex = '0' and inst2_is_complex = '1' and is_cracking = '0') else '0';
    slide_inst2   <= slide_inst2_s;
    stall_fetch_s <= (use_cracker and not cracker_done_s) or slide_inst2_s;

    -- Slot 1 Internal Finals
    final_valid1 <= crack_valid1 when use_cracker = '1' else valid1;
    final_op1    <= crack_op1    when use_cracker = '1' else op1_s;
    final_ra1    <= crack_ra1    when use_cracker = '1' else ra1_s;
    final_rb1    <= crack_rb1    when use_cracker = '1' else rb1_s;
    final_rc1    <= "000"        when use_cracker = '1' else rc1_s;
    
    -- Slot 2 Internal Finals
    final_valid2 <= crack_valid2 when use_cracker = '1' else '0' when slide_inst2_s = '1' else valid2;
    final_op2    <= crack_op2    when use_cracker = '1' else op2_s;
    final_ra2    <= crack_ra2    when use_cracker = '1' else ra2_s;
    final_rb2    <= crack_rb2    when use_cracker = '1' else rb2_s;
    final_rc2    <= "000"        when use_cracker = '1' else rc2_s;

    -- Route to Output Ports
    op1_valid <= final_valid1;
    op1       <= final_op1;
    ra1       <= final_ra1;
    rb1       <= final_rb1;
    rc1       <= final_rc1;
    imm1      <= crack_imm1 when use_cracker = '1' else imm1_s;
    pc1_out   <= crack_pc1  when use_cracker = '1' else pc1_in;
    cz_bits1  <= crack_cz1  when use_cracker = '1' else cz_bits1_s;
    comp_bit1 <= '0'        when use_cracker = '1' else comp_bit1_s; 
    
    op2_valid <= final_valid2;
    op2       <= final_op2;
    ra2       <= final_ra2;
    rb2       <= final_rb2;
    rc2       <= final_rc2;
    imm2      <= crack_imm2 when use_cracker = '1' else imm2_s;
    pc2_out   <= crack_pc2  when use_cracker = '1' else pc2_in;
    cz_bits2  <= crack_cz2  when use_cracker = '1' else cz_bits2_s;
    comp_bit2 <= '0'        when use_cracker = '1' else comp_bit2_s; 

    -- ------------------------------------------------------------------
    -- 4. DEPENDENCY DETECTION (Now looks at the FINAL uops)
    -- ------------------------------------------------------------------
    inst1_writes_reg <= '1' when (final_op1 = "0001") or (final_op1 = "0010") or
                                 (final_op1 = "0100") or (final_op1 = "0011") else '0';
    
    inst2_reads_rb <= '1' when (final_op2 = "0001") or (final_op2 = "1000") else '0';
    
    inst2_reads_rc <= '1' when (final_op2 = "0001") or (final_op2 = "0010") else '0';
    
    inst2_writes_reg <= '1' when (final_op2 = "0001") or (final_op2 = "0010") or 
                                 (final_op2 = "0100") or (final_op2 = "0011") else '0';
    
    -- CHANGE THESE TO DRIVE THE _s SIGNALS
    route_inst1_tag_to_inst2_rb_s <= '1' when (final_valid1 = '1') and (final_valid2 = '1') and
                                            (inst1_writes_reg = '1') and (inst2_reads_rb = '1') and
                                            (final_ra1 = final_rb2) else '0';
    
    route_inst1_tag_to_inst2_rc_s <= '1' when (final_valid1 = '1') and (final_valid2 = '1') and
                                            (inst1_writes_reg = '1') and (inst2_reads_rc = '1') and
                                            (final_ra1 = final_rc2) else '0';
    
    inst2_overrides_rat_s <= '1' when (final_valid1 = '1') and (final_valid2 = '1') and
                                    (inst1_writes_reg = '1') and (inst2_writes_reg = '1') and
                                    (final_ra1 = final_ra2) else '0';

    -- ADD THESE CONCURRENT ASSIGNMENTS TO THE OUT PORTS
    route_inst1_tag_to_inst2_rb <= route_inst1_tag_to_inst2_rb_s;
    route_inst1_tag_to_inst2_rc <= route_inst1_tag_to_inst2_rc_s;
    inst2_overrides_rat         <= inst2_overrides_rat_s;
    stall_fetch   <= stall_fetch_s;
-- =================================================================
    -- 5. SIMULATION DEBUG PRINTING
    -- =================================================================
    -- synthesis translate_off
    process(clk)
        -- Internal variables just for clean printing
        variable print_imm1, print_imm2 : std_logic_vector(15 downto 0);
        variable print_cz1, print_cz2   : std_logic_vector(1 downto 0);
    begin
        if falling_edge(clk) then
            
            -- Route the correct IMM and CZ for printing
            if use_cracker = '1' then
                print_imm1 := crack_imm1; print_cz1 := crack_cz1;
                print_imm2 := crack_imm2; print_cz2 := crack_cz2;
            else
                print_imm1 := imm1_s; print_cz1 := cz_bits1_s;
                print_imm2 := imm2_s; print_cz2 := cz_bits2_s;
            end if;
            
            if (final_valid1 = '1' or final_valid2 = '1' or use_cracker = '1') then
                report "-------------------------------------------------------------";
                report "TIME: " & time'image(now) & " | USE_CRACKER: " & std_logic'image(use_cracker) & " | STALL_FETCH: " & std_logic'image(stall_fetch_s);
                
                -- Print Slot 1
                if final_valid1 = '1' then
                    report "  SLOT 1 | OP: " & integer'image(to_integer(unsigned(final_op1))) &
                           " | RA: " & integer'image(to_integer(unsigned(final_ra1))) &
                           " | RB: " & integer'image(to_integer(unsigned(final_rb1))) &
                           " | IMM: " & integer'image(to_integer(unsigned(print_imm1))) &
                           " | CZ: " & integer'image(to_integer(unsigned(print_cz1)));
                else
                    report "  SLOT 1 | BUBBLE (Valid = 0)";
                end if;
                
                -- Print Slot 2
                if final_valid2 = '1' then
                    report "  SLOT 2 | OP: " & integer'image(to_integer(unsigned(final_op2))) &
                           " | RA: " & integer'image(to_integer(unsigned(final_ra2))) &
                           " | RB: " & integer'image(to_integer(unsigned(final_rb2))) &
                           " | IMM: " & integer'image(to_integer(unsigned(print_imm2))) &
                           " | CZ: " & integer'image(to_integer(unsigned(print_cz2)));
                else
                    report "  SLOT 2 | BUBBLE (Valid = 0)";
                end if;
            end if;
        end if;
    end process;
    -- synthesis translate_on
end Behavioral;