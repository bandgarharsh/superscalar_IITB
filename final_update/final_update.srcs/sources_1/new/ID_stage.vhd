library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use work.iitb_risc_pkg.ALL;


-- MODULE: Instruction Decode (ID) & Micro-op FSM
-- DESCRIPTION: 
--   Superscalar decode stage. Converts architectural instructions into internal 
--   micro-operations (uops). Implements an advanced Mealy FSM (FSMD) to dynamically 
--   expand Load Multiple (LM) and Store Multiple (SM) instructions into individual 
--   uops while preserving superscalar instruction order using a Skid Buffer queue.

entity ID_stage is
    Port (
        clk          : in std_logic; 
        rst          : in std_logic; 
        stall_fetch  : in std_logic; 
        id_stall_out : out std_logic; 
        global_flush : in std_logic;
        
        valid1_in    : in std_logic; valid2_in : in std_logic; 
        pc1_in       : in std_logic_vector(15 downto 0); pc2_in : in std_logic_vector(15 downto 0);
        instruct1_in : in std_logic_vector(15 downto 0); instruct2_in : in std_logic_vector(15 downto 0);
        in_pred_taken1  : in std_logic; in_pred_target1 : in std_logic_vector(15 downto 0);
        in_pred_taken2  : in std_logic; in_pred_target2 : in std_logic_vector(15 downto 0);
        
        -- SLOT 1 OUTPUTS
        op1_valid : out std_logic; pc1_out : out std_logic_vector(15 downto 0); op1 : out std_logic_vector(3 downto 0); imm1 : out std_logic_vector(15 downto 0);
        comp_bit1 : out std_logic; cz_bits1 : out std_logic_vector(1 downto 0); src1_reg1 : out std_logic_vector(2 downto 0); src2_reg1 : out std_logic_vector(2 downto 0); dest_reg1 : out std_logic_vector(2 downto 0); 
        reads_rs1_1 : out std_logic; reads_rs2_1 : out std_logic; we_gpr1 : out std_logic; dest_is_r0_1 : out std_logic; we_flag1 : out std_logic; 
        is_alu1 : out std_logic; is_lsu1 : out std_logic; is_branch1 : out std_logic; is_multimem1 : out std_logic; is_store1 : out std_logic; illegal_op1 : out std_logic;
        out_pred_taken1 : out std_logic; out_pred_target1 : out std_logic_vector(15 downto 0);
        
        -- SLOT 2 OUTPUTS
        op2_valid : out std_logic; pc2_out : out std_logic_vector(15 downto 0); op2 : out std_logic_vector(3 downto 0); imm2 : out std_logic_vector(15 downto 0);
        comp_bit2 : out std_logic; cz_bits2 : out std_logic_vector(1 downto 0); src1_reg2 : out std_logic_vector(2 downto 0); src2_reg2 : out std_logic_vector(2 downto 0); dest_reg2 : out std_logic_vector(2 downto 0); 
        reads_rs1_2 : out std_logic; reads_rs2_2 : out std_logic; we_gpr2 : out std_logic; dest_is_r0_2 : out std_logic; we_flag2 : out std_logic; 
        is_alu2 : out std_logic; is_lsu2 : out std_logic; is_branch2 : out std_logic; is_multimem2 : out std_logic; is_store2 : out std_logic; illegal_op2 : out std_logic;
        out_pred_taken2 : out std_logic; out_pred_target2 : out std_logic_vector(15 downto 0)
    );
end ID_stage;

architecture Behavioral of ID_stage is
    -- Decoder Signals
    signal dec_valid1, dec_valid2 : std_logic;
    signal is_alu1_s, is_alu2_s, is_lsu1_s, is_lsu2_s, is_branch1_s, is_branch2_s, is_store1_s, is_store2_s, is_multimem1_s, is_multimem2_s : std_logic;
    signal op1_s, op2_s : std_logic_vector(3 downto 0);
    signal src1_reg1_s, src2_reg1_s, dest_reg1_s, src1_reg2_s, src2_reg2_s, dest_reg2_s: std_logic_vector(2 downto 0);
    signal imm1_s, imm2_s : std_logic_vector(15 downto 0);
    signal we_gpr1_s, we_gpr2_s, we_flag1_s, we_flag2_s, reads_rs1_1_s, reads_rs2_1_s, reads_rs1_2_s, reads_rs2_2_s, dest_is_r0_1_s, dest_is_r0_2_s, comp_bit1_s, comp_bit2_s, illegal_op1_s, illegal_op2_s : std_logic;
    signal cz_bits1_s, cz_bits2_s : std_logic_vector(1 downto 0);

    -- Internal UOP Record Type for clean data packaging inside the queue
    type uop_t is record
        valid : std_logic; pc : std_logic_vector(15 downto 0); op : std_logic_vector(3 downto 0); imm : std_logic_vector(15 downto 0);
        comp_bit : std_logic; cz_bits : std_logic_vector(1 downto 0); src1_reg, src2_reg, dest_reg : std_logic_vector(2 downto 0);
        reads_rs1, reads_rs2, we_gpr, dest_is_r0, we_flag : std_logic;
        is_alu, is_lsu, is_branch, is_multimem, is_store, illegal_op : std_logic; pred_taken : std_logic; pred_target : std_logic_vector(15 downto 0);
    end record;

    constant NULL_UOP : uop_t := (
        valid => '0', pc => (others=>'0'), op => (others=>'0'), imm => (others=>'0'), comp_bit => '0', cz_bits => "00", 
        src1_reg => "000", src2_reg => "000", dest_reg => "000", reads_rs1 => '0', reads_rs2 => '0', we_gpr => '0', 
        dest_is_r0 => '0', we_flag => '0', is_alu => '0', is_lsu => '0', is_branch => '0', is_multimem => '0', 
        is_store => '0', illegal_op => '0', pred_taken => '0', pred_target => (others=>'0')
    );

    signal dec1_uop, dec2_uop, out_uop1, out_uop2 : uop_t;
    
    -- Anti-Lag PC Filter (Prevents re-processing trapped instructions during stall)
    signal valid1_s, valid2_s, is_multi1, is_multi2 : std_logic;
    signal last_multi_pc1 : std_logic_vector(15 downto 0) := (others => '1');
    signal last_multi_pc2 : std_logic_vector(15 downto 0) := (others => '1');

    -- Skid Buffer / Decode Queue
    type fifo_array_t is array(0 to 15) of uop_t;
    signal q_mem : fifo_array_t;
    signal head, tail : unsigned(3 downto 0) := "0000";
    signal q_count : integer range 0 to 16 := 0;
    signal local_pop_sig : integer range 0 to 2 := 0;

    -- Mealy FSMD States & Datapath Registers
    type state_t is (IDLE, PUSH_S1, EXPAND_S1, PUSH_S2, EXPAND_S2);
    signal state : state_t := IDLE;
    
    signal hold1, hold2 : uop_t;
    signal hold_m1, hold_m2 : std_logic;
    signal mask_reg : std_logic_vector(8 downto 0);
    signal offset_reg : unsigned(15 downto 0);
    signal idx1, idx2 : integer range 0 to 9;
    signal next_mask_comb : std_logic_vector(8 downto 0);

    -- Helper function to pack standard signals into a UOP record
    function pack_uop(v: std_logic; pc: std_logic_vector; op: std_logic_vector; imm: std_logic_vector; comp: std_logic; cz: std_logic_vector; rs1, rs2, rd: std_logic_vector; r_rs1, r_rs2, w_gpr, d_r0, w_flag: std_logic; i_alu, i_lsu, i_br, i_multi, i_st, ill: std_logic; pt: std_logic; ptar: std_logic_vector) return uop_t is
        variable res : uop_t;
    begin
        res.valid := v; res.pc := pc; res.op := op; res.imm := imm; res.comp_bit := comp; res.cz_bits := cz; res.src1_reg := rs1; res.src2_reg := rs2; res.dest_reg := rd; res.reads_rs1 := r_rs1; res.reads_rs2 := r_rs2; res.we_gpr := w_gpr; res.dest_is_r0 := d_r0; res.we_flag := w_flag; res.is_alu := i_alu; res.is_lsu := i_lsu; res.is_branch := i_br; res.is_multimem := i_multi; res.is_store := i_st; res.illegal_op := ill; res.pred_taken := pt; res.pred_target := ptar; return res;
    end function;


    -- MULTI-MEM MICRO-OP GENERATOR
    -- Transforms a single LM/SM into precise individual Load/Store uops.
    -- Explicitly handles the Flag loading condition (LMF) if the 9th bit is set.

    function format_micro_op(hold : uop_t; idx : integer; offset : unsigned) return uop_t is
        variable res : uop_t := hold;
    begin
        -- Force the uop to be a memory instruction
        res.is_alu := '0'; res.is_lsu := '1'; res.is_branch := '0'; res.is_multimem := '0'; res.illegal_op := '0';
        res.reads_rs1 := '1'; res.comp_bit := '0'; res.dest_is_r0 := '0'; res.pred_taken := '0'; res.pred_target := (others=>'0');
        res.imm := std_logic_vector(offset); -- Assign correctly calculated offset
        
        if hold.op = OP_LM then res.op := OP_LW; res.is_store := '0'; res.reads_rs2 := '0'; 
        else res.op := OP_SW; res.is_store := '1'; res.reads_rs2 := '1'; end if;
        
        if idx = 8 then
            -- FLAG OPERATION (LMF): Dedicated uop that only writes to the Flag Register
            res.cz_bits := "11"; res.dest_reg := "000"; res.src2_reg := "000";
            if hold.op = OP_LM then res.we_flag := '1'; res.we_gpr := '0'; else res.we_flag := '0'; res.we_gpr := '0'; end if;
        else
            -- NORMAL GPR OPERATION
            res.cz_bits := "00"; res.we_flag := '0';
            if hold.op = OP_LM then res.dest_reg := std_logic_vector(to_unsigned(idx, 3)); res.src2_reg := "000"; res.we_gpr := '1';
            else res.dest_reg := "000"; res.src2_reg := std_logic_vector(to_unsigned(idx, 3)); res.we_gpr := '0'; end if;
        end if;
        return res;
    end function;

begin

    -- INSTANTIATE DUAL INSTRUCTION DECODERS

    decoder_inst1 : entity work.instruction_decoder port map(instr => instruct1_in, valid_in => valid1_in, valid_inst => dec_valid1, illegal_op => illegal_op1_s, opcode => op1_s, src1_reg => src1_reg1_s, src2_reg => src2_reg1_s, dest_reg => dest_reg1_s, reads_rs1 => reads_rs1_1_s, reads_rs2 => reads_rs2_1_s, we_gpr => we_gpr1_s, we_flag => we_flag1_s, dest_is_r0 => dest_is_r0_1_s, cz_bits => cz_bits1_s, imm_ext => imm1_s, comp_bit => comp_bit1_s, is_alu => is_alu1_s, is_lsu => is_lsu1_s, is_branch => is_branch1_s, is_multimem => is_multimem1_s, is_store => is_store1_s);
    decoder_inst2 : entity work.instruction_decoder port map(instr => instruct2_in, valid_in => valid2_in, valid_inst => dec_valid2, illegal_op => illegal_op2_s, opcode => op2_s, src1_reg => src1_reg2_s, src2_reg => src2_reg2_s, dest_reg => dest_reg2_s, reads_rs1 => reads_rs1_2_s, reads_rs2 => reads_rs2_2_s, we_gpr => we_gpr2_s, we_flag => we_flag2_s, dest_is_r0 => dest_is_r0_2_s, cz_bits => cz_bits2_s, imm_ext => imm2_s, comp_bit => comp_bit2_s, is_alu => is_alu2_s, is_lsu => is_lsu2_s, is_branch => is_branch2_s, is_multimem => is_multimem2_s, is_store => is_store2_s);

    -- Anti-Lag filter: Ensures an instruction is only processed once if the pipeline stalls
    valid1_s <= '1' when dec_valid1 = '1' and pc1_in /= last_multi_pc1 else '0';
    valid2_s <= '1' when dec_valid2 = '1' and pc2_in /= last_multi_pc2 else '0';

    is_multi1 <= '1' when valid1_s = '1' and (op1_s = OP_LM or op1_s = OP_SM) else '0';
    is_multi2 <= '1' when valid2_s = '1' and (op2_s = OP_LM or op2_s = OP_SM) else '0';
    
    dec1_uop <= pack_uop(valid1_s, pc1_in, op1_s, imm1_s, comp_bit1_s, cz_bits1_s, src1_reg1_s, src2_reg1_s, dest_reg1_s, reads_rs1_1_s, reads_rs2_1_s, we_gpr1_s, dest_is_r0_1_s, we_flag1_s, is_alu1_s, is_lsu1_s, is_branch1_s, is_multimem1_s, is_store1_s, illegal_op1_s, in_pred_taken1, in_pred_target1);
    dec2_uop <= pack_uop(valid2_s, pc2_in, op2_s, imm2_s, comp_bit2_s, cz_bits2_s, src1_reg2_s, src2_reg2_s, dest_reg2_s, reads_rs1_2_s, reads_rs2_2_s, we_gpr2_s, dest_is_r0_2_s, we_flag2_s, is_alu2_s, is_lsu2_s, is_branch2_s, is_multimem2_s, is_store2_s, illegal_op2_s, in_pred_taken2, in_pred_target2);

    -- Priority Encoder: Scans the Multi-Mem mask to find the lowest two active bits
    process(mask_reg) variable found1, found2 : integer range 0 to 9; begin
        found1 := 9; found2 := 9;
        for i in 7 downto 0 loop 
            if mask_reg(i) = '1' then 
                if found1 = 9 then found1 := 7 - i; elsif found2 = 9 then found2 := 7 - i; end if; 
            end if; 
        end loop;
        if mask_reg(8) = '1' then
            if found1 = 9 then found1 := 8; elsif found2 = 9 then found2 := 8; end if;
        end if;
        idx1 <= found1; idx2 <= found2;
    end process;

    -- Clears the mask bits that were successfully encoded
    process(mask_reg, idx1, idx2) variable n_mask : std_logic_vector(8 downto 0); begin
        n_mask := mask_reg; 
        if idx1 /= 9 then if idx1 = 8 then n_mask(8) := '0'; else n_mask(7 - idx1) := '0'; end if; end if; 
        if idx2 /= 9 then if idx2 = 8 then n_mask(8) := '0'; else n_mask(7 - idx2) := '0'; end if; end if; 
        next_mask_comb <= n_mask;
    end process;

    -- Continuous POP Engine (Driven by downstream availability)
    process(q_count, stall_fetch) begin
        if stall_fetch = '0' then
            if q_count >= 2 then local_pop_sig <= 2;
            elsif q_count = 1 then local_pop_sig <= 1; 
            else local_pop_sig <= 0; end if;
        else 
            local_pop_sig <= 0; 
        end if;
    end process;


    -- 0-CYCLE COMBINATIONAL BYPASS
    -- Eliminates queue latency for standard scalar instructions, dramatically 
    -- reducing IPC loss when the pipeline is flowing freely.

    process(q_count, q_mem, head, dec1_uop, dec2_uop, is_multi1, is_multi2, state, stall_fetch) begin
        out_uop1 <= NULL_UOP; out_uop2 <= NULL_UOP;
        
        if q_count >= 2 then 
            out_uop1 <= q_mem(to_integer(head)); 
            out_uop2 <= q_mem(to_integer(head + 1)); 
        elsif q_count = 1 then
            out_uop1 <= q_mem(to_integer(head));
        -- Bypass Condition: Queue Empty, FSM Idle, No Multi-Mems, No Downstream Stall
        elsif q_count = 0 and state = IDLE and stall_fetch = '0' then
            if is_multi1 = '0' and is_multi2 = '0' then
                out_uop1 <= dec1_uop;
                out_uop2 <= dec2_uop;
            end if;
        end if;
    end process;


    -- MEALY FSMD: MULTI-MEM EXPANSION & SKID BUFFER
    -- Acts as both a Skid Buffer during stalls and a state machine for LM/SM expansion.

    process(clk) variable pop_cnt, push_cnt, q_free : integer; begin
        if rising_edge(clk) then
            if rst = '1' or global_flush = '1' then 
                state <= IDLE; head <= "0000"; tail <= "0000"; q_count <= 0;
                last_multi_pc1 <= (others => '1'); last_multi_pc2 <= (others => '1');
            else
                pop_cnt := local_pop_sig; push_cnt := 0; q_free := 16 - (q_count - pop_cnt);

                -- Wipe the anti-lag PC filter when IF provides completely new instructions
                if state = IDLE and valid1_in = '1' and pc1_in /= last_multi_pc1 then
                    last_multi_pc1 <= (others => '1'); last_multi_pc2 <= (others => '1');
                end if;

                if state = IDLE then
                    if is_multi1 = '1' or is_multi2 = '1' then
                        -- ORDER PRESERVATION: Lock both into hold registers to maintain program order
                        hold1 <= dec1_uop; hold2 <= dec2_uop; hold_m1 <= is_multi1; hold_m2 <= is_multi2;
                        last_multi_pc1 <= pc1_in; last_multi_pc2 <= pc2_in; 
                        
                        if is_multi1 = '1' then 
                            state <= EXPAND_S1; mask_reg <= imm1_s(8 downto 0); offset_reg <= (others=>'0');
                        else 
                            state <= PUSH_S1; 
                        end if;
                    else
                        if stall_fetch = '1' then
                            -- Skid Buffer push logic when downstream pipeline is blocked
                            if valid1_s = '1' and valid2_s = '1' then
                                if q_free >= 2 then
                                    q_mem(to_integer(tail)) <= dec1_uop; q_mem(to_integer(tail+1)) <= dec2_uop; push_cnt := 2;
                                end if;
                            elsif valid1_s = '1' and valid2_s = '0' then
                                if q_free >= 1 then 
                                    q_mem(to_integer(tail)) <= dec1_uop; push_cnt := 1; 
                                end if;
                            end if;
                        else
                            push_cnt := 0; 
                        end if;
                    end if;

                elsif state = PUSH_S1 then
                    if stall_fetch = '0' then 
                        if hold1.valid = '1' then q_mem(to_integer(tail)) <= hold1; push_cnt := 1; end if;
                        if hold_m2 = '1' then 
                            state <= EXPAND_S2; mask_reg <= hold2.imm(8 downto 0); offset_reg <= (others=>'0');
                        else 
                            state <= PUSH_S2; 
                        end if;
                    end if;

                elsif state = EXPAND_S1 then
                    if stall_fetch = '0' then 
                        if mask_reg = "000000000" then
                            if hold_m2 = '1' then 
                                state <= EXPAND_S2; mask_reg <= hold2.imm(8 downto 0); offset_reg <= (others=>'0');
                            else 
                                state <= PUSH_S2; 
                            end if;
                        else
                            if idx1 /= 9 then
                                q_mem(to_integer(tail)) <= format_micro_op(hold1, idx1, offset_reg); 
                                if idx2 /= 9 then 
                                    q_mem(to_integer(tail + 1)) <= format_micro_op(hold1, idx2, offset_reg + 1); 
                                    push_cnt := 2; 
                                    offset_reg <= offset_reg + 2;
                                else 
                                    push_cnt := 1; 
                                    offset_reg <= offset_reg + 1;
                                end if;
                            end if;
                            
                            if next_mask_comb = "000000000" then
                                if hold_m2 = '1' then 
                                    state <= EXPAND_S2; mask_reg <= hold2.imm(8 downto 0); offset_reg <= (others=>'0');
                                else 
                                    state <= PUSH_S2; 
                                end if;
                            else 
                                mask_reg <= next_mask_comb; 
                            end if;
                        end if;
                    end if;

                elsif state = PUSH_S2 then
                    if stall_fetch = '0' then 
                        if hold2.valid = '1' then q_mem(to_integer(tail)) <= hold2; push_cnt := 1; end if;
                        state <= IDLE;
                    end if;

                elsif state = EXPAND_S2 then
                    if stall_fetch = '0' then 
                        if mask_reg = "000000000" then 
                            state <= IDLE;
                        else
                            if idx1 /= 9 then
                                q_mem(to_integer(tail)) <= format_micro_op(hold2, idx1, offset_reg); 
                                if idx2 /= 9 then 
                                    q_mem(to_integer(tail + 1)) <= format_micro_op(hold2, idx2, offset_reg + 1); 
                                    push_cnt := 2; 
                                    offset_reg <= offset_reg + 2;
                                else 
                                    push_cnt := 1; 
                                    offset_reg <= offset_reg + 1;
                                end if;
                            end if;
                            
                            if next_mask_comb = "000000000" then 
                                state <= IDLE;
                            else 
                                mask_reg <= next_mask_comb; 
                            end if;
                        end if;
                    end if;
                end if;

                head <= head + pop_cnt; tail <= tail + push_cnt; q_count <= q_count + push_cnt - pop_cnt;
            end if;
        end if;
    end process;

    -- Freeze Fetch Stage if FSM is busy generating uops, or if a Multi-Mem is detected.
    id_stall_out <= '1' when (stall_fetch = '1') or (state /= IDLE) or (is_multi1 = '1' or is_multi2 = '1') else '0';

 
    -- FINAL PORT MAPPING (Data sent to Rename Stage)

    op1_valid <= out_uop1.valid; pc1_out <= out_uop1.pc; op1 <= out_uop1.op; imm1 <= out_uop1.imm; comp_bit1 <= out_uop1.comp_bit; cz_bits1 <= out_uop1.cz_bits; src1_reg1 <= out_uop1.src1_reg; src2_reg1 <= out_uop1.src2_reg; dest_reg1 <= out_uop1.dest_reg; reads_rs1_1 <= out_uop1.reads_rs1; reads_rs2_1 <= out_uop1.reads_rs2; we_gpr1 <= out_uop1.we_gpr; dest_is_r0_1 <= out_uop1.dest_is_r0; we_flag1 <= out_uop1.we_flag; is_alu1 <= out_uop1.is_alu; is_lsu1 <= out_uop1.is_lsu; is_branch1 <= out_uop1.is_branch; is_multimem1 <= out_uop1.is_multimem; is_store1 <= out_uop1.is_store; illegal_op1 <= out_uop1.illegal_op; out_pred_taken1 <= out_uop1.pred_taken; out_pred_target1 <= out_uop1.pred_target;
    op2_valid <= out_uop2.valid; pc2_out <= out_uop2.pc; op2 <= out_uop2.op; imm2 <= out_uop2.imm; comp_bit2 <= out_uop2.comp_bit; cz_bits2 <= out_uop2.cz_bits; src1_reg2 <= out_uop2.src1_reg; src2_reg2 <= out_uop2.src2_reg; dest_reg2 <= out_uop2.dest_reg; reads_rs1_2 <= out_uop2.reads_rs1; reads_rs2_2 <= out_uop2.reads_rs2; we_gpr2 <= out_uop2.we_gpr; dest_is_r0_2 <= out_uop2.dest_is_r0; we_flag2 <= out_uop2.we_flag; is_alu2 <= out_uop2.is_alu; is_lsu2 <= out_uop2.is_lsu; is_branch2 <= out_uop2.is_branch; is_multimem2 <= out_uop2.is_multimem; is_store2 <= out_uop2.is_store; illegal_op2 <= out_uop2.illegal_op; out_pred_taken2 <= out_uop2.pred_taken; out_pred_target2 <= out_uop2.pred_target;


    -- PROFESSIONAL X-RAY LOGGING (FSM & SKID STATE)
    
    process(clk) 
        variable l : line; 
        variable state_str : string(1 to 9);
    begin
        if rising_edge(clk) then
            if rst = '0' then
                if state = IDLE then state_str := "IDLE     ";
                elsif state = EXPAND_S1 then state_str := "EXPAND_S1";
                elsif state = EXPAND_S2 then state_str := "EXPAND_S2";
                elsif state = PUSH_S1 then state_str := "PUSH_S1  ";
                elsif state = PUSH_S2 then state_str := "PUSH_S2  ";
                end if;

                write(l, string'("=================================================================")); writeline(output, l);
                write(l, string'("[ID X-RAY TRACE] State: ")); write(l, state_str);
                write(l, string'(" | Queue Count: ")); write(l, integer'image(q_count));
                write(l, string'(" | Stall Fetch: ")); write(l, std_logic'image(stall_fetch));
                writeline(output, l);
                
                write(l, string'("  -> Incoming PC1: ")); write(l, integer'image(to_integer(unsigned(pc1_in))));
                write(l, string'(" | Multi1: ")); write(l, std_logic'image(is_multi1));
                write(l, string'("  -> Incoming PC2: ")); write(l, integer'image(to_integer(unsigned(pc2_in))));
                write(l, string'(" | Multi2: ")); write(l, std_logic'image(is_multi2));
                writeline(output, l);

                if state /= IDLE then
                    write(l, string'("  -> FSM Active | Mask Reg: ")); 
                    for i in 8 downto 0 loop
                        if mask_reg(i) = '1' then write(l, string'("1")); else write(l, string'("0")); end if;
                    end loop;
                    write(l, string'(" | Offset: ")); write(l, integer'image(to_integer(offset_reg)));
                    write(l, string'(" | Idx1: ")); write(l, integer'image(idx1));
                    write(l, string'(" | Idx2: ")); write(l, integer'image(idx2));
                    writeline(output, l);
                end if;

                if q_count > 0 then
                    write(l, string'("  -> Queue Status | Head: ")); write(l, integer'image(to_integer(head)));
                    write(l, string'(" | Tail: ")); write(l, integer'image(to_integer(tail)));
                    write(l, string'(" | Pop Sig: ")); write(l, integer'image(local_pop_sig));
                    writeline(output, l);
                elsif state = IDLE and is_multi1 = '0' and is_multi2 = '0' and stall_fetch = '0' then
                    write(l, string'("  -> Routing: 0-Cycle Combinational Bypass Active.")); writeline(output, l);
                end if;
                write(l, string'("=================================================================")); writeline(output, l);
            end if;
        end if;
    end process;
end Behavioral;