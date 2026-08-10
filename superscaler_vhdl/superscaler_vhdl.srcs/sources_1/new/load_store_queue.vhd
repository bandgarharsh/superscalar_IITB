library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity load_store_queue is
  Port ( 
        clk         : in std_logic;
        rst         : in std_logic;
        flush       : in std_logic;
        
        -- --- 1. DISPATCH INTERFACE ---
        we1             : in std_logic;
        rs_packet1      : in std_logic_vector(63 downto 0); -- FIXED: Symmetric and clean
        rob_tag1        : in std_logic_vector(4 downto 0);
        d1_vbase_valid  : in std_logic;
        d1_vbase_data   : in std_logic_vector(15 downto 0);
        d1_vdata_valid  : in std_logic;
        d1_vdata_data   : in std_logic_vector(15 downto 0);
        
        we2             : in std_logic;
        rs_packet2      : in std_logic_vector(63 downto 0); -- FIXED: Symmetric and clean
        rob_tag2        : in std_logic_vector(4 downto 0);
        d2_vbase_valid  : in std_logic;
        d2_vbase_data   : in std_logic_vector(15 downto 0);
        d2_vdata_valid  : in std_logic;
        d2_vdata_data   : in std_logic_vector(15 downto 0);
        
        -- --- 2. COMMON DATA BUS INTERFACE (Snooping) ---
        cdb1_valid : in std_logic;
        cdb1_tag   : in std_logic_vector(4 downto 0);
        cdb1_data  : in std_logic_vector(15 downto 0);
        
        cdb2_valid : in std_logic;
        cdb2_tag   : in std_logic_vector(4 downto 0);
        cdb2_data  : in std_logic_vector(15 downto 0);

        -- --- 3. ROB COMMIT INTERFACE (Prevents Speculative Stores) ---
        rob_commit1_valid : in std_logic;
        rob_commit1_tag   : in std_logic_vector(4 downto 0);
        
        rob_commit2_valid : in std_logic;
        rob_commit2_tag   : in std_logic_vector(4 downto 0);
        
        -- --- 4. ISSUE INTERFACE (To Memory ALU) ---
        issue_ready : in std_logic; -- FIXED: ALU handshake added
        issue_valid : out std_logic;
        issue_is_st : out std_logic;
        issue_addr  : out std_logic_vector(15 downto 0);
        issue_data  : out std_logic_vector(15 downto 0);
        issue_dest  : out std_logic_vector(4 downto 0);
        issue_rob   : out std_logic_vector(4 downto 0);
        
        available_slots : out std_logic_vector(2 downto 0)
  );
end load_store_queue;

architecture Behavioral of load_store_queue is
    
    constant DEPTH : integer := 4;
    
    type bit_arr  is array (0 to DEPTH-1) of std_logic;
    type data_arr is array (0 to DEPTH-1) of std_logic_vector(15 downto 0);
    type tag_arr  is array (0 to DEPTH-1) of std_logic_vector(4 downto 0);
    
    signal valid      : bit_arr := (others => '0');
    signal is_store   : bit_arr := (others => '0');
    signal offset     : data_arr := (others => (others => '0'));
    signal dest_pr    : tag_arr := (others => (others => '0'));
    signal rob_tag    : tag_arr := (others => (others => '0'));
    
    signal base_v_val : bit_arr := (others => '0');
    signal base_v     : data_arr := (others => (others => '0'));
    signal base_q     : tag_arr := (others => (others => '0'));
    
    signal data_v_val : bit_arr := (others => '0');
    signal data_v     : data_arr := (others => (others => '0'));
    signal data_q     : tag_arr := (others => (others => '0'));

    signal committed  : bit_arr := (others => '0'); 
    
    signal head  : integer range 0 to DEPTH-1 := 0;
    signal tail  : integer range 0 to DEPTH-1 := 0;
    signal count : integer range 0 to DEPTH := 0; 
    
    signal head_ready : std_logic;
    
begin

    available_slots <= std_logic_vector(to_unsigned(DEPTH - count, 3));
    
    head_ready <= '1' when (valid(head) = '1' and
                            base_v_val(head) = '1' and
                            (is_store(head) = '0' or (data_v_val(head) = '1' and committed(head) = '1')))
                      else '0';
                      
    issue_valid <= head_ready;
    issue_is_st <= is_store(head);
    
    -- Address calculation uses signed arithmetic for correct offset mapping
    issue_addr <= std_logic_vector(signed(base_v(head)) + signed(offset(head)));
    issue_data <= data_v(head);
    issue_dest <= dest_pr(head);
    issue_rob  <= rob_tag(head);
    
    process(clk, rst)
        variable next_tail  : integer range 0 to DEPTH-1;
        variable next_head  : integer range 0 to DEPTH-1;
        variable pops       : integer range 0 to 1;
        variable pushes     : integer range 0 to 2;
        variable actually_issued : std_logic;
    begin
        if rst = '1' then
            head <= 0; tail <= 0; count <= 0;
            valid <= (others => '0');
            committed <= (others => '0');
            
        elsif rising_edge(clk) then
            
            -- Full queue wipe on flush (To be upgraded with ROB rollback later)
            if flush = '1' then
                head <= 0; tail <= 0; count <= 0;
                valid <= (others => '0');
                committed <= (others => '0');
            else
                pops := 0; pushes := 0;
                next_tail := tail; next_head := head;
                
                -- FIXED: Handshake evaluated before popping
                actually_issued := head_ready and issue_ready;
                
                if actually_issued = '1' then
                    valid(head) <= '0';
                    committed(head) <= '0';
                    pops := 1;
                    if head = DEPTH-1 then next_head := 0; else next_head := head + 1; end if;
                end if;
                
                -- Slot 1 Push
                if we1 = '1' then
                    valid(next_tail) <= '1';
                    committed(next_tail) <= '0'; 
                    
                    if rs_packet1(63 downto 60) = "0101" then is_store(next_tail) <= '1'; else is_store(next_tail) <= '0'; end if;
                    
                    offset(next_tail)  <= rs_packet1(34 downto 19);
                    dest_pr(next_tail) <= rs_packet1(59 downto 55);
                    base_q(next_tail)  <= rs_packet1(49 downto 45);
                    data_q(next_tail)  <= rs_packet1(44 downto 40);
                    
                    rob_tag(next_tail) <= rob_tag1;
                    base_v_val(next_tail) <= d1_vbase_valid; base_v(next_tail) <= d1_vbase_data;
                    data_v_val(next_tail) <= d1_vdata_valid; data_v(next_tail) <= d1_vdata_data;
                    
                    pushes := pushes + 1;
                    if next_tail = DEPTH-1 then next_tail := 0; else next_tail := next_tail + 1; end if;
                end if;
                
                -- Slot 2 Push
                if we2 = '1' then
                    valid(next_tail) <= '1';
                    committed(next_tail) <= '0';
                    
                    if rs_packet2(63 downto 60) = "0101" then is_store(next_tail) <= '1'; else is_store(next_tail) <= '0'; end if;
                    
                    offset(next_tail)  <= rs_packet2(34 downto 19); 
                    dest_pr(next_tail) <= rs_packet2(59 downto 55);
                    base_q(next_tail)  <= rs_packet2(49 downto 45); 
                    data_q(next_tail)  <= rs_packet2(44 downto 40);
                    
                    rob_tag(next_tail) <= rob_tag2;
                    base_v_val(next_tail) <= d2_vbase_valid; base_v(next_tail) <= d2_vbase_data;
                    data_v_val(next_tail) <= d2_vdata_valid; data_v(next_tail) <= d2_vdata_data;
                    
                    pushes := pushes + 1;
                    if next_tail = DEPTH-1 then next_tail := 0; else next_tail := next_tail + 1; end if;
                end if;
                
                head <= next_head;
                tail <= next_tail;
                count <= count + pushes - pops;
                
                -- CDB Snooping & ROB Commit Listening
                for i in 0 to DEPTH-1 loop
                    if valid(i) = '1' then
                        
                        -- Listen for ROB Commits
                        if is_store(i) = '1' then
                            if rob_commit1_valid = '1' and rob_tag(i) = rob_commit1_tag then
                                committed(i) <= '1';
                            elsif rob_commit2_valid = '1' and rob_tag(i) = rob_commit2_tag then
                                committed(i) <= '1';
                            end if;
                        end if;

                        -- Listen for CDB Data
                        if base_v_val(i) = '0' then
                            if cdb1_valid = '1' and base_q(i) = cdb1_tag then
                                base_v(i) <= cdb1_data; base_v_val(i) <= '1'; 
                            elsif cdb2_valid = '1' and base_q(i) = cdb2_tag then
                                base_v(i) <= cdb2_data; base_v_val(i) <= '1';       
                            end if;
                        end if;
                        
                        if is_store(i) = '1' and data_v_val(i) = '0' then
                            if cdb1_valid = '1' and data_q(i) = cdb1_tag then
                                data_v(i) <= cdb1_data; data_v_val(i) <= '1'; 
                            elsif cdb2_valid = '1' and data_q(i) = cdb2_tag then
                                data_v(i) <= cdb2_data; data_v_val(i) <= '1';       
                            end if;
                        end if;
                        
                    end if;
                end loop;
            end if;
        end if; 
    end process;
end Behavioral;