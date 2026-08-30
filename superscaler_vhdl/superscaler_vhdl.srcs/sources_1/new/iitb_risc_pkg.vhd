library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package iitb_risc_pkg is
    -- Global Architecture Widths
    constant DATA_WIDTH : integer := 16;
    constant ADDR_WIDTH : integer := 16;
    constant REG_ADDR_W : integer := 3;
    
    -- Opcodes (4-bit)
    constant OP_ADI : std_logic_vector(3 downto 0) := "0000";
    constant OP_ADD : std_logic_vector(3 downto 0) := "0001"; -- ADA, ADC, ADZ, etc.
    constant OP_NDU : std_logic_vector(3 downto 0) := "0010"; -- NDU, NDC, NDZ, etc.
    constant OP_LLI : std_logic_vector(3 downto 0) := "0011";
    constant OP_LW  : std_logic_vector(3 downto 0) := "0100";
    constant OP_SW  : std_logic_vector(3 downto 0) := "0101";
    constant OP_LM  : std_logic_vector(3 downto 0) := "0110"; -- Includes LMF
    constant OP_SM  : std_logic_vector(3 downto 0) := "0111"; -- Includes SMF
    constant OP_BEQ : std_logic_vector(3 downto 0) := "1000";
    constant OP_BLT : std_logic_vector(3 downto 0) := "1001"; -- Includes BLE
    constant OP_BLE : std_logic_vector(3 downto 0) := "1010"; -- Includes BLE
    constant OP_JAL : std_logic_vector(3 downto 0) := "1100";
    constant OP_JLR : std_logic_vector(3 downto 0) := "1101";
    constant OP_JRI : std_logic_vector(3 downto 0) := "1111";
    
    -- Condition/Flag Bits (CZ)
    constant COND_AL : std_logic_vector(1 downto 0) := "00"; -- Always
    constant COND_Z  : std_logic_vector(1 downto 0) := "01"; -- If Zero
    constant COND_C  : std_logic_vector(1 downto 0) := "10"; -- If Carry
    constant COND_CW : std_logic_vector(1 downto 0) := "11"; -- Carry + Write
    
    -- Add this to iitb_risc_pkg.vhd
    type dispatch_packet_t is record
        valid       : std_logic;
        pc          : std_logic_vector(15 downto 0);
        op          : std_logic_vector(3 downto 0);
        imm         : std_logic_vector(15 downto 0);
        comp_bit    : std_logic;
        cz_bits     : std_logic_vector(1 downto 0);
        
        pred_taken  : std_logic;                     -- Did Fetch guess Taken?
        pred_target : std_logic_vector(15 downto 0); -- Where did Fetch jump to?
        -- Source 1 (GPR)
        prs_tag    : std_logic_vector(4 downto 0);
        prs_rdy    : std_logic;
        prs_data   : std_logic_vector(15 downto 0); -- Actual data from PRF!
        
        -- Source 2 (GPR)
        prt_tag     : std_logic_vector(4 downto 0);
        prt_rdy     : std_logic;
        prt_data    : std_logic_vector(15 downto 0); -- Actual data from PRF!
        
        -- Source 3 (Flags)
        pr_flag_tag : std_logic_vector(4 downto 0);
        pr_flag_rdy : std_logic;
        pr_flag_data: std_logic_vector(1 downto 0);  -- Actual {C,Z} from PRF!
        
        -- Destinations
        arch_dest   : std_logic_vector(2 downto 0); -- for RRAT recoveery
         
        pd_new      : std_logic_vector(4 downto 0);
        pf_new      : std_logic_vector(4 downto 0);
        rob_id      : std_logic_vector(3 downto 0);
        we_gpr      : std_logic;
        we_flag     : std_logic;
    end record;
    type issue_packet_t is record
        valid       : std_logic;
        pc          : std_logic_vector(15 downto 0);
        op          : std_logic_vector(3 downto 0);
        imm         : std_logic_vector(15 downto 0);
        comp_bit    : std_logic;
        cz_bits     : std_logic_vector(1 downto 0);
        
        -- ==========================================
        -- RAW OPERAND DATA (No Tags, No Ready Bits!)
        -- ==========================================
        rs1_data    : std_logic_vector(15 downto 0);
        rs2_data    : std_logic_vector(15 downto 0);
        flag_data   : std_logic_vector(1 downto 0); 
        
        -- ==========================================
        -- DESTINATION METADATA (For Writeback & ROB)
        -- ==========================================
        pd_new      : std_logic_vector(4 downto 0);
        pf_new      : std_logic_vector(4 downto 0);
        rob_id      : std_logic_vector(3 downto 0);
        we_gpr      : std_logic;
        we_flag     : std_logic;
    end record;
    
    type branch_issue_packet_t is record
        valid       : std_logic;
        pc          : std_logic_vector(15 downto 0);
        op          : std_logic_vector(3 downto 0);
        imm         : std_logic_vector(15 downto 0);
        comp_bit    : std_logic;
        cz_bits     : std_logic_vector(1 downto 0);
        
        -- ==========================================
        -- BRANCH PREDICTION DATA
        -- ==========================================
        pred_taken  : std_logic;
        pred_target : std_logic_vector(15 downto 0);
        
        -- ==========================================
        -- RAW OPERANDS
        -- ==========================================
        rs1_data    : std_logic_vector(15 downto 0);
        rs2_data    : std_logic_vector(15 downto 0);
        flag_data   : std_logic_vector(1 downto 0);
        
        -- ==========================================
        -- DESTINATION METADATA
        -- ==========================================
        pd_new      : std_logic_vector(4 downto 0);
        pf_new      : std_logic_vector(4 downto 0);
        rob_id      : std_logic_vector(3 downto 0);
        we_gpr      : std_logic;
        we_flag     : std_logic;
    end record;
    type lsq_entry_t is record
        valid       : std_logic;
        
        is_store    : std_logic;  -- 1 for SW, 0 for LW
        
        -- Step 1: Address Calculation
        base_rdy    : std_logic;  -- Is rs1 (Base) ready?
        base_data   : std_logic_vector(15 downto 0);
        imm         : std_logic_vector(15 downto 0);
        
        addr_valid  : std_logic;  -- Has the AGU calculated the address yet?
        mem_addr    : std_logic_vector(15 downto 0);
        
        -- Step 2: Data Handling
        data_rdy    : std_logic;  -- Is rs2 (Store Data) ready?
        store_data  : std_logic_vector(15 downto 0);
        
        -- Tracking
        pd_new      : std_logic_vector(4 downto 0);
        rob_id      : std_logic_vector(3 downto 0);
    end record;
    type lsu_issue_packet_t is record
        valid       : std_logic;
        pc          : std_logic_vector(15 downto 0);
        op          : std_logic_vector(3 downto 0);
        imm         : std_logic_vector(15 downto 0);
        
        -- ==========================================
        -- BASE ADDRESS (RB -> rs1)
        -- ==========================================
        base_data   : std_logic_vector(15 downto 0); 
        
        -- ==========================================
        -- STORE DATA (RA -> rs2, for SW/SM only)
        -- ==========================================
        prt_tag     : std_logic_vector(4 downto 0);  
        prt_rdy     : std_logic;                     
        prt_data    : std_logic_vector(15 downto 0); 
        
        -- ==========================================
        -- DESTINATION METADATA (RA -> rd, for LW/LM)
        -- ==========================================
        pd_new      : std_logic_vector(4 downto 0);  -- Physical GPR tag
        pf_new      : std_logic_vector(4 downto 0);  -- Physical Flag tag (You caught this!)
        rob_id      : std_logic_vector(3 downto 0);
        
        -- Enables
        we_gpr      : std_logic; 
        we_flag     : std_logic; -- Set to '1' for LW so it can update the Z flag
    end record;
    -- ==========================================
    -- STORE QUEUE TYPES
    -- ==========================================
    
    -- 1. The record for a single slot in the Store Queue
    type sq_entry_t is record
        valid       : std_logic;
        mem_addr    : std_logic_vector(15 downto 0); -- The safe address from AGU
        data_ready  : std_logic;                     -- Is the data here yet?
        store_data  : std_logic_vector(15 downto 0); -- The data to write
        prt_tag     : std_logic_vector(4 downto 0);  -- Snoop tag for missing data
        rob_id      : std_logic_vector(3 downto 0);  -- Ticket number for age checks
    end record;
    
    -- The LQ State Machine for each slot
    -- 00: WAIT_SAFE (Checking SQ)
    -- 01: WAIT_RAM  (Sent read_en, waiting for data)
    -- 10: BROADCAST (Data is ready, fire to CDB!)
    
    type lq_entry_t is record
        valid       : std_logic;
        state       : std_logic_vector(1 downto 0); 
        mem_addr    : std_logic_vector(15 downto 0);
        
        -- Metadata for Broadcast
        pd_new      : std_logic_vector(4 downto 0);
        pf_new      : std_logic_vector(4 downto 0);
        we_gpr      : std_logic;
        we_flag     : std_logic;
        rob_id      : std_logic_vector(3 downto 0);
        
        -- Forwarded or RAM Data
        final_data  : std_logic_vector(15 downto 0);
    end record;
    
    type rob_entry_t is record
        -- ========================================================
        -- 1. STATUS BITS
        -- ========================================================
        valid           : std_logic; -- 1 = Slot holds active instruction. 0 = Slot is empty.
        executed        : std_logic; -- 1 = Execution done. (Hardware ignores this if valid=0)
        
        -- ========================================================
        -- 2. INSTRUCTION METADATA
        -- ========================================================
        op_type         : std_logic_vector(1 downto 0);  -- 00=ALU, 01=LOAD, 10=STORE, 11=BRANCH
        pc              : std_logic_vector(15 downto 0); -- MANDATORY: Used for branch recovery!
        
        -- ========================================================
        -- 3. BRANCH RECOVERY INFO (The Pending Part!)
        -- ========================================================
        is_branch       : std_logic;                     -- Is this a BEQ/JAL?
        mispredicted    : std_logic;                     -- Set to '1' by Branch Unit if guess was wrong
        correct_target  : std_logic_vector(15 downto 0); -- Where should the PC actually go?
        
        -- ========================================================
        -- 4. DESTINATION REGISTERS (For In-Order Commit)
        -- ========================================================
        pd_new          : std_logic_vector(4 downto 0);  -- Physical Register written to
        pf_new          : std_logic_vector(4 downto 0);  -- Physical flag written to
        arch_dest       : std_logic_vector(2 downto 0);  -- Arch Register (R0-R7) to update in ARF
        
        -- ========================================================
        -- 5. THE DATA (Calculated out-of-order)
        -- ========================================================
        gpr_data        : std_logic_vector(15 downto 0); -- Results from ALU or Load Queue
        flag_data       : std_logic_vector(1 downto 0);  -- Flags {C, Z} from ALU or Load Queue
        
        -- ========================================================
        -- 6. WRITE ENABLES (Does this instruction write to ARF?)
        -- ========================================================
        we_gpr          : std_logic;
        we_flag         : std_logic;
    end record;
    
    type sq_array_t is array (0 to 3) of sq_entry_t;
    type array_of_2bit is array (integer range <>) of std_logic_vector(1 downto 0);
    type array_of_5bit is array (integer range <>) of std_logic_vector(4 downto 0);
    type array_of_16bit is array (integer range <>) of std_logic_vector(15 downto 0);
end package iitb_risc_pkg;