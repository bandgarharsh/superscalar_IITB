-- old code 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dispatch_stage is
    Port (
        clk   : in std_logic;
        rst   : in std_logic;
        flush : in std_logic; -- Restored flush protection

        -- ==========================================
        -- Inputs from RR Stage 
        -- ==========================================
        valid1_in    : in std_logic;
        op1_in       : in std_logic_vector(3 downto 0);
        ra1_in       : in std_logic_vector(2 downto 0);
        p_ra1        : in std_logic_vector(4 downto 0);
        p_flag1_dest : in std_logic_vector(4 downto 0);
        p_rb1        : in std_logic_vector(4 downto 0);
        p_rc1        : in std_logic_vector(4 downto 0);
        pr_flag1     : in std_logic_vector(4 downto 0);
        old_p_ra1    : in std_logic_vector(4 downto 0);
        old_pr_flag1 : in std_logic_vector(4 downto 0);
        we_flag1_in  : in std_logic;
        imm1_in      : in std_logic_vector(15 downto 0);
        cz1_in       : in std_logic_vector(1 downto 0);
        comp1_in     : in std_logic;
        pc1_in       : in std_logic_vector(15 downto 0);

        valid2_in    : in std_logic;
        op2_in       : in std_logic_vector(3 downto 0);
        ra2_in       : in std_logic_vector(2 downto 0);
        p_ra2        : in std_logic_vector(4 downto 0);
        p_flag2_dest : in std_logic_vector(4 downto 0);
        p_rb2        : in std_logic_vector(4 downto 0);
        p_rc2        : in std_logic_vector(4 downto 0);
        pr_flag2     : in std_logic_vector(4 downto 0);
        old_p_ra2    : in std_logic_vector(4 downto 0);
        old_pr_flag2 : in std_logic_vector(4 downto 0);
        we_flag2_in  : in std_logic;
        imm2_in      : in std_logic_vector(15 downto 0);
        cz2_in       : in std_logic_vector(1 downto 0);
        comp2_in     : in std_logic;
        pc2_in       : in std_logic_vector(15 downto 0);

        -- ==========================================
        -- Inputs from ROB (The allocated tags)
        -- ==========================================
        rob_tag1_in : in std_logic_vector(4 downto 0); -- NEW
        rob_tag2_in : in std_logic_vector(4 downto 0); -- NEW

        -- ==========================================
        -- Capacity Inputs (From downstream)
        -- ==========================================
        rob_free_slots : in unsigned(5 downto 0); 
        rs_alu_free    : in unsigned(2 downto 0); -- NEW: Free count instead of full bit
        rs_mem_free    : in unsigned(2 downto 0); -- NEW: Free count instead of full bit
        rs_br_free     : in unsigned(2 downto 0); -- NEW: Free count instead of full bit

        -- ==========================================
        -- Outputs to Upstream (Stall)
        -- ==========================================
        dispatch_stall : out std_logic;

        -- ==========================================
        -- Grouped Outputs to Reservation Stations (RS)
        -- ==========================================
        -- [68:64] ROB Tag (5) <--- NEW!
        -- [63:60] Opcode (4)
        -- [59:55] Dest PR (5)
        -- [54:50] Dest Flag PR (5)
        -- [49:45] Src1 PR (5)
        -- [44:40] Src2 PR (5)
        -- [39:35] Src Flag PR (5)
        -- [34:19] Immediate (16)
        -- [18:17] CZ (2)
        -- [16]    Comp (1)
        -- [15:0]  PC (16)
        rs_packet1 : out std_logic_vector(68 downto 0); -- Expanded to 69 bits
        rs_packet2 : out std_logic_vector(68 downto 0); -- Expanded to 69 bits

        rs_alu_valid1, rs_alu_valid2 : out std_logic;
        rs_mem_valid1, rs_mem_valid2 : out std_logic;
        rs_br_valid1,  rs_br_valid2  : out std_logic;

        -- ==========================================
        -- Grouped Outputs to Reorder Buffer (ROB)
        -- ==========================================
        rob_packet1 : out std_logic_vector(44 downto 0);
        rob_packet2 : out std_logic_vector(44 downto 0);

        rob_valid1, rob_valid2 : out std_logic
    );
end dispatch_stage;

architecture Behavioral of dispatch_stage is

    signal is_alu1, is_mem1, is_br1 : std_logic;
    signal is_alu2, is_mem2, is_br2 : std_logic;
    signal writes_gpr1, writes_gpr2 : std_logic;

    signal val1, val2 : std_logic;
    signal alu_needed, mem_needed, br_needed : unsigned(1 downto 0);
    
    signal stall_rob, stall_alu, stall_mem, stall_br : std_logic;
    signal dispatch_stall_s : std_logic;
    signal num_valid : unsigned(1 downto 0);

begin

    -- Flush Gating
    val1 <= valid1_in and not flush;
    val2 <= valid2_in and not flush;

    -- 1. Decode Execution Targets
    is_alu1 <= '1' when (op1_in = "0000" or op1_in = "0001" or op1_in = "0010" or op1_in = "0011") else '0';
    is_alu2 <= '1' when (op2_in = "0000" or op2_in = "0001" or op2_in = "0010" or op2_in = "0011") else '0';
    
    is_mem1 <= '1' when (op1_in = "0100" or op1_in = "0101" or op1_in = "0110" or op1_in = "0111") else '0';
    is_mem2 <= '1' when (op2_in = "0100" or op2_in = "0101" or op2_in = "0110" or op2_in = "0111") else '0';
    
    is_br1  <= '1' when (op1_in = "1000" or op1_in = "1001" or op1_in = "1100" or op1_in = "1101" or op1_in = "1111") else '0';
    is_br2  <= '1' when (op2_in = "1000" or op2_in = "1001" or op2_in = "1100" or op2_in = "1101" or op2_in = "1111") else '0';

    writes_gpr1 <= '1' when (is_alu1 = '1' or op1_in = "0100" or op1_in = "1100" or op1_in = "1101") else '0';
    writes_gpr2 <= '1' when (is_alu2 = '1' or op2_in = "0100" or op2_in = "1100" or op2_in = "1101") else '0';

    -- 2. Evaluate Stalls (NEW: Required Slots vs Free Slots)
    num_valid <= ("0" & val1) + ("0" & val2);
    
    alu_needed <= ("0" & (val1 and is_alu1)) + ("0" & (val2 and is_alu2));
    mem_needed <= ("0" & (val1 and is_mem1)) + ("0" & (val2 and is_mem2));
    br_needed  <= ("0" & (val1 and is_br1))  + ("0" & (val2 and is_br2));

    stall_rob <= '1' when rob_free_slots < num_valid else '0';
    stall_alu <= '1' when rs_alu_free < resize(alu_needed, 3) else '0';
    stall_mem <= '1' when rs_mem_free < resize(mem_needed, 3) else '0';
    stall_br  <= '1' when rs_br_free  < resize(br_needed, 3) else '0';

    dispatch_stall_s <= stall_rob or stall_alu or stall_mem or stall_br;
    dispatch_stall   <= dispatch_stall_s;

    -- 3. Construct the Packets (NEW: Appended rob_tag to the top bits)
    rs_packet1 <= rob_tag1_in & op1_in & p_ra1 & p_flag1_dest & p_rb1 & p_rc1 & pr_flag1 & imm1_in & cz1_in & comp1_in & pc1_in;
    rs_packet2 <= rob_tag2_in & op2_in & p_ra2 & p_flag2_dest & p_rb2 & p_rc2 & pr_flag2 & imm2_in & cz2_in & comp2_in & pc2_in;

    rob_packet1 <= ra1_in & p_ra1 & old_p_ra1 & p_flag1_dest & old_pr_flag1 & we_flag1_in & writes_gpr1 & op1_in & pc1_in;
    rob_packet2 <= ra2_in & p_ra2 & old_p_ra2 & p_flag2_dest & old_pr_flag2 & we_flag2_in & writes_gpr2 & op2_in & pc2_in;

    -- 4. Route Valids (Strictly Gated by Stalls)
    rob_valid1 <= val1 and not dispatch_stall_s;
    rob_valid2 <= val2 and not dispatch_stall_s;

    rs_alu_valid1 <= val1 and is_alu1 and not dispatch_stall_s;
    rs_alu_valid2 <= val2 and is_alu2 and not dispatch_stall_s;

    rs_mem_valid1 <= val1 and is_mem1 and not dispatch_stall_s;
    rs_mem_valid2 <= val2 and is_mem2 and not dispatch_stall_s;

    rs_br_valid1  <= val1 and is_br1  and not dispatch_stall_s;
    rs_br_valid2  <= val2 and is_br2  and not dispatch_stall_s;

end Behavioral;