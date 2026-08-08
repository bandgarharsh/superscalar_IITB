library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =================================================================================
-- Entity: branch_rs
-- Description: 4-slot Reservation Station dedicated to Control Flow instructions 
--              (BEQ, BLT, JAL, JLR, etc.). Snoops the CDB and issues to a 
--              dedicated Branch Execution Unit to minimize misprediction penalties.
-- =================================================================================
entity branch_rs is
    Port (
        clk         : in std_logic;
        rst         : in std_logic;
        flush       : in std_logic; -- Global flush from ROB on misprediction

        -- --- 1. DISPATCH INTERFACE (Writing to RS) ---
        we          : in std_logic;
        alloc_idx   : in std_logic_vector(1 downto 0);
        d_opcode    : in std_logic_vector(3 downto 0);
        d_pc        : in std_logic_vector(15 downto 0);  -- Required for PC+Imm math
        d_imm       : in std_logic_vector(15 downto 0);  -- Sign-extended offset
        d_dest_pr   : in std_logic_vector(4 downto 0);   -- For JAL/JLR linking
        d_rob_tag   : in std_logic_vector(4 downto 0);

        -- Operand 1 (RA - e.g., first value to compare, or Jump base address)
        d_vj_valid  : in std_logic;
        d_vj_data   : in std_logic_vector(15 downto 0);
        d_qj_tag    : in std_logic_vector(4 downto 0);

        -- Operand 2 (RB - e.g., second value to compare)
        d_vk_valid  : in std_logic;
        d_vk_data   : in std_logic_vector(15 downto 0);
        d_qk_tag    : in std_logic_vector(4 downto 0);

        -- --- 2. COMMON DATA BUS INTERFACE (Snooping) ---
        cdb1_valid  : in std_logic;
        cdb1_tag    : in std_logic_vector(4 downto 0);
        cdb1_data   : in std_logic_vector(15 downto 0);

        cdb2_valid  : in std_logic;
        cdb2_tag    : in std_logic_vector(4 downto 0);
        cdb2_data   : in std_logic_vector(15 downto 0);

        -- --- 3. ISSUE INTERFACE (To Branch Execution Unit) ---
        issue_valid   : out std_logic;
        issue_opcode  : out std_logic_vector(3 downto 0);
        issue_pc      : out std_logic_vector(15 downto 0);
        issue_imm     : out std_logic_vector(15 downto 0);
        issue_vj      : out std_logic_vector(15 downto 0);
        issue_vk      : out std_logic_vector(15 downto 0);
        issue_dest_pr : out std_logic_vector(4 downto 0);
        issue_rob_tag : out std_logic_vector(4 downto 0);

        -- Status to Dispatcher
        busy_slots    : out std_logic_vector(3 downto 0)
    );
end branch_rs;

architecture Behavioral of branch_rs is

    -- Internal Array Types for the 4 slots
    type bit_array    is array (0 to 3) of std_logic;
    type opcode_array is array (0 to 3) of std_logic_vector(3 downto 0);
    type tag_array    is array (0 to 3) of std_logic_vector(4 downto 0);
    type data_array   is array (0 to 3) of std_logic_vector(15 downto 0);

    -- Reservation Station Slot Registers
    signal busy      : bit_array := (others => '0');
    signal opcode    : opcode_array := (others => (others => '0'));
    signal pc        : data_array := (others => (others => '0'));
    signal imm       : data_array := (others => (others => '0'));
    signal dest_pr   : tag_array := (others => (others => '0'));
    signal rob_tag   : tag_array := (others => (others => '0'));

    signal vj_valid  : bit_array := (others => '0');
    signal vj        : data_array := (others => (others => '0'));
    signal qj        : tag_array := (others => (others => '0'));

    signal vk_valid  : bit_array := (others => '0');
    signal vk        : data_array := (others => (others => '0'));
    signal qk        : tag_array := (others => (others => '0'));

    -- Internal signals for issue logic
    signal ready       : bit_array;
    signal int_issue_v : std_logic;
    signal int_issue_i : integer range 0 to 3;

begin

    -- Output busy vector so Dispatch knows which slots are occupied
    busy_slots <= busy(3) & busy(2) & busy(1) & busy(0);

    -- -------------------------------------------------------------------------
    -- Combinational Logic: Ready Flags
    -- A branch is ready when its slot is busy and both required operands are valid
    -- -------------------------------------------------------------------------
    ready(0) <= busy(0) and vj_valid(0) and vk_valid(0);
    ready(1) <= busy(1) and vj_valid(1) and vk_valid(1);
    ready(2) <= busy(2) and vj_valid(2) and vk_valid(2);
    ready(3) <= busy(3) and vj_valid(3) and vk_valid(3);

    -- -------------------------------------------------------------------------
    -- Combinational Logic: Priority Encoder (Oldest ready branch wins)
    -- -------------------------------------------------------------------------
    process(ready, opcode, pc, imm, vj, vk, dest_pr, rob_tag)
    begin
        -- Default assignments (no issue)
        int_issue_v   <= '0';
        int_issue_i   <= 0;
        issue_valid   <= '0';
        issue_opcode  <= (others => '0');
        issue_pc      <= (others => '0');
        issue_imm     <= (others => '0');
        issue_vj      <= (others => '0');
        issue_vk      <= (others => '0');
        issue_dest_pr <= (others => '0');
        issue_rob_tag <= (others => '0');

        if ready(0) = '1' then
            int_issue_v <= '1'; int_issue_i <= 0; issue_valid <= '1';
            issue_opcode <= opcode(0); issue_pc <= pc(0); issue_imm <= imm(0);
            issue_vj <= vj(0); issue_vk <= vk(0); 
            issue_dest_pr <= dest_pr(0); issue_rob_tag <= rob_tag(0);
        elsif ready(1) = '1' then
            int_issue_v <= '1'; int_issue_i <= 1; issue_valid <= '1';
            issue_opcode <= opcode(1); issue_pc <= pc(1); issue_imm <= imm(1);
            issue_vj <= vj(1); issue_vk <= vk(1); 
            issue_dest_pr <= dest_pr(1); issue_rob_tag <= rob_tag(1);
        elsif ready(2) = '1' then
            int_issue_v <= '1'; int_issue_i <= 2; issue_valid <= '1';
            issue_opcode <= opcode(2); issue_pc <= pc(2); issue_imm <= imm(2);
            issue_vj <= vj(2); issue_vk <= vk(2); 
            issue_dest_pr <= dest_pr(2); issue_rob_tag <= rob_tag(2);
        elsif ready(3) = '1' then
            int_issue_v <= '1'; int_issue_i <= 3; issue_valid <= '1';
            issue_opcode <= opcode(3); issue_pc <= pc(3); issue_imm <= imm(3);
            issue_vj <= vj(3); issue_vk <= vk(3); 
            issue_dest_pr <= dest_pr(3); issue_rob_tag <= rob_tag(3);
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Sequential Logic: Dispatch, CDB Snooping, Issue Clearing, and Flushes
    -- -------------------------------------------------------------------------
    process(clk, rst, flush)
        variable a_idx : integer range 0 to 3;
    begin
        -- When a branch misprediction occurs, the ROB sends a flush signal.
        -- We instantly clear every single slot by forcing busy bits to 0.
        if rst = '1' or flush = '1' then
            busy <= (others => '0');
            
        elsif rising_edge(clk) then
            
            a_idx := to_integer(unsigned(alloc_idx));

            -- 1. CLEAR ISSUED INSTRUCTION
            if int_issue_v = '1' then
                busy(int_issue_i) <= '0';
            end if;

            -- 2. DISPATCH (Allocate new branch)
            if we = '1' then
                busy(a_idx)      <= '1';
                opcode(a_idx)    <= d_opcode;
                pc(a_idx)        <= d_pc;
                imm(a_idx)       <= d_imm;
                dest_pr(a_idx)   <= d_dest_pr;
                rob_tag(a_idx)   <= d_rob_tag;
                
                vj_valid(a_idx)  <= d_vj_valid;
                vj(a_idx)        <= d_vj_data;
                qj(a_idx)        <= d_qj_tag;
                
                vk_valid(a_idx)  <= d_vk_valid;
                vk(a_idx)        <= d_vk_data;
                qk(a_idx)        <= d_qk_tag;
            end if;

            -- 3. CDB SNOOPING (Listen for missing operands)
            for i in 0 to 3 loop
                if busy(i) = '1' then
                    
                    -- Check Operand J against CDB 1 and 2
                    if vj_valid(i) = '0' then
                        if cdb1_valid = '1' and qj(i) = cdb1_tag then
                            vj(i) <= cdb1_data;
                            vj_valid(i) <= '1';
                        elsif cdb2_valid = '1' and qj(i) = cdb2_tag then
                            vj(i) <= cdb2_data;
                            vj_valid(i) <= '1';
                        end if;
                    end if;

                    -- Check Operand K against CDB 1 and 2
                    if vk_valid(i) = '0' then
                        if cdb1_valid = '1' and qk(i) = cdb1_tag then
                            vk(i) <= cdb1_data;
                            vk_valid(i) <= '1';
                        elsif cdb2_valid = '1' and qk(i) = cdb2_tag then
                            vk(i) <= cdb2_data;
                            vk_valid(i) <= '1';
                        end if;
                    end if;
                end if;
            end loop;
        end if;
    end process;

end Behavioral;