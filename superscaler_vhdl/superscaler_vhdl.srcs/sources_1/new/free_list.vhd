library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity free_list is
    Port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        
        -- --- RECOVERY (From Commit Stage) ---
        flush               : in  std_logic;
        commit_gpr_mask     : in  std_logic_vector(31 downto 0);
        commit_flag_mask    : in  std_logic_vector(31 downto 0);

        -- ==========================================
        -- GPR ALLOCATION (To Rename)
        -- ==========================================
        req_gpr1            : in  std_logic;
        req_gpr2            : in  std_logic;
        alloc_gpr1          : out std_logic_vector(4 downto 0);
        alloc_gpr2          : out std_logic_vector(4 downto 0);
        avail_gprs          : out unsigned(1 downto 0); -- UPDATED: Outputs 0, 1, or 2+

        -- ==========================================
        -- FLAG ALLOCATION (To Rename)
        -- ==========================================
        req_flag1           : in  std_logic;
        req_flag2           : in  std_logic;
        alloc_flag1         : out std_logic_vector(4 downto 0);
        alloc_flag2         : out std_logic_vector(4 downto 0);
        avail_flags         : out unsigned(1 downto 0); -- UPDATED: Outputs 0, 1, or 2+

        -- ==========================================
        -- DEALLOCATION (From Commit Stage)
        -- ==========================================
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

    -- 1 = Free, 0 = Allocated
    signal gpr_mask  : std_logic_vector(31 downto 0);
    signal flag_mask : std_logic_vector(31 downto 0);

    -- Internal signals for the priority encoders
    signal gpr_idx1, gpr_idx2   : integer range 0 to 31;
    signal flag_idx1, flag_idx2 : integer range 0 to 31;
    signal gpr_avail1, gpr_avail2   : boolean;
    signal flag_avail1, flag_avail2 : boolean;

begin

    -- =================================================================
    -- 1. COMBINATIONAL PRIORITY ENCODERS (Scan right-to-left)
    -- =================================================================
    process(gpr_mask, flag_mask)
        variable v_gpr_idx1, v_gpr_idx2   : integer range 0 to 31;
        variable v_flag_idx1, v_flag_idx2 : integer range 0 to 31;
        variable v_gpr_found1, v_gpr_found2   : boolean;
        variable v_flag_found1, v_flag_found2 : boolean;
    begin
        -- Initialize
        v_gpr_found1 := false; v_gpr_found2 := false;
        v_flag_found1 := false; v_flag_found2 := false;
        v_gpr_idx1 := 0; v_gpr_idx2 := 0;
        v_flag_idx1 := 0; v_flag_idx2 := 0;

        -- Scan GPR Mask for the first two '1's
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

        -- Scan Flag Mask for the first two '1's
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

        -- Map variables to signals
        gpr_idx1 <= v_gpr_idx1; gpr_idx2 <= v_gpr_idx2;
        gpr_avail1 <= v_gpr_found1; gpr_avail2 <= v_gpr_found2;

        flag_idx1 <= v_flag_idx1; flag_idx2 <= v_flag_idx2;
        flag_avail1 <= v_flag_found1; flag_avail2 <= v_flag_found2;
    end process;

    -- Assign Tag outputs
    alloc_gpr1 <= std_logic_vector(to_unsigned(gpr_idx1, 5));
    alloc_gpr2 <= std_logic_vector(to_unsigned(gpr_idx2, 5));
    alloc_flag1 <= std_logic_vector(to_unsigned(flag_idx1, 5));
    alloc_flag2 <= std_logic_vector(to_unsigned(flag_idx2, 5));

    -- =================================================================
    -- 2. RESOURCE COUNTING (New Logic to replace 'empty')
    -- =================================================================
    -- This converts the boolean "found" flags into a 2-bit unsigned number
    -- that the top-level RR_stage can use for its Atomic Handshake.
    process(gpr_avail1, gpr_avail2, flag_avail1, flag_avail2)
    begin
        -- GPR Count
        if gpr_avail2 then
            avail_gprs <= "10"; -- 2 or more available
        elsif gpr_avail1 then
            avail_gprs <= "01"; -- exactly 1 available
        else
            avail_gprs <= "00"; -- 0 available
        end if;
        
        -- Flag Count
        if flag_avail2 then
            avail_flags <= "10";
        elsif flag_avail1 then
            avail_flags <= "01";
        else
            avail_flags <= "00";
        end if;
    end process;


    -- =================================================================
    -- 3. SEQUENTIAL NEXT-STATE LOGIC (Update the masks)
    -- =================================================================
    process(clk, rst)
        variable next_gpr_mask  : std_logic_vector(31 downto 0);
        variable next_flag_mask : std_logic_vector(31 downto 0);
    begin
        if rst = '1' then
            -- At reset: P0-P7 are mapped to R0-R7 (Busy = 0). P8-P31 are Free (1).
            gpr_mask <= x"FFFFFF00"; 
            
            -- At reset: F0 is the initial flag state (Busy = 0). F1-F31 are Free (1).
            flag_mask <= x"FFFFFFFE";

        elsif rising_edge(clk) then
            if flush = '1' then
                -- Instant recovery from branch mispredict
                gpr_mask  <= commit_gpr_mask;
                flag_mask <= commit_flag_mask;
            else
                -- Start with current masks
                next_gpr_mask  := gpr_mask;
                next_flag_mask := flag_mask;

                -- A. Process Allocations (Set bits to 0)
                -- Because the RR_stage passes 'dispatch_fire' into req_gpr1/2,
                -- we will ONLY clear these bits if the bundle was fully accepted!
                if req_gpr1 = '1' and gpr_avail1 then
                    next_gpr_mask(gpr_idx1) := '0';
                end if;
                if req_gpr2 = '1' and gpr_avail2 then
                    next_gpr_mask(gpr_idx2) := '0';
                end if;

                if req_flag1 = '1' and flag_avail1 then
                    next_flag_mask(flag_idx1) := '0';
                end if;
                if req_flag2 = '1' and flag_avail2 then
                    next_flag_mask(flag_idx2) := '0';
                end if;

                -- B. Process Deallocations from Commit (Set bits to 1)
                if free_gpr1_en = '1' then
                    next_gpr_mask(to_integer(unsigned(free_gpr1_tag))) := '1';
                end if;
                if free_gpr2_en = '1' then
                    next_gpr_mask(to_integer(unsigned(free_gpr2_tag))) := '1';
                end if;

                if free_flag1_en = '1' then
                    next_flag_mask(to_integer(unsigned(free_flag1_tag))) := '1';
                end if;
                if free_flag2_en = '1' then
                    next_flag_mask(to_integer(unsigned(free_flag2_tag))) := '1';
                end if;

                -- Update registers
                gpr_mask  <= next_gpr_mask;
                flag_mask <= next_flag_mask;
            end if;
        end if;
    end process;

end Behavioral;