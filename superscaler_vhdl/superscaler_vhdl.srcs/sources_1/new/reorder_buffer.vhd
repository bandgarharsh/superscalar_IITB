library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity reorder_buffer is
    Port ( 
        clk : in std_logic;
        rst : in std_logic;
        flush : in std_logic; -- 2. NEW: External flush input
        
        -- ==========================================
        -- DISPATCH INTERFACE (In-Order Allocation)
        -- ==========================================
        we1         : in std_logic;
        rob_packet1 : in std_logic_vector(44 downto 0);
        out_rob_tag1: out std_logic_vector(2 downto 0); -- 1. FIXED: 3-bit tag
        
        we2         : in std_logic;
        rob_packet2 : in std_logic_vector(44 downto 0);
        out_rob_tag2: out std_logic_vector(2 downto 0); -- 1. FIXED: 3-bit tag

        rob_free_slots : out unsigned(5 downto 0); 
        
        -- ==========================================
        -- CDB INTERFACE (Out-of-Order Completion)
        -- ==========================================
        cdb1_valid      : in std_logic;
        cdb1_rob_tag    : in std_logic_vector(2 downto 0); -- 1. FIXED: 3-bit tag
        cdb1_mispredict : in std_logic;
        cdb1_target_pc  : in std_logic_vector(15 downto 0);
        
        cdb2_valid      : in std_logic;
        cdb2_rob_tag    : in std_logic_vector(2 downto 0); -- 1. FIXED: 3-bit tag
        cdb2_mispredict : in std_logic;
        cdb2_target_pc  : in std_logic_vector(15 downto 0);
        
        -- ==========================================
        -- RETIREMENT INTERFACE (In-Order Commit)
        -- ==========================================
        rob_push_gpr1   : out std_logic; rob_freed_gpr1  : out std_logic_vector(4 downto 0);
        rob_push_flag1  : out std_logic; rob_freed_flag1 : out std_logic_vector(4 downto 0);
        rob_push_gpr2   : out std_logic; rob_freed_gpr2  : out std_logic_vector(4 downto 0);
        rob_push_flag2  : out std_logic; rob_freed_flag2 : out std_logic_vector(4 downto 0);
        
        retire1_valid   : out std_logic; 
        retire1_we_gpr  : out std_logic; -- 7. NEW: Explicit GPR write enable
        retire1_we_flag : out std_logic;
        retire1_arch_reg: out std_logic_vector(2 downto 0);
        retire1_phys_reg: out std_logic_vector(4 downto 0);
        
        retire2_valid   : out std_logic; 
        retire2_we_gpr  : out std_logic; -- 7. NEW: Explicit GPR write enable
        retire2_we_flag : out std_logic;
        retire2_arch_reg: out std_logic_vector(2 downto 0);
        retire2_phys_reg: out std_logic_vector(4 downto 0);

        -- ==========================================
        -- STORE COMMIT INTERFACE (To LSQ)
        -- ==========================================
        rob_commit1_valid : out std_logic; -- 6. NEW: Allows Store 1 to write memory
        rob_commit1_tag   : out std_logic_vector(2 downto 0);
        rob_commit2_valid : out std_logic; -- 6. NEW: Allows Store 2 to write memory
        rob_commit2_tag   : out std_logic_vector(2 downto 0);
        
        -- ==========================================
        -- PIPELINE CONTROL
        -- ==========================================
        flush_pipeline : out std_logic;
        flush_pc       : out std_logic_vector(15 downto 0)
    );
end reorder_buffer;

architecture Behavioral of reorder_buffer is
    
    constant DEPTH : integer := 8;
    
    type bit_arr  is array (0 to DEPTH-1) of std_logic;
    type arch_arr is array (0 to DEPTH-1) of std_logic_vector(2 downto 0);
    type phys_arr is array (0 to DEPTH-1) of std_logic_vector(4 downto 0);
    type pc_arr   is array (0 to DEPTH-1) of std_logic_vector(15 downto 0);
    
    signal valid      : bit_arr := (others => '0');
    signal done       : bit_arr := (others => '0');
    signal arch_reg   : arch_arr := (others => (others => '0'));
    
    signal new_gpr    : phys_arr := (others => (others => '0'));
    signal old_gpr    : phys_arr := (others => (others => '0'));
    signal we_gpr     : bit_arr := (others => '0');
    
    signal new_flag   : phys_arr := (others => (others => '0'));
    signal old_flag   : phys_arr := (others => (others => '0'));
    signal we_flag    : bit_arr := (others => '0');
    
    signal is_branch  : bit_arr := (others => '0');
    signal is_store   : bit_arr := (others => '0');
    signal mispredict : bit_arr := (others => '0');
    signal target_pc  : pc_arr := (others => (others => '0'));
    signal pc         : pc_arr := (others => (others => '0')); -- NEW: Stores instruction PC
    
    signal head  : integer range 0 to DEPTH-1 := 0;
    signal tail  : integer range 0 to DEPTH-1 := 0;
    signal count : integer range 0 to DEPTH := 0;
    
begin
    
    out_rob_tag1 <= std_logic_vector(to_unsigned(tail, 3));
    out_rob_tag2 <= std_logic_vector(to_unsigned((tail + 1) mod DEPTH, 3));
    
    rob_free_slots <= to_unsigned(DEPTH - count, 6);
    
    process(clk, rst, flush)
        variable next_head  : integer range 0 to DEPTH-1;
        variable next_tail  : integer range 0 to DEPTH-1;
        variable pops       : integer range 0 to 2;
        variable pushes     : integer range 0 to 2;
        variable head_plus1 : integer range 0 to DEPTH-1;
        variable do_flush   : boolean; 
    begin
        if rst = '1' or flush = '1' then
            head <= 0; tail <= 0; count <= 0;
            valid <= (others => '0'); done <= (others => '0');
            flush_pipeline <= '0';
       
        elsif rising_edge(clk) then
            
            pops := 0; pushes := 0;
            next_head := head; next_tail := tail;
            head_plus1 := (head + 1) mod DEPTH;
            
            do_flush := false;
            flush_pipeline <= '0';
            
            retire1_valid <= '0'; retire2_valid <= '0';
            retire1_we_gpr <= '0'; retire2_we_gpr <= '0';
            rob_push_gpr1 <= '0'; rob_push_flag1 <= '0';
            rob_push_gpr2 <= '0'; rob_push_flag2 <= '0';
            
            rob_commit1_valid <= '0'; rob_commit1_tag <= (others => '0');
            rob_commit2_valid <= '0'; rob_commit2_tag <= (others => '0');
            
            -- =======================================================
            -- 1. CDB SNOOPING (Out-of-Order Completion)
            -- =======================================================
            if cdb1_valid = '1' then
                done(to_integer(unsigned(cdb1_rob_tag))) <= '1';
                mispredict(to_integer(unsigned(cdb1_rob_tag))) <= cdb1_mispredict;
                target_pc(to_integer(unsigned(cdb1_rob_tag))) <= cdb1_target_pc;
            end if;
            
            if cdb2_valid = '1' then
                done(to_integer(unsigned(cdb2_rob_tag))) <= '1';
                mispredict(to_integer(unsigned(cdb2_rob_tag))) <= cdb2_mispredict;
                target_pc(to_integer(unsigned(cdb2_rob_tag))) <= cdb2_target_pc;
            end if;
            
            -- =======================================================
            -- 2. IN-ORDER RETIREMENT & FLUSH CHECK
            -- =======================================================
            if valid(head) = '1' and done(head) = '1' then
                
                -- Retire Slot 1 universally
                valid(head) <= '0';
                pops := 1; next_head := head_plus1;
                
                retire1_valid    <= '1'; 
                retire1_we_gpr   <= we_gpr(head);
                retire1_we_flag  <= we_flag(head);
                retire1_arch_reg <= arch_reg(head);
                retire1_phys_reg <= new_gpr(head);
                
                rob_push_gpr1  <= we_gpr(head);  rob_freed_gpr1  <= old_gpr(head);
                rob_push_flag1 <= we_flag(head); rob_freed_flag1 <= old_flag(head);

                -- 6. STORE COMMIT: Trigger LSQ to write memory!
                if is_store(head) = '1' then
                    rob_commit1_valid <= '1';
                    rob_commit1_tag   <= std_logic_vector(to_unsigned(head, 3));
                end if;

                -- 3. BRANCH MISPREDICT: Retire the branch, flush only the younger instructions!
                if is_branch(head) = '1' and mispredict(head) = '1' then
                    do_flush := true;
                    flush_pipeline <= '1';
                    flush_pc <= target_pc(head);
                    
                    valid <= (others => '0'); done <= (others => '0');
                    head <= head_plus1;
                    tail <= head_plus1;
                    count <= 0;
                else
                    -- Check if Slot 2 can also retire safely
                    if valid(head_plus1) = '1' and done(head_plus1) = '1' then
                        valid(head_plus1) <= '0';
                        pops := 2; next_head := (head + 2) mod DEPTH;
                        
                        retire2_valid    <= '1';
                        retire2_we_gpr   <= we_gpr(head_plus1);
                        retire2_we_flag  <= we_flag(head_plus1);
                        retire2_arch_reg <= arch_reg(head_plus1);
                        retire2_phys_reg <= new_gpr(head_plus1);
                        
                        rob_push_gpr2  <= we_gpr(head_plus1);  rob_freed_gpr2  <= old_gpr(head_plus1);
                        rob_push_flag2 <= we_flag(head_plus1); rob_freed_flag2 <= old_flag(head_plus1);

                        if is_store(head_plus1) = '1' then
                            rob_commit2_valid <= '1';
                            rob_commit2_tag   <= std_logic_vector(to_unsigned(head_plus1, 3));
                        end if;

                        if is_branch(head_plus1) = '1' and mispredict(head_plus1) = '1' then
                            do_flush := true;
                            flush_pipeline <= '1';
                            flush_pc <= target_pc(head_plus1);
                            
                            valid <= (others => '0'); done <= (others => '0');
                            head <= (head + 2) mod DEPTH;
                            tail <= (head + 2) mod DEPTH;
                            count <= 0;
                        end if;
                    end if;
                end if;
            end if;
            
            -- =======================================================
            -- 3. IN-ORDER ALLOCATION (Dispatch)
            -- =======================================================
            if not do_flush then
                
                if we1 = '1' then
                    valid(next_tail) <= '1'; done(next_tail) <= '0';
                    
                    arch_reg(next_tail) <= rob_packet1(44 downto 42);
                    new_gpr(next_tail)  <= rob_packet1(41 downto 37);
                    old_gpr(next_tail)  <= rob_packet1(36 downto 32);
                    new_flag(next_tail) <= rob_packet1(31 downto 27);
                    old_flag(next_tail) <= rob_packet1(26 downto 22);
                    we_flag(next_tail)  <= rob_packet1(21);
                    we_gpr(next_tail)   <= rob_packet1(20);
                    pc(next_tail)       <= rob_packet1(15 downto 0);
                    
                    -- 5. FIXED: Decoding IITB-RISC Branches correctly
                    if rob_packet1(19 downto 16) = "1100" or rob_packet1(19 downto 16) = "1000" or rob_packet1(19 downto 16) = "1001" then 
                        is_branch(next_tail) <= '1'; else is_branch(next_tail) <= '0'; 
                    end if;
                    
                    if rob_packet1(19 downto 16) = "0101" then is_store(next_tail) <= '1'; else is_store(next_tail) <= '0'; end if;
                    
                    pushes := pushes + 1;
                    next_tail := (next_tail + 1) mod DEPTH;
                end if;
                
                if we2 = '1' then
                    valid(next_tail) <= '1'; done(next_tail) <= '0';
                    
                    arch_reg(next_tail) <= rob_packet2(44 downto 42);
                    new_gpr(next_tail)  <= rob_packet2(41 downto 37);
                    old_gpr(next_tail)  <= rob_packet2(36 downto 32);
                    new_flag(next_tail) <= rob_packet2(31 downto 27);
                    old_flag(next_tail) <= rob_packet2(26 downto 22);
                    we_flag(next_tail)  <= rob_packet2(21);
                    we_gpr(next_tail)   <= rob_packet2(20);
                    pc(next_tail)       <= rob_packet2(15 downto 0);
                    
                    if rob_packet2(19 downto 16) = "1100" or rob_packet2(19 downto 16) = "1000" or rob_packet2(19 downto 16) = "1001" then 
                        is_branch(next_tail) <= '1'; else is_branch(next_tail) <= '0'; 
                    end if;
                    
                    if rob_packet2(19 downto 16) = "0101" then is_store(next_tail) <= '1'; else is_store(next_tail) <= '0'; end if;
                    
                    pushes := pushes + 1;
                    next_tail := (next_tail + 1) mod DEPTH;
                end if;
                
                head <= next_head;
                tail <= next_tail;
                count <= count + pushes - pops;
            end if;
            
        end if;
    end process;              
end Behavioral;