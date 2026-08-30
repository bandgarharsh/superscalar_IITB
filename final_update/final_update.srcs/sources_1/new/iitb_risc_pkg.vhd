library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package iitb_risc_pkg is
    -- Global Architecture Widths
    constant DATA_WIDTH : integer := 16;
    constant ADDR_WIDTH : integer := 16;
    constant REG_ADDR_W : integer := 3;
    
    -- Opcodes (4-bit)
    constant OP_ADI : std_logic_vector(3 downto 0) := "0000";
    constant OP_ADD : std_logic_vector(3 downto 0) := "0001"; 
    constant OP_NDU : std_logic_vector(3 downto 0) := "0010"; 
    constant OP_LLI : std_logic_vector(3 downto 0) := "0011";
    constant OP_LW  : std_logic_vector(3 downto 0) := "0100";
    constant OP_SW  : std_logic_vector(3 downto 0) := "0101";
    constant OP_LM  : std_logic_vector(3 downto 0) := "0110"; 
    constant OP_SM  : std_logic_vector(3 downto 0) := "0111"; 
    constant OP_BEQ : std_logic_vector(3 downto 0) := "1000";
    constant OP_BLT : std_logic_vector(3 downto 0) := "1001"; 
    constant OP_BLE : std_logic_vector(3 downto 0) := "1010"; 
    constant OP_JAL : std_logic_vector(3 downto 0) := "1100";
    constant OP_JLR : std_logic_vector(3 downto 0) := "1101";
    constant OP_JRI : std_logic_vector(3 downto 0) := "1111";
    
    -- Condition/Flag Bits (CZ)
    constant COND_AL : std_logic_vector(1 downto 0) := "00"; 
    constant COND_Z  : std_logic_vector(1 downto 0) := "01"; 
    constant COND_C  : std_logic_vector(1 downto 0) := "10"; 
    constant COND_CW : std_logic_vector(1 downto 0) := "11"; 
    
    type dispatch_packet_t is record
        valid       : std_logic;
        pc          : std_logic_vector(15 downto 0);
        op          : std_logic_vector(3 downto 0);
        imm         : std_logic_vector(15 downto 0);
        comp_bit    : std_logic;
        cz_bits     : std_logic_vector(1 downto 0);
        
        pred_taken  : std_logic;                     
        pred_target : std_logic_vector(15 downto 0); 
        prs_tag    : std_logic_vector(4 downto 0);
        prs_rdy    : std_logic;
        prs_data   : std_logic_vector(15 downto 0); 
        
        prt_tag     : std_logic_vector(4 downto 0);
        prt_rdy     : std_logic;
        prt_data    : std_logic_vector(15 downto 0); 
        
        pr_flag_tag : std_logic_vector(4 downto 0);
        pr_flag_rdy : std_logic;
        pr_flag_data: std_logic_vector(1 downto 0);  
        
        arch_dest   : std_logic_vector(2 downto 0); 
         
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
        
        rs1_data    : std_logic_vector(15 downto 0);
        rs2_data    : std_logic_vector(15 downto 0);
        flag_data   : std_logic_vector(1 downto 0); 
        
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
        
        pred_taken  : std_logic;
        pred_target : std_logic_vector(15 downto 0);
        
        rs1_data    : std_logic_vector(15 downto 0);
        rs2_data    : std_logic_vector(15 downto 0);
        flag_data   : std_logic_vector(1 downto 0);
        
        pd_new      : std_logic_vector(4 downto 0);
        pf_new      : std_logic_vector(4 downto 0);
        rob_id      : std_logic_vector(3 downto 0);
        we_gpr      : std_logic;
        we_flag     : std_logic;
    end record;

    type lsq_entry_t is record
        valid       : std_logic;
        is_store    : std_logic; 
        
        cz_bits     : std_logic_vector(1 downto 0); -- NEW: Tracks the secret SMF/LMF identifier!
        
        base_rdy    : std_logic; 
        base_data   : std_logic_vector(15 downto 0);
        imm         : std_logic_vector(15 downto 0);
        
        addr_valid  : std_logic; 
        mem_addr    : std_logic_vector(15 downto 0);
        
        data_rdy    : std_logic; 
        store_data  : std_logic_vector(15 downto 0);
        
        pd_new      : std_logic_vector(4 downto 0);
        rob_id      : std_logic_vector(3 downto 0);
    end record;

    type lsu_issue_packet_t is record
        valid       : std_logic;
        pc          : std_logic_vector(15 downto 0);
        op          : std_logic_vector(3 downto 0);
        imm         : std_logic_vector(15 downto 0);
        
        cz_bits     : std_logic_vector(1 downto 0); -- NEW: Passes the identifier to the AGU/Load Queue!
        
        base_data   : std_logic_vector(15 downto 0); 
        
        prt_tag     : std_logic_vector(4 downto 0);  
        prt_rdy     : std_logic;                     
        prt_data    : std_logic_vector(15 downto 0); 
        
        pd_new      : std_logic_vector(4 downto 0);  
        pf_new      : std_logic_vector(4 downto 0);  
        rob_id      : std_logic_vector(3 downto 0);
        
        we_gpr      : std_logic; 
        we_flag     : std_logic; 
    end record;

    type sq_entry_t is record
        valid       : std_logic;
        mem_addr    : std_logic_vector(15 downto 0); 
        data_ready  : std_logic;                     
        store_data  : std_logic_vector(15 downto 0); 
        prt_tag     : std_logic_vector(4 downto 0);  
        rob_id      : std_logic_vector(3 downto 0);  
    end record;
    
    type lq_entry_t is record
        valid       : std_logic;
        state       : std_logic_vector(1 downto 0); 
        mem_addr    : std_logic_vector(15 downto 0);
        
        cz_bits     : std_logic_vector(1 downto 0); -- NEW: Tells the Load Queue to broadcast to the Flag CDB!
        
        pd_new      : std_logic_vector(4 downto 0);
        pf_new      : std_logic_vector(4 downto 0);
        we_gpr      : std_logic;
        we_flag     : std_logic;
        rob_id      : std_logic_vector(3 downto 0);
        
        final_data  : std_logic_vector(15 downto 0);
    end record;
    
    type rob_entry_t is record
        valid           : std_logic; 
        executed        : std_logic; 
        
        op_type         : std_logic_vector(1 downto 0);  
        pc              : std_logic_vector(15 downto 0); 
        
        is_branch       : std_logic;                     
        mispredicted    : std_logic;                     
        correct_target  : std_logic_vector(15 downto 0); 
        
        pd_new          : std_logic_vector(4 downto 0);  
        pf_new          : std_logic_vector(4 downto 0);  
        arch_dest       : std_logic_vector(2 downto 0);  
        
        gpr_data        : std_logic_vector(15 downto 0); 
        flag_data       : std_logic_vector(1 downto 0);  
        
        we_gpr          : std_logic;
        we_flag         : std_logic;
    end record;
    
    type sq_array_t is array (0 to 15) of sq_entry_t;
    type array_of_2bit is array (integer range <>) of std_logic_vector(1 downto 0);
    type array_of_5bit is array (integer range <>) of std_logic_vector(4 downto 0);
    type array_of_16bit is array (integer range <>) of std_logic_vector(15 downto 0);
end package iitb_risc_pkg;