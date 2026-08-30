library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

----------------------------------------------------------------------------------
-- MODULE: Physical Register Busy Table
-- DESCRIPTION:
--   Tracks whether the data inside a physical register is valid/complete, or if 
--   it is actively computing in an execution unit. Listens to the Common Data Bus
--   (CDB) to asynchronously mark dependencies as 'Ready', allowing Tomasulo 
--   wakeup logic to react on the exact same cycle.
----------------------------------------------------------------------------------
entity busy_table is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        flush           : in  std_logic;
        
        -- Physical Tag Lookups
        prs1            : in  std_logic_vector(4 downto 0);
        prt1            : in  std_logic_vector(4 downto 0);
        pr_flag1        : in  std_logic_vector(4 downto 0);
        prs2            : in  std_logic_vector(4 downto 0);
        prt2            : in  std_logic_vector(4 downto 0);
        pr_flag2        : in  std_logic_vector(4 downto 0);
        
        -- Readiness Status
        prs1_ready      : out std_logic;
        prt1_ready      : out std_logic;
        pr_flag1_ready  : out std_logic;
        prs2_ready      : out std_logic;
        prt2_ready      : out std_logic;
        pr_flag2_ready  : out std_logic;
        
        -- Complete Table Masks
        gpr_busy_out    : out std_logic_vector(31 downto 0);
        flag_busy_out   : out std_logic_vector(31 downto 0);
        
        -- Allocation Controls (Registers going in-flight)
        alloc_gpr1_en   : in  std_logic;
        alloc_gpr1      : in  std_logic_vector(4 downto 0);
        alloc_gpr2_en   : in  std_logic;
        alloc_gpr2      : in  std_logic_vector(4 downto 0);
        alloc_f1_en     : in  std_logic;
        alloc_f1        : in  std_logic_vector(4 downto 0);
        alloc_f2_en     : in  std_logic;
        alloc_f2        : in  std_logic_vector(4 downto 0);
        
        -- Writeback (CDB) Controls (Registers clearing dependencies)
        wb_gpr1_en      : in  std_logic;
        wb_gpr1_tag     : in  std_logic_vector(4 downto 0);
        wb_gpr2_en      : in  std_logic;
        wb_gpr2_tag     : in  std_logic_vector(4 downto 0);
        wb_gpr3_en      : in  std_logic;
        wb_gpr3_tag     : in  std_logic_vector(4 downto 0);
        wb_f1_en        : in  std_logic;
        wb_f1_tag       : in  std_logic_vector(4 downto 0);
        wb_f2_en        : in  std_logic;
        wb_f2_tag       : in  std_logic_vector(4 downto 0)
    );
end busy_table;

architecture Behavioral of busy_table is
    -- Internal memory: 1 = Actively Computing (Busy), 0 = Data Valid (Ready)
    signal gpr_busy_mask  : std_logic_vector(31 downto 0);
    signal flag_busy_mask : std_logic_vector(31 downto 0);

    -- Combinational snooping function to detect if a requested register is currently writing back on the CDB
    function is_wb_gpr(tag: std_logic_vector(4 downto 0); w1_e: std_logic; w1_t: std_logic_vector(4 downto 0); w2_e: std_logic; w2_t: std_logic_vector(4 downto 0); w3_e: std_logic; w3_t: std_logic_vector(4 downto 0)) return boolean is
    begin return (w1_e = '1' and tag = w1_t) or (w2_e = '1' and tag = w2_t) or (w3_e = '1' and tag = w3_t); end function;

    function is_wb_f(tag: std_logic_vector(4 downto 0); w1_e: std_logic; w1_t: std_logic_vector(4 downto 0); w2_e: std_logic; w2_t: std_logic_vector(4 downto 0)) return boolean is
    begin return (w1_e = '1' and tag = w1_t) or (w2_e = '1' and tag = w2_t); end function;

begin

    -- Slot 1 Readiness Checks (Evaluates 1 if CDB matches, OR if memory mask is 0)
    prs1_ready  <= '1' when is_wb_gpr(prs1, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) else not gpr_busy_mask(to_integer(unsigned(prs1)));
    prt1_ready  <= '1' when is_wb_gpr(prt1, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) else not gpr_busy_mask(to_integer(unsigned(prt1)));
    pr_flag1_ready <= '1' when is_wb_f(pr_flag1, wb_f1_en, wb_f1_tag, wb_f2_en, wb_f2_tag) else not flag_busy_mask(to_integer(unsigned(pr_flag1)));

    -- Slot 2 Readiness Checks with Intra-Cycle Override:
    -- If Slot 2 relies on a register just allocated by Slot 1, it must be marked BUSY ('0'), bypassing the static array.
    prs2_ready  <= '0' when (alloc_gpr1_en = '1' and prs2 = alloc_gpr1) else '1' when is_wb_gpr(prs2, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) else not gpr_busy_mask(to_integer(unsigned(prs2)));
    prt2_ready  <= '0' when (alloc_gpr1_en = '1' and prt2 = alloc_gpr1) else '1' when is_wb_gpr(prt2, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) else not gpr_busy_mask(to_integer(unsigned(prt2)));
    pr_flag2_ready <= '0' when (alloc_f1_en = '1' and pr_flag2 = alloc_f1) else '1' when is_wb_f(pr_flag2, wb_f1_en, wb_f1_tag, wb_f2_en, wb_f2_tag) else not flag_busy_mask(to_integer(unsigned(pr_flag2)));

    -- State Management
    process(clk, rst)
    begin
        if rst = '1' then
            gpr_busy_mask  <= (others => '0');
            flag_busy_mask <= (others => '0');
        elsif rising_edge(clk) then
            if flush = '1' then
                -- Clear all dependencies instantly on a flush
                gpr_busy_mask  <= (others => '0');
                flag_busy_mask <= (others => '0');
            else
                -- Mark resolved executions back to Ready (0)
                if wb_gpr1_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr1_tag))) <= '0'; end if;
                if wb_gpr2_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr2_tag))) <= '0'; end if;
                if wb_gpr3_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr3_tag))) <= '0'; end if;
                if wb_f1_en = '1' then flag_busy_mask(to_integer(unsigned(wb_f1_tag))) <= '0'; end if;
                if wb_f2_en = '1' then flag_busy_mask(to_integer(unsigned(wb_f2_tag))) <= '0'; end if;

                -- Mark newly dispatched allocations as In-Flight / Busy (1)
                -- (Overrides writeback if allocated on the exact same cycle, preventing collision)
                if alloc_gpr1_en = '1' then gpr_busy_mask(to_integer(unsigned(alloc_gpr1))) <= '1'; end if;
                if alloc_gpr2_en = '1' then gpr_busy_mask(to_integer(unsigned(alloc_gpr2))) <= '1'; end if;
                if alloc_f1_en = '1' then flag_busy_mask(to_integer(unsigned(alloc_f1))) <= '1'; end if;
                if alloc_f2_en = '1' then flag_busy_mask(to_integer(unsigned(alloc_f2))) <= '1'; end if;
            end if;
        end if;
    end process;

    -- Logging trace
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' and flush = '0' then
                if alloc_gpr1_en = '1' then
                    write(l, string'("[BUSY TABLE] Marked Phys P")); write(l, integer'image(to_integer(unsigned(alloc_gpr1)))); write(l, string'(" as BUSY")); writeline(output, l);
                end if;
                if alloc_gpr2_en = '1' then
                    write(l, string'("[BUSY TABLE] Marked Phys P")); write(l, integer'image(to_integer(unsigned(alloc_gpr2)))); write(l, string'(" as BUSY")); writeline(output, l);
                end if;
                
                if wb_gpr1_en = '1' then
                    write(l, string'("[BUSY TABLE] CDB Cleared Phys P")); write(l, integer'image(to_integer(unsigned(wb_gpr1_tag)))); write(l, string'(" -> READY")); writeline(output, l);
                end if;
                if wb_gpr2_en = '1' then
                    write(l, string'("[BUSY TABLE] CDB Cleared Phys P")); write(l, integer'image(to_integer(unsigned(wb_gpr2_tag)))); write(l, string'(" -> READY")); writeline(output, l);
                end if;
            end if;
        end if;
    end process;

    gpr_busy_out  <= gpr_busy_mask;
    flag_busy_out <= flag_busy_mask;
end Behavioral;