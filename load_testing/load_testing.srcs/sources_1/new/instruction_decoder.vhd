library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL; 

entity instruction_decoder is
    Port (
        instr      : in  std_logic_vector(15 downto 0); 
        valid_in   : in  std_logic; 
        valid_inst : out std_logic; 
        illegal_op : out std_logic; 
        opcode     : out std_logic_vector(3 downto 0); 
        src1_reg   : out std_logic_vector(2 downto 0); 
        src2_reg   : out std_logic_vector(2 downto 0); 
        dest_reg   : out std_logic_vector(2 downto 0); 
        reads_rs1  : out std_logic; 
        reads_rs2  : out std_logic; 
        we_gpr     : out std_logic; 
        we_flag    : out std_logic; 
        dest_is_r0 : out std_logic; 
        cz_bits    : out std_logic_vector(1 downto 0);
        imm_ext    : out std_logic_vector(15 downto 0); 
        comp_bit   : out std_logic; 
        is_alu     : out std_logic; 
        is_lsu     : out std_logic; 
        is_branch  : out std_logic; 
        is_multimem: out std_logic; 
        is_store   : out std_logic 
    );
end instruction_decoder;

architecture Behavioral of instruction_decoder is
begin
    opcode <= instr(15 downto 12); 

    process(instr, valid_in)
        variable v_op : std_logic_vector(3 downto 0);
        variable v_ra : std_logic_vector(2 downto 0);
        variable v_rb : std_logic_vector(2 downto 0);
        variable v_rc : std_logic_vector(2 downto 0);
        variable v_we_gpr : std_logic;
        variable v_dest : std_logic_vector(2 downto 0);
    begin
        v_op := instr(15 downto 12);
        v_ra := instr(11 downto 9);
        v_rb := instr(8 downto 6);
        v_rc := instr(5 downto 3);

        valid_inst  <= valid_in; illegal_op  <= '0';
        src1_reg    <= v_rb;
        src2_reg    <= v_rc; 
        v_dest := v_ra;
        v_we_gpr    := '0'; we_flag     <= '0';
        reads_rs1   <= '0'; reads_rs2   <= '0'; cz_bits <= "00";
        is_alu      <= '0'; is_lsu      <= '0'; is_branch <= '0';
        is_multimem <= '0'; imm_ext     <= (others => '0');
        comp_bit    <= '0'; is_store    <= '0';

        if valid_in = '1' then
            case v_op is
                when OP_ADD | OP_NDU =>
                    src1_reg  <= v_rb; --- this 3 you got it wrong here dest rs1 rs2 but you thought op rs1 rs2 dest 3 bits
                    src2_reg  <= v_rc;
                    v_dest    := v_ra;
                    reads_rs1 <= '1'; reads_rs2 <= '1';
                    v_we_gpr  := '1'; we_flag   <= '1'; 
                    comp_bit  <= instr(2); cz_bits <= instr(1 downto 0); is_alu <= '1';

                when OP_ADI =>
                    src1_reg  <= v_rb; -- here also
                    v_dest    := v_ra; -- ADI Writes to RA!
                    reads_rs1 <= '1'; reads_rs2 <= '0';
                    v_we_gpr  := '1'; we_flag   <= '1';  
                    imm_ext   <= std_logic_vector(resize(signed(instr(5 downto 0)), 16)); is_alu <= '1';

                when OP_LLI =>
                    v_dest    := v_ra;
                    reads_rs1 <= '0'; reads_rs2 <= '0';
                    v_we_gpr  := '1'; we_flag   <= '0';
                    imm_ext   <= std_logic_vector(resize(unsigned(instr(8 downto 0)), 16)); is_alu <= '1';

                when OP_LW =>
                    src1_reg  <= v_rb; 
                    v_dest    := v_ra;
                    reads_rs1 <= '1'; reads_rs2 <= '0';
                    v_we_gpr  := '1'; we_flag   <= '1';  
                    imm_ext   <= std_logic_vector(resize(signed(instr(5 downto 0)), 16)); is_lsu <= '1';

                when OP_SW =>
                    src1_reg  <= v_rb; -- i think here 
                    src2_reg  <= v_ra;
                    reads_rs1 <= '1'; reads_rs2 <= '1'; 
                    v_we_gpr  := '0'; we_flag   <= '0';
                    imm_ext   <= std_logic_vector(resize(signed(instr(5 downto 0)), 16)); is_lsu <= '1'; is_store <= '1';

                when OP_LM | OP_SM =>
                    src1_reg  <= v_ra;
                    reads_rs1 <= '1'; imm_ext(8 downto 0) <= instr(8 downto 0); is_multimem <= '1';

                when OP_BEQ | OP_BLT | OP_BLE =>
                    src1_reg  <= v_ra; src2_reg  <= v_rb;
                    reads_rs1 <= '1'; reads_rs2 <= '1'; 
                    imm_ext   <= std_logic_vector(resize(signed(instr(5 downto 0)), 16)); is_branch <= '1';

                when OP_JAL =>
                    v_dest    := v_ra;
                    reads_rs1 <= '0'; reads_rs2 <= '0';
                    v_we_gpr  := '1'; imm_ext   <= std_logic_vector(resize(signed(instr(8 downto 0)), 16)); is_branch <= '1';

                when OP_JLR =>
                    src1_reg  <= v_rb; -- here also 
                    v_dest    := v_ra;
                    reads_rs1 <= '1'; reads_rs2 <= '0'; v_we_gpr  := '1'; is_branch <= '1';

                when OP_JRI =>
                    src1_reg  <= v_ra; reads_rs1 <= '1'; reads_rs2 <= '0';
                    imm_ext   <= std_logic_vector(resize(signed(instr(8 downto 0)), 16)); is_branch <= '1';

                when others => illegal_op <= '1';
            end case;
        end if;

        we_gpr   <= v_we_gpr; dest_reg <= v_dest;
        if (v_we_gpr = '1' and v_dest = "000") then dest_is_r0 <= '1'; else dest_is_r0 <= '0'; end if;
    end process;
end Behavioral;