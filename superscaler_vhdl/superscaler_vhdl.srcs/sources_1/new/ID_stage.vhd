library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ID_stage is
    Port (
        instruct1_in : in  std_logic_vector(15 downto 0);
        instruct2_in : in  std_logic_vector(15 downto 0);

        op1          : out std_logic_vector(3 downto 0);
        ra1          : out std_logic_vector(2 downto 0);
        rb1          : out std_logic_vector(2 downto 0);
        rc1          : out std_logic_vector(2 downto 0);
        imm1         : out std_logic_vector(15 downto 0);
        comp_bit1    : out std_logic;
        cz_bits1     : out std_logic_vector(1 downto 0);

        op2          : out std_logic_vector(3 downto 0);
        ra2          : out std_logic_vector(2 downto 0);
        rb2          : out std_logic_vector(2 downto 0);
        rc2          : out std_logic_vector(2 downto 0);
        imm2         : out std_logic_vector(15 downto 0);
        comp_bit2    : out std_logic;
        cz_bits2     : out std_logic_vector(1 downto 0);

        route_inst1_tag_to_inst2_rb : out std_logic;
        route_inst1_tag_to_inst2_rc : out std_logic;
        inst2_overrides_rat         : out std_logic
    );
end ID_stage;

architecture Behavioral of ID_stage is

    signal valid1, valid2 : std_logic;

    signal inst1_writes_reg : std_logic;
    signal inst2_reads_rb   : std_logic;
    signal inst2_reads_rc   : std_logic;
    signal inst2_writes_reg : std_logic;
    
    signal op1_s, op2_s : std_logic_vector(3 downto 0);

    signal ra1_s, rb1_s, rc1_s : std_logic_vector(2 downto 0);
    signal ra2_s, rb2_s, rc2_s : std_logic_vector(2 downto 0);
    
    signal imm1_s, imm2_s : std_logic_vector(15 downto 0);
    
    signal comp_bit1_s, comp_bit2_s : std_logic;
    
    signal cz_bits1_s, cz_bits2_s : std_logic_vector(1 downto 0);
    
    
begin

    ------------------------------------------------------------------
    -- Decoder 1
    ------------------------------------------------------------------

    decoder_inst1 : entity work.instruction_decoder
        port map(
            instr      => instruct1_in,
            valid_inst => valid1,
            opcode => op1_s,
            ra => ra1_s,
            rb => rb1_s,
            rc => rc1_s,
            imm_ext => imm1_s,
            comp_bit => comp_bit1_s,
            cz_bits => cz_bits1_s
        );

    ------------------------------------------------------------------
    -- Decoder 2
    ------------------------------------------------------------------

    decoder_inst2 : entity work.instruction_decoder
        port map(
            instr      => instruct2_in,
            valid_inst => valid2,
            opcode => op2_s,
            ra => ra2_s,
            rb => rb2_s,
            rc => rc2_s,
            imm_ext => imm2_s,
            comp_bit => comp_bit2_s,
            cz_bits => cz_bits2_s
        );

    ------------------------------------------------------------------
    -- Dependency Detection
    ------------------------------------------------------------------

    inst1_writes_reg <= '1' when
    (op1_s = "0001") or
    (op1_s = "0010") or
    (op1_s = "0100") or
    (op1_s = "0011")
    else
        '0';
    
    inst2_reads_rb <= '1' when
        (op2_s = "0001") or
        (op2_s = "1000")
    else
        '0';
    
    inst2_reads_rc <= '1' when
        (op2_s = "0001") or
        (op2_s = "0010")
    else
        '0';
    
    inst2_writes_reg <= '1' when
        (op2_s = "0001") or
        (op2_s = "0010") or
        (op2_s = "0100") or
        (op2_s = "0011")
    else
        '0';
    
    route_inst1_tag_to_inst2_rb <= '1' when
        (valid1 = '1') and
        (valid2 = '1') and
        (inst1_writes_reg = '1') and
        (inst2_reads_rb = '1') and
        (ra1_s = rb2_s)
    else
        '0';
    
    route_inst1_tag_to_inst2_rc <= '1' when
        (valid1 = '1') and
        (valid2 = '1') and
        (inst1_writes_reg = '1') and
        (inst2_reads_rc = '1') and
        (ra1_s = rc2_s)
    else
        '0';
    
    inst2_overrides_rat <= '1' when
        (valid1 = '1') and
        (valid2 = '1') and
        (inst1_writes_reg = '1') and
        (inst2_writes_reg = '1') and
        (ra1_s = ra2_s)
    else
        '0';

    
    op1 <= op1_s;
    ra1 <= ra1_s;
    rb1 <= rb1_s;
    rc1 <= rc1_s;
    imm1 <= imm1_s;
    comp_bit1 <= comp_bit1_s;
    cz_bits1 <= cz_bits1_s;
    
    op2 <= op2_s;
    ra2 <= ra2_s;
    rb2 <= rb2_s;
    rc2 <= rc2_s;
    imm2 <= imm2_s;
    comp_bit2 <= comp_bit2_s;
    cz_bits2 <= cz_bits2_s;

end Behavioral;