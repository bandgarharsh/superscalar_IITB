library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity superscalar_core is
    Port (
        clk : in std_logic;
        rst : in std_logic
    );
end superscalar_core;

architecture Structural of superscalar_core is

    -- =========================================================
    -- 1. GLOBAL PIPELINE SIGNALS
    -- =========================================================
    signal flush_pipeline : std_logic;
    signal flush_pc       : std_logic_vector(15 downto 0);
    signal dispatch_stall : std_logic;

    -- =========================================================
    -- 2. DISPATCH TO RS SIGNALS (The 64-bit Packets)
    -- =========================================================
    signal rs_packet1, rs_packet2 : std_logic_vector(63 downto 0);
    signal rob_packet1, rob_packet2 : std_logic_vector(44 downto 0);
    
    signal alu_we1, alu_we2 : std_logic;
    signal br_we1, br_we2   : std_logic;
    signal lsq_we1, lsq_we2 : std_logic;
    
    signal rs_alu_full, rs_br_full, rs_lsq_full : std_logic;
    signal rob_free_slots : unsigned(5 downto 0);

    -- =========================================================
    -- 3. CDB SIGNALS (From ALUs to RS/ROB)
    -- =========================================================
    signal cdb1_valid : std_logic;
    signal cdb1_tag   : std_logic_vector(4 downto 0);
    signal cdb1_data  : std_logic_vector(15 downto 0);
    signal cdb1_flags : std_logic_vector(1 downto 0);
    
    signal cdb2_valid : std_logic;
    signal cdb2_tag   : std_logic_vector(4 downto 0);
    signal cdb2_data  : std_logic_vector(15 downto 0);
    signal cdb2_flags : std_logic_vector(1 downto 0);

begin

    -- =========================================================
    -- [PLACEHOLDER] FETCH, DECODE, RENAME STAGES
    -- =========================================================
    -- Here we will instantiate instruction_fetch, IF_ID, 
    -- instruction_decoder, and RR_stage. They will output the
    -- renamed micro-ops directly into the dispatch_stage.
    
    
    -- =========================================================
    -- DISPATCH STAGE & LATCH
    -- =========================================================
    dispatch_inst : entity work.dispatch_stage
        port map (
            clk => clk, rst => rst,
            
            -- [Connect inputs from RR_stage here]

            rob_free_slots => rob_free_slots,
            rs_alu_full => rs_alu_full,
            rs_mem_full => rs_lsq_full,
            rs_br_full  => rs_br_full,
            
            dispatch_stall => dispatch_stall,
            
            rs_packet1 => rs_packet1, rs_packet2 => rs_packet2,
            rob_packet1 => rob_packet1, rob_packet2 => rob_packet2,
            
            rs_alu_valid1 => alu_we1, rs_alu_valid2 => alu_we2,
            rs_br_valid1  => br_we1,  rs_br_valid2  => br_we2,
            rs_mem_valid1 => lsq_we1, rs_mem_valid2 => lsq_we2
        );
        
    -- =========================================================
    -- RESERVATION STATIONS (The Queues)
    -- =========================================================
    alu_rs_inst : entity work.arithmetic_rs
        port map (
            clk => clk, rst => rst, flush => flush_pipeline,
            
            -- Dispatch Inputs
            we1 => alu_we1, rs_packet1 => rs_packet1, -- (Plus valid data signals from Latch)
            we2 => alu_we2, rs_packet2 => rs_packet2, -- (Plus valid data signals from Latch)
            
            -- CDB Snooping
            cdb1_valid => cdb1_valid, cdb1_tag => cdb1_tag, cdb1_data => cdb1_data, cdb1_flags => cdb1_flags,
            cdb2_valid => cdb2_valid, cdb2_tag => cdb2_tag, cdb2_data => cdb2_data, cdb2_flags => cdb2_flags
            
            -- Issue Outputs to ALU (Leave open for now)
            -- busy_slots => [Evaluate for rs_alu_full]
        );

    branch_rs_inst : entity work.branch_rs
        port map (
            clk => clk, rst => rst, flush => flush_pipeline,
            we1 => br_we1, rs_packet1 => rs_packet1,
            we2 => br_we2, rs_packet2 => rs_packet2,
            cdb1_valid => cdb1_valid, cdb1_tag => cdb1_tag, cdb1_data => cdb1_data, cdb1_flags => cdb1_flags,
            cdb2_valid => cdb2_valid, cdb2_tag => cdb2_tag, cdb2_data => cdb2_data, cdb2_flags => cdb2_flags
        );

    lsq_inst : entity work.load_store_queue
        port map (
            clk => clk, rst => rst, flush => flush_pipeline,
            we1 => lsq_we1, rs_packet1 => rs_packet1,
            we2 => lsq_we2, rs_packet2 => rs_packet2,
            cdb1_valid => cdb1_valid, cdb1_tag => cdb1_tag, cdb1_data => cdb1_data,
            cdb2_valid => cdb2_valid, cdb2_tag => cdb2_tag, cdb2_data => cdb2_data
        );
        
    -- =========================================================
    -- REORDER BUFFER (Commit Engine)
    -- =========================================================
    rob_inst : entity work.reorder_buffer
        port map (
            clk => clk, rst => rst,
            
            -- Dispatch Allocation
            we1 => '1', rob_packet1 => rob_packet1, -- Gated by dispatch_stall logic upstream
            we2 => '1', rob_packet2 => rob_packet2,
            rob_free_slots => rob_free_slots,
            
            -- CDB Completion Snooping
            cdb1_valid => cdb1_valid, cdb1_rob_tag => "00000", -- Wire from ALU later
            cdb2_valid => cdb2_valid, cdb2_rob_tag => "00000", -- Wire from ALU later
            
            flush_pipeline => flush_pipeline,
            flush_pc => flush_pc
        );

end Structural;