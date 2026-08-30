library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

----------------------------------------------------------------------------------
-- MODULE: Physical Register Free List
-- DESCRIPTION:
--   Tracks available physical GPRs and Flag registers.
--   Uses a 32-bit vector mask (1 = Free, 0 = Allocated). 
--   Combinational priority encoders scan the mask right-to-left to find the 
--   next available physical registers during the dispatch phase.
----------------------------------------------------------------------------------
entity free_list is
    Port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        
        -- Recovery Interface (From Commit Stage)
        flush               : in  std_logic;
        commit_gpr_mask     : in  std_logic_vector(31 downto 0);
        commit_flag_mask    : in  std_logic_vector(31 downto 0);

        -- GPR Allocation Interface (To Rename Stage)
        req_gpr1            : in  std_logic;
        req_gpr2            : in  std_logic;
        alloc_gpr1          : out std_logic_vector(4 downto 0);
        alloc_gpr2          : out std_logic_vector(4 downto 0);
        avail_gprs          : out unsigned(1 downto 0); 

        -- Flag Allocation Interface (To Rename Stage)
        req_flag1           : in  std_logic;
        req_flag2           : in  std_logic;
        alloc_flag1         : out std_logic_vector(4 downto 0);
        alloc_flag2         : out std_logic_vector(4 downto 0);
        avail_flags         : out unsigned(1 downto 0); 

        -- Deallocation Interface (From Commit Stage)
        free_gpr1_en        : in  std_logic;
        free_gpr1_tag       : in  std_logic_vector(4 downto 0);
        free_gpr2_en        : in  std_logic;
        free_gpr2_tag       : in  std_logic_vector(4 downto 0);

        free_flag1_en       : in  std_logic;
        free_flag1_tag      : in  std_logic_vector(4 downto 0);
        free_flag2_en       : in  std_logic;
        free_flag2_tag      : in  std_logic_vector(4 downto 0)
    );
end free_list;

architecture Behavioral of free_list is

    -- 1 = Register is free to be allocated
    -- 0 = Register is currently in-flight
    signal gpr_mask  : std_logic_vector(31 downto 0);
    signal flag_mask : std_logic_vector(31 downto 0);

    -- Priority encoder mapping signals
    signal gpr_idx1, gpr_idx2   : integer range 0 to 31;
    signal flag_idx1, flag_idx2 : integer range 0 to 31;
    signal gpr_avail1, gpr_avail2   : boolean;
    signal flag_avail1, flag_avail2 : boolean;

begin

    -- Combinational Priority Encoders: Scan bit-masks to locate up to two free physical registers
    process(gpr_mask, flag_mask)
        variable v_gpr_idx1, v_gpr_idx2   : integer range 0 to 31;
        variable v_flag_idx1, v_flag_idx2 : integer range 0 to 31;
        variable v_gpr_found1, v_gpr_found2   : boolean;
        variable v_flag_found1, v_flag_found2 : boolean;
    begin
        -- Base initialization
        v_gpr_found1 := false; v_gpr_found2 := false;
        v_flag_found1 := false; v_flag_found2 := false;
        v_gpr_idx1 := 0; v_gpr_idx2 := 0;
        v_flag_idx1 := 0; v_flag_idx2 := 0;

        -- Extract up to two free GPRs
        for i in 0 to 31 loop
            if gpr_mask(i) = '1' then
                if not v_gpr_found1 then
                    v_gpr_idx1 := i;
                    v_gpr_found1 := true;
                elsif not v_gpr_found2 then
                    v_gpr_idx2 := i;
                    v_gpr_found2 := true;
                end if;
            end if;
        end loop;

        -- Extract up to two free Flag registers
        for i in 0 to 31 loop
            if flag_mask(i) = '1' then
                if not v_flag_found1 then
                    v_flag_idx1 := i;
                    v_flag_found1 := true;
                elsif not v_flag_found2 then
                    v_flag_idx2 := i;
                    v_flag_found2 := true;
                end if;
            end if;
        end loop;

        -- Bind calculation variables to datapath
        gpr_idx1 <= v_gpr_idx1; gpr_idx2 <= v_gpr_idx2;
        gpr_avail1 <= v_gpr_found1; gpr_avail2 <= v_gpr_found2;

        flag_idx1 <= v_flag_idx1; flag_idx2 <= v_flag_idx2;
        flag_avail1 <= v_flag_found1; flag_avail2 <= v_flag_found2;
    end process;

    -- Format derived indices into 5-bit physical tags
    alloc_gpr1 <= std_logic_vector(to_unsigned(gpr_idx1, 5));
    alloc_gpr2 <= std_logic_vector(to_unsigned(gpr_idx2, 5));
    alloc_flag1 <= std_logic_vector(to_unsigned(flag_idx1, 5));
    alloc_flag2 <= std_logic_vector(to_unsigned(flag_idx2, 5));

    -- Quantify available resources for the dispatch control logic
    process(gpr_avail1, gpr_avail2, flag_avail1, flag_avail2)
    begin
        if gpr_avail2 then avail_gprs <= "10";
        elsif gpr_avail1 then avail_gprs <= "01";
        else avail_gprs <= "00"; end if;
        
        if flag_avail2 then avail_flags <= "10";
        elsif flag_avail1 then avail_flags <= "01";
        else avail_flags <= "00"; end if;
    end process;

    -- Sequential Next-State Logic: Process active allocations and retired deallocations
    process(clk, rst)
        variable next_gpr_mask  : std_logic_vector(31 downto 0);
        variable next_flag_mask : std_logic_vector(31 downto 0);
    begin
        if rst = '1' then
            gpr_mask <= x"FFFFFF00"; 
            flag_mask <= x"FFFFFFFE";
        elsif rising_edge(clk) then
            if flush = '1' then
                -- Hard reset vectors on branch mispredict using known-safe state from RRAT
                gpr_mask  <= commit_gpr_mask;
                flag_mask <= commit_flag_mask;
            else
                next_gpr_mask  := gpr_mask;
                next_flag_mask := flag_mask;

                -- Step 1: Claim requested registers (Clear bit to '0')
                if req_gpr1 = '1' and gpr_avail1 then next_gpr_mask(gpr_idx1) := '0'; end if;
                if req_gpr2 = '1' and gpr_avail2 then next_gpr_mask(gpr_idx2) := '0'; end if;
                if req_flag1 = '1' and flag_avail1 then next_flag_mask(flag_idx1) := '0'; end if;
                if req_flag2 = '1' and flag_avail2 then next_flag_mask(flag_idx2) := '0'; end if;

                -- Step 2: Recycle retired registers from Commit Stage (Set bit back to '1')
                if free_gpr1_en = '1' then next_gpr_mask(to_integer(unsigned(free_gpr1_tag))) := '1'; end if;
                if free_gpr2_en = '1' then next_gpr_mask(to_integer(unsigned(free_gpr2_tag))) := '1'; end if;
                if free_flag1_en = '1' then next_flag_mask(to_integer(unsigned(free_flag1_tag))) := '1'; end if;
                if free_flag2_en = '1' then next_flag_mask(to_integer(unsigned(free_flag2_tag))) := '1'; end if;

                -- Latch modifications
                gpr_mask  <= next_gpr_mask;
                flag_mask <= next_flag_mask;
            end if;
        end if;
    end process;

    -- Logging trace
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                if flush = '1' then
                    write(l, string'("[FREE LIST] FLUSHED -> Masks Restored to Safe Commit State"));
                    writeline(output, l);
                else
                    -- Outbound Allocations
                    if req_gpr1 = '1' and gpr_avail1 then
                        write(l, string'("[FREE LIST] ALLOCATED GPR -> Phys P"));
                        write(l, integer'image(gpr_idx1));
                        writeline(output, l);
                    end if;
                    if req_gpr2 = '1' and gpr_avail2 then
                        write(l, string'("[FREE LIST] ALLOCATED GPR -> Phys P"));
                        write(l, integer'image(gpr_idx2));
                        writeline(output, l);
                    end if;

                    -- Inbound Deallocations
                    if free_gpr1_en = '1' then
                        write(l, string'("[FREE LIST] FREED GPR -> Phys P"));
                        write(l, integer'image(to_integer(unsigned(free_gpr1_tag))));
                        writeline(output, l);
                    end if;
                    if free_gpr2_en = '1' then
                        write(l, string'("[FREE LIST] FREED GPR -> Phys P"));
                        write(l, integer'image(to_integer(unsigned(free_gpr2_tag))));
                        writeline(output, l);
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;