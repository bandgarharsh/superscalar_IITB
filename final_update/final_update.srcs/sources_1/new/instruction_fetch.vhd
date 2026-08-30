library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; 

-- MODULE: Instruction Fetch (IF) Stage
-- DESCRIPTION: 
--   Superscalar front-end fetch stage. Fetches two instructions simultaneously.
--   Integrates a Dual Branch Predictor to speculatively steer the Program Counter (PC).
--   Handles pipeline flushes from the ROB and front-end stalls from the ID queue.

entity instruction_fetch is
    Port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        -- Front-end control
        stall_fetch  : in  std_logic;
        sel          : in  std_logic_vector(1 downto 0);
        pc_bran      : in  std_logic_vector(15 downto 0);

        -- Two fetched instructions (Superscalar Output)
        instruct1    : out std_logic_vector(15 downto 0);
        instruct2    : out std_logic_vector(15 downto 0);

        -- PCs associated with the instructions
        pc1_out      : out std_logic_vector(15 downto 0);
        pc2_out      : out std_logic_vector(15 downto 0);

        -- Instruction validity masks
        valid1       : out std_logic;
        valid2       : out std_logic;

        -- Branch prediction interface (To ID Stage)
        pred_taken1  : out std_logic;
        pred_target1 : out std_logic_vector(15 downto 0);
        pred_taken2  : out std_logic;
        pred_target2 : out std_logic_vector(15 downto 0);

        
        -- Branch Predictor Update Interface (From ROB Commit)
        
        upd_pc       : in std_logic_vector(15 downto 0);
        upd_target   : in std_logic_vector(15 downto 0);
        upd_taken    : in std_logic;
        upd_is_cond  : in std_logic;
        upd_is_indir : in std_logic
    );
end instruction_fetch;

architecture Behavioral of instruction_fetch is

    -- Program Counter Signals
    signal pc_current : std_logic_vector(15 downto 0);
    signal pc2_s      : std_logic_vector(15 downto 0);
    signal pc_next    : std_logic_vector(15 downto 0);
    signal pc_seq     : std_logic_vector(15 downto 0);
    
    -- Raw Instructions from Memory
    signal instr1_mem : std_logic_vector(15 downto 0);
    signal instr2_mem : std_logic_vector(15 downto 0);

    -- Internal Predictor Signals
    signal sig_pred_taken1  : std_logic;
    signal sig_pred_target1 : std_logic_vector(15 downto 0);
    signal sig_pred_taken2  : std_logic;
    signal sig_pred_target2 : std_logic_vector(15 downto 0);

begin

    -- Slot 2 PC is implicitly Slot 1 PC + 2
    pc2_s <= std_logic_vector(unsigned(pc_current) + 2);

    
    -- DATAPATH INSTANTIATIONS
    
    
    -- Main PC Register
    u_pc_reg : entity work.pc_reg
        port map (
            clk    => clk,
            rst    => rst,
            pc_in  => pc_next,
            pc_out => pc_current
        );

    -- Sequential PC Adder (Calculates Default Next PC)
    u_pc_adder : entity work.pc_adder
        port map (
            pc     => pc_current,
            pc_out => pc_seq
        );

    -- Dual-Port Instruction Memory
    u_instruction_memory : entity work.instru_mem
        port map (
            addr      => pc_current,
            instruct1 => instr1_mem,
            instruct2 => instr2_mem
        );

    -- Dual Branch Predictor (Evaluates both instructions simultaneously)
    u_branch_predictor : entity work.dual_branch_predictor
        port map (
            clk          => clk,
            rst          => rst,
            
            -- Read Port 1 (Slot 1)
            pc1_in       => pc_current,
            instr1_in    => instr1_mem,
            pred_taken1  => sig_pred_taken1,
            pred_target1 => sig_pred_target1,
            
            -- Read Port 2 (Slot 2)
            pc2_in       => pc2_s,
            instr2_in    => instr2_mem,
            pred_taken2  => sig_pred_taken2,
            pred_target2 => sig_pred_target2,
            
            -- Update Port (From ROB Commit Stage)
            upd_pc       => upd_pc,
            upd_target   => upd_target,
            upd_taken    => upd_taken,
            upd_is_cond  => upd_is_cond,
            upd_is_indir => upd_is_indir
        );

    
    -- NEXT-PC SELECTION (Priority Steering Logic)
   
    process(sel, pc_seq, pc_bran, pc_current, stall_fetch, sig_pred_taken1, sig_pred_target1, sig_pred_taken2, sig_pred_target2)
    begin
        if sel = "01" then
            -- PRIORITY 1: ROB Flush (Mispredict recovery or R0 manual write)
            pc_next <= pc_bran;
            
        elsif stall_fetch = '1' then
            -- PRIORITY 2: Front-end stall (Hold PC due to queue pressure)
            pc_next <= pc_current;
            
        elsif sig_pred_taken1 = '1' then
            -- PRIORITY 3: Slot 1 Speculative Jump
            pc_next <= sig_pred_target1;
            
        elsif sig_pred_taken2 = '1' then
            -- PRIORITY 4: Slot 2 Speculative Jump
            pc_next <= sig_pred_target2;
            
        else
            -- PRIORITY 5: Default sequential fetch
            pc_next <= pc_seq;
        end if;
    end process;

    
    -- OUTPUT MAPPING & VALIDITY MASKING
    
    pc1_out <= pc_current;
    pc2_out <= pc2_s;
    
    instruct1 <= instr1_mem;
    instruct2 <= instr2_mem;
    
    -- Base validity
    valid1 <= not rst;
    
    -- "SLOT 2 KILL" RULE: If Slot 1 predicts a taken branch, 
    -- Slot 2 (which is sequential) is on the wrong path and must be dropped!
    valid2 <= (not rst) and (not sig_pred_taken1);

    pred_taken1  <= sig_pred_taken1;
    pred_target1 <= sig_pred_target1;
    pred_taken2  <= sig_pred_taken2;
    pred_target2 <= sig_pred_target2;

    
    -- PROFESSIONAL X-RAY LOGGING
    
    process(clk)
        variable l : line; 
    begin
        if rising_edge(clk) then
            if rst = '0' then
                
                if sel = "01" then
                    write(l, string'("[IF STAGE] FLUSHED  -> Redirecting PC to: "));
                    write(l, integer'image(to_integer(unsigned(pc_bran))));
                    writeline(output, l);
                    
                elsif stall_fetch = '1' then
                    write(l, string'("[IF STAGE] STALLED  -> Holding PC at: "));
                    write(l, integer'image(to_integer(unsigned(pc_current))));
                    writeline(output, l);
                    
                else
                    write(l, string'("[IF STAGE] FETCHING -> PC1: "));
                    write(l, integer'image(to_integer(unsigned(pc_current))));
                    write(l, string'(" (Inst: "));
                    write(l, integer'image(to_integer(unsigned(instr1_mem))));
                    
                    if sig_pred_taken1 = '1' then
                        write(l, string'(")[PRED JUMP]"));
                    else
                        write(l, string'(") | PC2: "));
                        write(l, integer'image(to_integer(unsigned(pc2_s))));
                        write(l, string'(" (Inst: "));
                        write(l, integer'image(to_integer(unsigned(instr2_mem))));
                        if sig_pred_taken2 = '1' then
                            write(l, string'(")[PRED JUMP]"));
                        else
                            write(l, string'(")"));
                        end if;
                    end if;
                    writeline(output, l);
                end if;
                
            end if;
        end if;
    end process;

end Behavioral;