library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.iitb_risc_pkg.ALL; 

entity instruction_decoder is
    Port (
        instr      : in  std_logic_vector(15 downto 0); -- instruction in
        valid_in   : in  std_logic; -- valid 
        
        valid_inst : out std_logic; -- valid out
        illegal_op : out std_logic; -- OPcode is wrong 
        opcode     : out std_logic_vector(3 downto 0); -- 
        
        -- ==========================================
        -- UNIFIED REGISTER OPERANDS (For Rename Stage)
        -- ==========================================
        src1_reg   : out std_logic_vector(2 downto 0); -- ra
        src2_reg   : out std_logic_vector(2 downto 0); -- rb
        dest_reg   : out std_logic_vector(2 downto 0); -- rc
        
        reads_rs1  : out std_logic; -- reads ra
        reads_rs2  : out std_logic; -- reads rb
        we_gpr     : out std_logic; -- write physical reg
        dest_is_r0 : out std_logic; -- CRITICAL: Flags R0 writes for PC redirection 
        
        -- ==========================================
        -- FIRST-CLASS FLAG DEPENDENCIES
        -- ==========================================
        cz_bits : out std_logic_vector(1 downto 0);

        -- ==========================================
        -- PAYLOAD & DISPATCH ROUTING
        -- ==========================================
        imm_ext    : out std_logic_vector(15 downto 0); -- 16 bit imm extended
        comp_bit   : out std_logic; -- compliment bit
        
        is_alu     : out std_logic; -- alu operation
        is_lsu     : out std_logic; -- load store operation
        is_branch  : out std_logic; -- branch operation
        is_multimem: out std_logic; -- LM, SM, LMF, SMF (Sent to microcode cracker);
        
        is_store : out std_logic -- for memory write write enable;
    );
end instruction_decoder;

architecture Behavioral of instruction_decoder is
begin
    
    opcode <= instr(15 downto 12); -- 4 bit instruction extraction

    process(instr, valid_in)
        variable v_op : std_logic_vector(3 downto 0);
        variable v_ra : std_logic_vector(2 downto 0);
        variable v_rb : std_logic_vector(2 downto 0);
        variable v_rc : std_logic_vector(2 downto 0);
        variable v_cz : std_logic_vector(1 downto 0);
        variable v_we_gpr : std_logic;
        variable v_dest : std_logic_vector(2 downto 0);
    begin
        -- Extract fields
        v_op := instr(15 downto 12);
        v_ra := instr(11 downto 9);
        v_rb := instr(8 downto 6);
        v_rc := instr(5 downto 3);
        v_cz := instr(1 downto 0);

        -- Base defaults (assume nothing is read/written to prevent lockups)
        valid_inst  <= valid_in;
        illegal_op  <= '0';
        
        src1_reg    <= v_rb; -- Default RS1 is RB
        src2_reg    <= v_rc; -- Default RS2 is RC
        v_dest      := v_ra;
        v_we_gpr    := '0';
        
        reads_rs1   <= '0';
        reads_rs2   <= '0';
        
        cz_bits <= "00";
        
        is_alu      <= '0';
        is_lsu      <= '0';
        is_branch   <= '0';
        is_multimem <= '0';
        
        imm_ext     <= (others => '0');
        comp_bit    <= '0';
        is_store <= '0';
        
        if valid_in = '1' then
            case v_op is
                
                -- ======================================
                -- ADD FAMILY
                -- ======================================
                when OP_ADD =>
                    reads_rs1 <= '1';
                    reads_rs2 <= '1';
                    v_we_gpr  := '1';
                    v_dest    := v_ra; -- ADD writes to RA
                    
                    comp_bit  <= instr(2);
                    
                    -- Conditional Reads based on CZ bits
                    cz_bits <= instr(1 downto 0);
                    is_alu    <= '1';

                -- ======================================
                -- NAND FAMILY
                -- ======================================
                when OP_NDU =>
                    reads_rs1 <= '1';
                    reads_rs2 <= '1';
                    v_we_gpr  := '1';
                    v_dest    := v_ra; -- NDU writes to RA
                    
                    comp_bit  <= instr(2);
                    
                    cz_bits <= instr(1 downto 0);
                    is_alu    <= '1';

                -- ======================================
                -- ADI (Add Immediate)
                -- ======================================
                when OP_ADI =>
                    reads_rs1 <= '1'; -- Reads RA
                    v_we_gpr  := '1';
                    v_dest    := v_ra; -- ADI writes to RA!
                    
                    imm_ext   <= std_logic_vector(resize(signed(instr(5 downto 0)), 16));
                    is_alu    <= '1';

                -- ======================================
                -- LLI (Load Lower Immediate)
                -- ======================================
                when OP_LLI =>
                    v_we_gpr  := '1';
                    v_dest    := v_ra; -- LLI writes to RA
                    
                    -- Zero extend 9 bits
                    imm_ext   <= std_logic_vector(resize(unsigned(instr(8 downto 0)), 16));
                    is_alu    <= '1';

                -- ======================================
                -- LW / SW (Memory)
                -- ======================================
                when OP_LW =>
                    reads_rs2 <= '1'; -- Base address is RB
                    v_we_gpr  := '1';
                    v_dest    := v_ra; -- Load data into RA
                    
                    imm_ext   <= std_logic_vector(resize(signed(instr(5 downto 0)), 16));
                    is_lsu    <= '1';

                when OP_SW =>
                    reads_rs1 <= '1'; -- Data to store is RB
                    reads_rs2 <= '1'; -- Base address is RC
                    
                    imm_ext   <= std_logic_vector(resize(signed(instr(5 downto 0)), 16));
                    is_lsu    <= '1';
                    is_store  <= '1';
                -- ======================================
                -- LM / SM / LMF / SMF (Multi-Memory)
                -- ======================================
                when OP_LM | OP_SM =>
                    reads_rs1 <= '1'; -- Base is RB
                    -- We do not set v_we_gpr here. The Microcode Cracker will break this down.
                    imm_ext(8 downto 0) <= instr(8 downto 0); -- Pass the 8-bit mask
                    is_multimem <= '1';

                -- ======================================
                -- BRANCHES (BEQ, BLT, BLE)
                -- ======================================
                when OP_BEQ | OP_BLT | OP_BLE =>
                    reads_rs1 <= '1'; -- Compares RB
                    reads_rs2 <= '1'; -- against RC
                    
                    imm_ext   <= std_logic_vector(resize(signed(instr(5 downto 0)), 16));
                    is_branch <= '1';

                -- ======================================
                -- JUMPS (JAL, JLR, JRI)
                -- ======================================
                when OP_JAL =>
                    v_we_gpr  := '1';
                    v_dest    := v_ra; -- Saves PC+2 to RA
                    imm_ext   <= std_logic_vector(resize(signed(instr(8 downto 0)), 16));
                    is_branch <= '1';

                when OP_JLR =>
                    reads_rs2 <= '1'; -- Jumps to RB
                    v_we_gpr  := '1';
                    v_dest    := v_ra; -- Saves PC+2 to RA
                    is_branch <= '1';

                when OP_JRI =>
                    reads_rs1 <= '1'; -- Jumps to RA + imm
                    imm_ext   <= std_logic_vector(resize(signed(instr(8 downto 0)), 16));
                    is_branch <= '1';

                when others =>
                    illegal_op <= '1';
            end case;
        end if;

        -- Drive outputs
        we_gpr   <= v_we_gpr;
        dest_reg <= v_dest;
        
        -- CRITICAL: R0 Exception Rule (Section 32)
        if (v_we_gpr = '1' and v_dest = "000") then
            dest_is_r0 <= '1';
        else
            dest_is_r0 <= '0';
        end if;
        
    end process;
end Behavioral;