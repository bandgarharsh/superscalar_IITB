library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; -- NEW: Clean Logging

entity busy_table is
    Port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        flush           : in  std_logic;
        prs1            : in  std_logic_vector(4 downto 0);
        prt1            : in  std_logic_vector(4 downto 0);
        pr_flag1        : in  std_logic_vector(4 downto 0);
        prs2            : in  std_logic_vector(4 downto 0);
        prt2            : in  std_logic_vector(4 downto 0);
        pr_flag2        : in  std_logic_vector(4 downto 0);
        prs1_ready      : out std_logic;
        prt1_ready      : out std_logic;
        pr_flag1_ready  : out std_logic;
        prs2_ready      : out std_logic;
        prt2_ready      : out std_logic;
        pr_flag2_ready  : out std_logic;
        gpr_busy_out    : out std_logic_vector(31 downto 0);
        flag_busy_out   : out std_logic_vector(31 downto 0);
        alloc_gpr1_en   : in  std_logic;
        alloc_gpr1      : in  std_logic_vector(4 downto 0);
        alloc_gpr2_en   : in  std_logic;
        alloc_gpr2      : in  std_logic_vector(4 downto 0);
        alloc_f1_en     : in  std_logic;
        alloc_f1        : in  std_logic_vector(4 downto 0);
        alloc_f2_en     : in  std_logic;
        alloc_f2        : in  std_logic_vector(4 downto 0);
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
    signal gpr_busy_mask  : std_logic_vector(31 downto 0);
    signal flag_busy_mask : std_logic_vector(31 downto 0);

    function is_wb_gpr(tag: std_logic_vector(4 downto 0); w1_e: std_logic; w1_t: std_logic_vector(4 downto 0); w2_e: std_logic; w2_t: std_logic_vector(4 downto 0); w3_e: std_logic; w3_t: std_logic_vector(4 downto 0)) return boolean is
    begin return (w1_e = '1' and tag = w1_t) or (w2_e = '1' and tag = w2_t) or (w3_e = '1' and tag = w3_t); end function;

    function is_wb_f(tag: std_logic_vector(4 downto 0); w1_e: std_logic; w1_t: std_logic_vector(4 downto 0); w2_e: std_logic; w2_t: std_logic_vector(4 downto 0)) return boolean is
    begin return (w1_e = '1' and tag = w1_t) or (w2_e = '1' and tag = w2_t); end function;

begin
    prs1_ready  <= '1' when is_wb_gpr(prs1, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) else not gpr_busy_mask(to_integer(unsigned(prs1)));
    prt1_ready  <= '1' when is_wb_gpr(prt1, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) else not gpr_busy_mask(to_integer(unsigned(prt1)));
    pr_flag1_ready <= '1' when is_wb_f(pr_flag1, wb_f1_en, wb_f1_tag, wb_f2_en, wb_f2_tag) else not flag_busy_mask(to_integer(unsigned(pr_flag1)));

    prs2_ready  <= '0' when (alloc_gpr1_en = '1' and prs2 = alloc_gpr1) else '1' when is_wb_gpr(prs2, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) else not gpr_busy_mask(to_integer(unsigned(prs2)));
    prt2_ready  <= '0' when (alloc_gpr1_en = '1' and prt2 = alloc_gpr1) else '1' when is_wb_gpr(prt2, wb_gpr1_en, wb_gpr1_tag, wb_gpr2_en, wb_gpr2_tag, wb_gpr3_en, wb_gpr3_tag ) else not gpr_busy_mask(to_integer(unsigned(prt2)));
    pr_flag2_ready <= '0' when (alloc_f1_en = '1' and pr_flag2 = alloc_f1) else '1' when is_wb_f(pr_flag2, wb_f1_en, wb_f1_tag, wb_f2_en, wb_f2_tag) else not flag_busy_mask(to_integer(unsigned(pr_flag2)));

    process(clk, rst)
    begin
        if rst = '1' then
            gpr_busy_mask  <= (others => '0');
            flag_busy_mask <= (others => '0');
        elsif rising_edge(clk) then
            if flush = '1' then
                gpr_busy_mask  <= (others => '0');
                flag_busy_mask <= (others => '0');
            else
                if wb_gpr1_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr1_tag))) <= '0'; end if;
                if wb_gpr2_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr2_tag))) <= '0'; end if;
                if wb_gpr3_en = '1' then gpr_busy_mask(to_integer(unsigned(wb_gpr3_tag))) <= '0'; end if;
                if wb_f1_en = '1' then flag_busy_mask(to_integer(unsigned(wb_f1_tag))) <= '0'; end if;
                if wb_f2_en = '1' then flag_busy_mask(to_integer(unsigned(wb_f2_tag))) <= '0'; end if;

                if alloc_gpr1_en = '1' then gpr_busy_mask(to_integer(unsigned(alloc_gpr1))) <= '1'; end if;
                if alloc_gpr2_en = '1' then gpr_busy_mask(to_integer(unsigned(alloc_gpr2))) <= '1'; end if;
                if alloc_f1_en = '1' then flag_busy_mask(to_integer(unsigned(alloc_f1))) <= '1'; end if;
                if alloc_f2_en = '1' then flag_busy_mask(to_integer(unsigned(alloc_f2))) <= '1'; end if;
            end if;
        end if;
    end process;

    -- =================================================================
    -- PROFESSIONAL X-RAY: CDB AND BUSY TRACKING
    -- =================================================================
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