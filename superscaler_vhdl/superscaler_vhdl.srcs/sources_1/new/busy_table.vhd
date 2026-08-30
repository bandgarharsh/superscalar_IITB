library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- how are we finding stale data where are we assigning stale data and other ?
entity busy_table is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        flush           : in  std_logic;
        -- ==========================================
        -- READ PORTS (From RAT Outputs)
        -- ==========================================
        prs1            : in  std_logic_vector(4 downto 0);
        prt1            : in  std_logic_vector(4 downto 0);
        pr_flag1           : in  std_logic_vector(4 downto 0);

        prs2            : in  std_logic_vector(4 downto 0);
        prt2            : in  std_logic_vector(4 downto 0);
        pr_flag2           : in  std_logic_vector(4 downto 0);

        -- Outputs to Reservation Stations (1 = Ready, 0 = Busy)
        prs1_ready      : out std_logic;
        prt1_ready      : out std_logic;
        pr_flag1_ready     : out std_logic;

        prs2_ready      : out std_logic;
        prt2_ready      : out std_logic;
        pr_flag2_ready     : out std_logic;
        
        -- NEW: Live Masks for the Router!
        gpr_busy_out    : out std_logic_vector(31 downto 0);
        flag_busy_out   : out std_logic_vector(31 downto 0);
        -- ==========================================
        -- ALLOCATION PORTS (From Free List / Rename)
        -- ==========================================
        alloc_gpr1_en   : in  std_logic;
        alloc_gpr1      : in  std_logic_vector(4 downto 0);
        alloc_gpr2_en   : in  std_logic;
        alloc_gpr2      : in  std_logic_vector(4 downto 0);

        alloc_f1_en     : in  std_logic;
        alloc_f1        : in  std_logic_vector(4 downto 0);
        alloc_f2_en     : in  std_logic;
        alloc_f2        : in  std_logic_vector(4 downto 0);

        -- ==========================================
        -- WRITEBACK PORTS (From Execution Units / CDB)
        -- ==========================================
        -- 4 Ports for GPRs (e.g., ALU0, ALU1, LSU, Branch) -- we will ahve only 1 arithmatic alu 1 branch alu 1 load_Store__alu similar 3 reserve station private not centralized ?
        wb_gpr1_en      : in  std_logic;
        wb_gpr1_tag     : in  std_logic_vector(4 downto 0);
        wb_gpr2_en      : in  std_logic;
        wb_gpr2_tag     : in  std_logic_vector(4 downto 0);
        wb_gpr3_en      : in  std_logic;
        wb_gpr3_tag     : in  std_logic_vector(4 downto 0);

        -- 2 Ports for Flags -- same for why two flag is it for c and z or what 
        wb_f1_en        : in  std_logic;
        wb_f1_tag       : in  std_logic_vector(4 downto 0);
        wb_f2_en        : in  std_logic;
        wb_f2_tag       : in  std_logic_vector(4 downto 0)
    );
end busy_table;

architecture Behavioral of busy_table is

    -- 1 = Busy, 0 = Ready
    signal gpr_busy_mask  : std_logic_vector(31 downto 0);
    signal flag_busy_mask : std_logic_vector(31 downto 0);

    -- Internal Bypass functions to keep code clean -- what is this function doing what is it chaecking ? explain teminolgy ?
    function is_wb_gpr(tag : std_logic_vector(4 downto 0);
                       w1_e: std_logic; w1_t: std_logic_vector(4 downto 0);
                       w2_e: std_logic; w2_t: std_logic_vector(4 downto 0);
                       w3_e: std_logic; w3_t: std_logic_vector(4 downto 0)) return boolean is
    begin
        return (w1_e = '1' and tag = w1_t) or 
               (w2_e = '1' and tag = w2_t) or 
               (w3_e = '1' and tag = w3_t) ;
    end function;

    function is_wb_f(tag : std_logic_vector(4 downto 0); -- similar as ablove ?
                     w1_e: std_logic; w1_t: std_logic_vector(4 downto 0);
                     w2_e: std_logic; w2_t: std_logic_vector(4 downto 0)) return boolean is
    begin
        return (w1_e = '1' and tag = w1_t) or 
               (w2_e = '1' and tag = w2_t);
    end function;

begin

    -- =================================================================
    -- 1. COMBINATIONAL READS & BYPASSING
    -- =================================================================
    
    -- Slot 1 Reads (Check if it's currently being written back. If yes -> Ready)
    prs1_ready  <= '1' when is_wb_gpr(prs1, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) 
                   else not gpr_busy_mask(to_integer(unsigned(prs1)));
                   
    prt1_ready  <= '1' when is_wb_gpr(prt1, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) 
                   else not gpr_busy_mask(to_integer(unsigned(prt1)));
                   
    pr_flag1_ready <= '1' when is_wb_f(pr_flag1, wb_f1_en, wb_f1_tag, wb_f2_en, wb_f2_tag) 
                   else not flag_busy_mask(to_integer(unsigned(pr_flag1)));
                   


    -- Slot 2 Reads (Must check Writebacks AND if Slot 1 just allocated it)
    prs2_ready  <= '0' when (alloc_gpr1_en = '1' and prs2 = alloc_gpr1) -- Slot 1 allocated it! It's BUSY. -- if it  busy then it should be 1 ? and we are not using alloc_grp_en and alloc_grp2 ?
                   else '1' when is_wb_gpr(prs2, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) 
                   else not gpr_busy_mask(to_integer(unsigned(prs2)));

    prt2_ready  <= '0' when (alloc_gpr1_en = '1' and prt2 = alloc_gpr1)
                   else '1' when is_wb_gpr(prt2, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) 
                   else not gpr_busy_mask(to_integer(unsigned(prt2)));

    pr_flag2_ready <= '0' when (alloc_f1_en = '1' and pr_flag2 = alloc_f1)
                   else '1' when is_wb_f(pr_flag2, wb_f1_en, wb_f1_tag, wb_f2_en, wb_f2_tag)
                   else not flag_busy_mask(to_integer(unsigned(pr_flag2)));



    -- =================================================================
    -- 2. SEQUENTIAL UPDATES
    -- =================================================================
    process(clk, rst)
    begin
        if rst = '1' then
            gpr_busy_mask  <= (others => '0'); -- All ready
            flag_busy_mask <= (others => '0');
            
        elsif rising_edge(clk) then
            if flush = '1' then
                gpr_busy_mask  <= (others => '0'); -- Instantly make all registers Ready
                flag_busy_mask <= (others => '0');
            else
                -- Step A: Clear bits for Writebacks (Data is ready)
                if wb_gpr1_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr1_tag))) <= '0'; end if;
                if wb_gpr2_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr2_tag))) <= '0'; end if;
                if wb_gpr3_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr3_tag))) <= '0'; end if;
    
                if wb_f1_en = '1' then flag_busy_mask(to_integer(unsigned(wb_f1_tag))) <= '0'; end if;
                if wb_f2_en = '1' then flag_busy_mask(to_integer(unsigned(wb_f2_tag))) <= '0'; end if;
    
                -- Step B: Set bits for Allocations (Data is now in-flight)
                -- Note: Since VHDL processes sequentially, Allocation overrides Writeback. 
                -- (This is architecturally correct: we only allocate FREE registers, 
                --  but if an edge case arose, the newly allocated instruction must mark it busy).
                if alloc_gpr1_en = '1' then gpr_busy_mask(to_integer(unsigned(alloc_gpr1))) <= '1'; end if;
                if alloc_gpr2_en = '1' then gpr_busy_mask(to_integer(unsigned(alloc_gpr2))) <= '1'; end if;
    
                if alloc_f1_en = '1' then flag_busy_mask(to_integer(unsigned(alloc_f1))) <= '1'; end if;
                if alloc_f2_en = '1' then flag_busy_mask(to_integer(unsigned(alloc_f2))) <= '1'; end if;
                
            end if;
            
        end if;
    end process;
    -- =========================================================
    -- X-RAY: BUSY TABLE TRACKING
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' and flush = '0' then
                if alloc_gpr1_en = '1' then
                    report "[X-RAY BUSY TABLE] Slot 1 Allocated PRF_TAG: " & integer'image(to_integer(unsigned(alloc_gpr1))) & " -> Marked BUSY (Wait for CDB)";
                end if;
                if alloc_gpr2_en = '1' then
                    report "[X-RAY BUSY TABLE] Slot 2 Allocated PRF_TAG: " & integer'image(to_integer(unsigned(alloc_gpr2))) & " -> Marked BUSY (Wait for CDB)";
                end if;
                
                if wb_gpr1_en = '1' then
                    report "[X-RAY BUSY TABLE] CDB 1 Cleared PRF_TAG: " & integer'image(to_integer(unsigned(wb_gpr1_tag))) & " -> Marked READY";
                end if;
                if wb_gpr2_en = '1' then
                    report "[X-RAY BUSY TABLE] CDB 2 Cleared PRF_TAG: " & integer'image(to_integer(unsigned(wb_gpr2_tag))) & " -> Marked READY";
                end if;
            end if;
        end if;
    end process;

    gpr_busy_out  <= gpr_busy_mask;
    flag_busy_out <= flag_busy_mask;
end Behavioral;