library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dual_branch_predictor is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;

        -- =====================================================
        -- IF STAGE READ PORT 1 (Slot 1)
        -- =====================================================
        pc1_in      : in  STD_LOGIC_VECTOR(15 downto 0);
        instr1_in   : in  STD_LOGIC_VECTOR(15 downto 0);
        pred_taken1 : out STD_LOGIC;
        pred_target1: out STD_LOGIC_VECTOR(15 downto 0);

        -- =====================================================
        -- IF STAGE READ PORT 2 (Slot 2)
        -- =====================================================
        pc2_in      : in  STD_LOGIC_VECTOR(15 downto 0);
        instr2_in   : in  STD_LOGIC_VECTOR(15 downto 0);
        pred_taken2 : out STD_LOGIC;
        pred_target2: out STD_LOGIC_VECTOR(15 downto 0);

        -- =====================================================
        -- UPDATE PORT (Driven by ROB / Commit Stage)
        -- =====================================================
        upd_pc           : in STD_LOGIC_VECTOR(15 downto 0);
        upd_target       : in STD_LOGIC_VECTOR(15 downto 0);
        upd_taken        : in STD_LOGIC;
        upd_is_cond      : in STD_LOGIC; -- '1' if BEQ, BLT, BLE
        upd_is_indir     : in STD_LOGIC  -- '1' if JLR, JRI
    );
end dual_branch_predictor;

architecture Behavioral of dual_branch_predictor is
    -- Opcode constants
    constant OP_BEQ : STD_LOGIC_VECTOR(3 downto 0) := "1000";
    constant OP_BLT : STD_LOGIC_VECTOR(3 downto 0) := "1001";
    constant OP_BLE : STD_LOGIC_VECTOR(3 downto 0) := "1010";
    constant OP_JAL : STD_LOGIC_VECTOR(3 downto 0) := "1100";
    constant OP_JLR : STD_LOGIC_VECTOR(3 downto 0) := "1101";
    constant OP_JRI : STD_LOGIC_VECTOR(3 downto 0) := "1111";

    -- Slot 1 Decode
    signal op1 : STD_LOGIC_VECTOR(3 downto 0);
    signal is_jal1, is_jlr1, is_jri1, is_branch1 : STD_LOGIC;
    signal imm6_1, imm9_1 : STD_LOGIC_VECTOR(15 downto 0);
    signal btp_idx1 : integer range 0 to 63;
    signal btb_hit1 : STD_LOGIC;
    signal btb_tgt1 : STD_LOGIC_VECTOR(15 downto 0);

    -- Slot 2 Decode
    signal op2 : STD_LOGIC_VECTOR(3 downto 0);
    signal is_jal2, is_jlr2, is_jri2, is_branch2 : STD_LOGIC;
    signal imm6_2, imm9_2 : STD_LOGIC_VECTOR(15 downto 0);
    signal btp_idx2 : integer range 0 to 63;
    signal btb_hit2 : STD_LOGIC;
    signal btb_tgt2 : STD_LOGIC_VECTOR(15 downto 0);

    -- BTP : 64-entry 2-bit saturating direction predictor
    type btp_array is array (0 to 63) of STD_LOGIC_VECTOR(1 downto 0);
    signal btp_table : btp_array;
    signal upd_btp_idx : integer range 0 to 63;

    -- BTB : 4-entry fully associative
    type btb_valid_array is array (0 to 3) of STD_LOGIC;
    type btb_data_array  is array (0 to 3) of STD_LOGIC_VECTOR(15 downto 0);
    signal btb_valid : btb_valid_array;
    signal btb_tag   : btb_data_array;
    signal btb_mem   : btb_data_array;
    signal btb_rrptr : unsigned(1 downto 0);

begin
    -- =====================================================
    -- SLOT 1 COMBINATIONAL LOGIC
    -- =====================================================
    op1 <= instr1_in(15 downto 12);
    is_jal1    <= '1' when op1 = OP_JAL else '0';
    is_jlr1    <= '1' when op1 = OP_JLR else '0';
    is_jri1    <= '1' when op1 = OP_JRI else '0';
    is_branch1 <= '1' when (op1 = OP_BEQ or op1 = OP_BLT or op1 = OP_BLE) else '0';
    
    imm6_1 <= std_logic_vector(resize(signed(instr1_in(5 downto 0)),16));
    imm9_1 <= std_logic_vector(resize(signed(instr1_in(8 downto 0)),16));
    btp_idx1 <= to_integer(unsigned(pc1_in(6 downto 1)));

    process(pc1_in, btb_valid, btb_tag, btb_mem) begin
        btb_hit1 <= '0'; btb_tgt1 <= (others => '0');
        for i in 0 to 3 loop
            if btb_valid(i) = '1' and btb_tag(i) = pc1_in then
                btb_hit1 <= '1'; btb_tgt1 <= btb_mem(i);
            end if;
        end loop;
    end process;

    pred_taken1 <= is_jal1 or ((is_jlr1 or is_jri1) and btb_hit1) or (is_branch1 and btp_table(btp_idx1)(1));
    pred_target1 <= std_logic_vector(signed(pc1_in) + shift_left(signed(imm9_1), 1)) when is_jal1 = '1' else
                    btb_tgt1 when ((is_jlr1 = '1' or is_jri1 = '1') and btb_hit1 = '1') else
                    std_logic_vector(signed(pc1_in) + shift_left(signed(imm6_1), 1)) when (is_branch1 = '1' and btp_table(btp_idx1)(1) = '1') else
                    (others => '0');

    -- =====================================================
    -- SLOT 2 COMBINATIONAL LOGIC
    -- =====================================================
    op2 <= instr2_in(15 downto 12);
    is_jal2    <= '1' when op2 = OP_JAL else '0';
    is_jlr2    <= '1' when op2 = OP_JLR else '0';
    is_jri2    <= '1' when op2 = OP_JRI else '0';
    is_branch2 <= '1' when (op2 = OP_BEQ or op2 = OP_BLT or op2 = OP_BLE) else '0';
    
    imm6_2 <= std_logic_vector(resize(signed(instr2_in(5 downto 0)),16));
    imm9_2 <= std_logic_vector(resize(signed(instr2_in(8 downto 0)),16));
    btp_idx2 <= to_integer(unsigned(pc2_in(6 downto 1)));

    process(pc2_in, btb_valid, btb_tag, btb_mem) begin
        btb_hit2 <= '0'; btb_tgt2 <= (others => '0');
        for i in 0 to 3 loop
            if btb_valid(i) = '1' and btb_tag(i) = pc2_in then
                btb_hit2 <= '1'; btb_tgt2 <= btb_mem(i);
            end if;
        end loop;
    end process;

    pred_taken2 <= is_jal2 or ((is_jlr2 or is_jri2) and btb_hit2) or (is_branch2 and btp_table(btp_idx2)(1));
    pred_target2 <= std_logic_vector(signed(pc2_in) + shift_left(signed(imm9_2), 1)) when is_jal2 = '1' else
                    btb_tgt2 when ((is_jlr2 = '1' or is_jri2 = '1') and btb_hit2 = '1') else
                    std_logic_vector(signed(pc2_in) + shift_left(signed(imm6_2), 1)) when (is_branch2 = '1' and btp_table(btp_idx2)(1) = '1') else
                    (others => '0');

    -- =====================================================
    -- SEQUENTIAL UPDATES (From ROB/Backend)
    -- =====================================================
    upd_btp_idx <= to_integer(unsigned(upd_pc(6 downto 1)));

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                for i in 0 to 63 loop btp_table(i) <= "01"; end loop;
                for i in 0 to 3 loop btb_valid(i) <= '0'; end loop;
                btb_rrptr <= "00";
            else
                -- 1. Conditional Branch Update (BTP)
                if upd_is_cond = '1' then
                    if upd_taken = '1' then
                        if btp_table(upd_btp_idx) /= "11" then btp_table(upd_btp_idx) <= std_logic_vector(unsigned(btp_table(upd_btp_idx)) + 1); end if;
                    else
                        if btp_table(upd_btp_idx) /= "00" then btp_table(upd_btp_idx) <= std_logic_vector(unsigned(btp_table(upd_btp_idx)) - 1); end if;
                    end if;
                end if;

                -- 2. Indirect Jump Update (BTB)
                if upd_is_indir = '1' then
                    btb_valid(to_integer(btb_rrptr)) <= '1';
                    btb_tag(to_integer(btb_rrptr))   <= upd_pc;
                    btb_mem(to_integer(btb_rrptr))   <= upd_target;
                    btb_rrptr <= btb_rrptr + 1;
                end if;
            end if;
        end if;
    end process;
end Behavioral;