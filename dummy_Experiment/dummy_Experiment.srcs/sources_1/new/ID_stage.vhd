library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; -- NEW: The magic library for clean console printing!
use work.iitb_risc_pkg.ALL;

entity ID_stage is
    Port (
        clk          : in std_logic;
        rst          : in std_logic;
        stall_fetch  : in std_logic; -- Driven by downstream queues/ROB later
        
        -- Inputs from Fetch
        valid1_in    : in  std_logic;
        valid2_in    : in  std_logic;
        pc1_in       : in  std_logic_vector(15 downto 0);
        pc2_in       : in  std_logic_vector(15 downto 0);
        instruct1_in : in  std_logic_vector(15 downto 0);
        instruct2_in : in  std_logic_vector(15 downto 0);
        
        -- predict
        in_pred_taken1      : in std_logic;    
        in_pred_target1     : in std_logic_vector(15 downto 0);
        in_pred_taken2      : in std_logic;    
        in_pred_target2     : in std_logic_vector(15 downto 0);
        
        -- ==========================================
        -- SLOT 1 OUTPUTS TO RENAME & DISPATCH
        -- ==========================================
        op1_valid    : out std_logic;
        pc1_out      : out std_logic_vector(15 downto 0);
        op1          : out std_logic_vector(3 downto 0);
        imm1         : out std_logic_vector(15 downto 0);
        comp_bit1    : out std_logic;
        cz_bits1     : out std_logic_vector(1 downto 0);
        
        -- Unified Source/Destinations
        src1_reg1    : out std_logic_vector(2 downto 0); 
        src2_reg1    : out std_logic_vector(2 downto 0); 
        dest_reg1    : out std_logic_vector(2 downto 0); 
        
        -- Control Flags
        reads_rs1_1  : out std_logic; 
        reads_rs2_1  : out std_logic; 
        we_gpr1      : out std_logic; 
        dest_is_r0_1 : out std_logic; 

        we_flag1     : out std_logic; -- Combined writes_c OR writes_z
        
        -- Routing Flags
        is_alu1      : out std_logic; 
        is_lsu1      : out std_logic; 
        is_branch1   : out std_logic; 
        is_multimem1 : out std_logic; 
        is_store1    : out std_logic;
        illegal_op1  : out std_logic;
        
        out_pred_taken1      : out std_logic;
        out_pred_target1     : out std_logic_vector(15 downto 0);
        
        -- ==========================================
        -- SLOT 2 OUTPUTS TO RENAME & DISPATCH
        -- ==========================================
        op2_valid    : out std_logic;
        pc2_out      : out std_logic_vector(15 downto 0);
        op2          : out std_logic_vector(3 downto 0);
        imm2         : out std_logic_vector(15 downto 0);
        comp_bit2    : out std_logic;
        cz_bits2     : out std_logic_vector(1 downto 0);
        
        src1_reg2    : out std_logic_vector(2 downto 0); 
        src2_reg2    : out std_logic_vector(2 downto 0); 
        dest_reg2    : out std_logic_vector(2 downto 0); 
        
        reads_rs1_2  : out std_logic; 
        reads_rs2_2  : out std_logic; 
        we_gpr2      : out std_logic; 
        dest_is_r0_2 : out std_logic; 
        
        we_flag2     : out std_logic; 
        
        is_alu2      : out std_logic; 
        is_lsu2      : out std_logic; 
        is_branch2   : out std_logic; 
        is_multimem2 : out std_logic; 
        is_store2    : out std_logic;
        illegal_op2  : out std_logic;
        
        out_pred_taken2      : out std_logic;
        out_pred_target2     : out std_logic_vector(15 downto 0)
    );
end ID_stage;

architecture Behavioral of ID_stage is

    -- Internal decoder valid signals
    signal dec_valid1 : std_logic;
    signal dec_valid2 : std_logic;
    signal is_alu1_s, is_alu2_s : std_logic;
    
    signal op1_s : std_logic_vector(3 downto 0);
    signal src1_reg1_s, src2_reg1_s, dest_reg1_s: std_logic_vector(2 downto 0);
    signal imm1_s : std_logic_vector(15 downto 0);
    
    signal op2_s : std_logic_vector(3 downto 0);
    signal src1_reg2_s, src2_reg2_s, dest_reg2_s: std_logic_vector(2 downto 0);
    signal imm2_s : std_logic_vector(15 downto 0);

begin

    ------------------------------------------------------------------
    -- Decoder 1 Instantiation
    ------------------------------------------------------------------
    decoder_inst1 : entity work.instruction_decoder 
        port map(
            instr       => instruct1_in, 
            valid_in    => valid1_in, 
            valid_inst  => dec_valid1,
            illegal_op  => illegal_op1,
            opcode      => op1_s,
            src1_reg    => src1_reg1_s, 
            src2_reg    => src2_reg1_s, 
            dest_reg    => dest_reg1_s,
            reads_rs1   => reads_rs1_1,
            reads_rs2   => reads_rs2_1,
            we_gpr      => we_gpr1,
            dest_is_r0  => dest_is_r0_1,
            cz_bits     => cz_bits1,
            imm_ext     => imm1_s, 
            comp_bit    => comp_bit1, 
            is_alu      => is_alu1_s,
            is_lsu      => is_lsu1,
            is_branch   => is_branch1,
            is_multimem => is_multimem1,
            is_store    => is_store1
        );

    ------------------------------------------------------------------
    -- Decoder 2 Instantiation
    ------------------------------------------------------------------
    decoder_inst2 : entity work.instruction_decoder 
        port map(
            instr       => instruct2_in, 
            valid_in    => valid2_in, 
            valid_inst  => dec_valid2,
            illegal_op  => illegal_op2,
            opcode      => op2_s,
            src1_reg    => src1_reg2_s, 
            src2_reg    => src2_reg2_s, 
            dest_reg    => dest_reg2_s,
            reads_rs1   => reads_rs1_2,
            reads_rs2   => reads_rs2_2,
            we_gpr      => we_gpr2,
            dest_is_r0  => dest_is_r0_2,
            cz_bits     => cz_bits2,
            imm_ext     => imm2_s, 
            comp_bit    => comp_bit2, 
            is_alu      => is_alu2_s,
            is_lsu      => is_lsu2,
            is_branch   => is_branch2,
            is_multimem => is_multimem2,
            is_store    => is_store2
        );

    ------------------------------------------------------------------
    -- Direct Combinational Output Assignment
    ------------------------------------------------------------------
    -- If stalled from downstream, we drop valids
    op1_valid <= dec_valid1 when stall_fetch = '0' else '0';
    op2_valid <= dec_valid2 when stall_fetch = '0' else '0';
    
    pc1_out   <= pc1_in;
    pc2_out   <= pc2_in;
    is_alu1   <= is_alu1_s;
    is_alu2   <= is_alu2_s;
    op1 <= op1_s;
    op2 <= op2_s;
    src1_reg1 <= src1_reg1_s;
    src2_reg1 <= src2_reg1_s;
    src1_reg2 <= src1_reg2_s;
    src2_reg2 <= src2_reg2_s;
    imm1 <= imm1_s;
    imm2 <= imm2_s;
    dest_reg1 <= dest_reg1_s;
    dest_reg2 <= dest_reg2_s;
    
    we_flag1 <= '1' when (dec_valid1 = '1' and is_alu1_s = '1' and op1_s /= OP_LLI) else '0';
    we_flag2 <= '1' when (dec_valid2 = '1' and is_alu2_s = '1' and op2_s /= OP_LLI) else '0';
    
    out_pred_taken1      <= in_pred_taken1;
    out_pred_target1      <= in_pred_target1;
    out_pred_taken2      <= in_pred_taken2;
    out_pred_target2      <= in_pred_target2;

    -- =================================================================
    -- PROFESSIONAL X-RAY: WHAT IS THE DECODER EXTRACTING?
    -- =================================================================
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                if stall_fetch = '1' then
                    write(l, string'("[ID STAGE] STALLED  -> Holding instructions"));
                    writeline(output, l);
                else
                    if dec_valid1 = '1' then
                        write(l, string'("[ID STAGE] SLOT 1   -> PC: "));
                        write(l, integer'image(to_integer(unsigned(pc1_in))));
                        write(l, string'(" | OP: "));
                        write(l, integer'image(to_integer(unsigned(op1_s))));
                        write(l, string'(" | RS1: "));
                        write(l, integer'image(to_integer(unsigned(src1_reg1_s))));
                        write(l, string'(" | RS2: "));
                        write(l, integer'image(to_integer(unsigned(src2_reg1_s))));
                        write(l, string'(" | DEST: "));
                        write(l, integer'image(to_integer(unsigned(dest_reg1_s))));
                        write(l, string'(" | IMM: "));
                        -- Signed print for immediate! Fixes the 65504 vs -32 bug in traces!
                        write(l, integer'image(to_integer(signed(imm1_s)))); 
                        writeline(output, l);
                    end if;

                    if dec_valid2 = '1' then
                        write(l, string'("[ID STAGE] SLOT 2   -> PC: "));
                        write(l, integer'image(to_integer(unsigned(pc2_in))));
                        write(l, string'(" | OP: "));
                        write(l, integer'image(to_integer(unsigned(op2_s))));
                        write(l, string'(" | RS1: "));
                        write(l, integer'image(to_integer(unsigned(src1_reg2_s))));
                        write(l, string'(" | RS2: "));
                        write(l, integer'image(to_integer(unsigned(src2_reg2_s))));
                        write(l, string'(" | DEST: "));
                        write(l, integer'image(to_integer(unsigned(dest_reg2_s))));
                        write(l, string'(" | IMM: "));
                        write(l, integer'image(to_integer(signed(imm2_s))));
                        writeline(output, l);
                    end if;
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;