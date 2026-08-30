library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; -- NEW: Clean Logging!
use work.iitb_risc_pkg.ALL; 

entity ROB is
    Port (
        clk                 : in std_logic;
        rst                 : in std_logic;
        global_flush        : out std_logic;
        flush_target_pc     : out std_logic_vector(15 downto 0);

        disp_valid_1        : in std_logic;
        disp_packet_1       : in dispatch_packet_t; 
        disp_valid_2        : in std_logic;
        disp_packet_2       : in dispatch_packet_t; 
        
        dispatch_stall      : in std_logic;
        
        rob_tail_id1        : out std_logic_vector(3 downto 0);
        rob_tail_id2        : out std_logic_vector(3 downto 0);
        rob_full            : out std_logic;
        rob_free_count      : out unsigned(4 downto 0);
        
        alu_complete        : in std_logic;
        alu_rob_id          : in std_logic_vector(3 downto 0);
        alu_data            : in std_logic_vector(15 downto 0);
        alu_flags           : in std_logic_vector(1 downto 0);
        alu_cond_fail       : in std_logic; 
        
        lsu_complete        : in std_logic;
        lsu_rob_id          : in std_logic_vector(3 downto 0);
        lsu_data            : in std_logic_vector(15 downto 0);
        lsu_flags           : in std_logic_vector(1 downto 0);
        
        br_complete         : in std_logic;
        br_rob_id           : in std_logic_vector(3 downto 0);
        br_data             : in std_logic_vector(15 downto 0); 
        br_mispredicted     : in std_logic;
        br_correct_target   : in std_logic_vector(15 downto 0);
        
        sq_complete         : in std_logic;
        sq_rob_id           : in std_logic_vector(3 downto 0);

        commit_valid_1      : out std_logic;
        commit_arch_dest_1  : out std_logic_vector(2 downto 0);
        commit_pd_1         : out std_logic_vector(4 downto 0); 
        commit_data_1       : out std_logic_vector(15 downto 0);
        commit_flag_valid_1 : out std_logic;                      
        commit_pf_1         : out std_logic_vector(4 downto 0);   
        commit_flag_1       : out std_logic_vector(1 downto 0);
        
        commit_valid_2      : out std_logic;
        commit_arch_dest_2  : out std_logic_vector(2 downto 0);
        commit_pd_2         : out std_logic_vector(4 downto 0);
        commit_data_2       : out std_logic_vector(15 downto 0);
        commit_flag_valid_2 : out std_logic;                      
        commit_pf_2         : out std_logic_vector(4 downto 0);   
        commit_flag_2       : out std_logic_vector(1 downto 0);
        
        commit_store_valid  : out std_logic; 
        commit_store_id     : out std_logic_vector(3 downto 0)
    );
end ROB;

architecture Behavioral of ROB is
    type rob_array_t is array (0 to 15) of rob_entry_t;
    signal rob_mem : rob_array_t;
    
    signal head_ptr : unsigned(3 downto 0);
    signal tail_ptr : unsigned(3 downto 0);
    signal entry_count : unsigned(4 downto 0); 
    signal is_full  : std_logic;
    
    signal last_allocated_pc1 : std_logic_vector(15 downto 0) := (others => 'U');
    signal last_allocated_pc2 : std_logic_vector(15 downto 0) := (others => 'U');
    
    -- X-Ray Signals
    signal log_flush : std_logic := '0';
    signal log_flush_pc : std_logic_vector(15 downto 0);
    
    signal commit_valid_1_s : std_logic;
    signal commit_arch_dest_1_s : std_logic_vector(2 downto 0);
    signal commit_pd_1_s : std_logic_vector(4 downto 0);
    signal commit_data_1_s : std_logic_vector(15 downto 0);
    
    signal commit_valid_2_s : std_logic;
    signal commit_arch_dest_2_s : std_logic_vector(2 downto 0);
    signal commit_pd_2_s : std_logic_vector(4 downto 0);
    signal commit_data_2_s : std_logic_vector(15 downto 0);
    
begin
    is_full  <= '1' when entry_count >= 14 else '0';
    rob_full <= is_full;
    rob_free_count <= to_unsigned(16, 5) - entry_count;
    rob_tail_id1 <= std_logic_vector(tail_ptr);
    rob_tail_id2 <= std_logic_vector(tail_ptr + 1);
    
    commit_valid_1 <= commit_valid_1_s;
    commit_arch_dest_1 <= commit_arch_dest_1_s;
    commit_pd_1 <= commit_pd_1_s;
    commit_data_1 <= commit_data_1_s;
    
    commit_valid_2 <= commit_valid_2_s;
    commit_arch_dest_2 <= commit_arch_dest_2_s;
    commit_pd_2 <= commit_pd_2_s;
    commit_data_2 <= commit_data_2_s;
    
    process(clk)
        variable v_rob        : rob_array_t;
        variable v_head       : unsigned(3 downto 0);
        variable v_tail       : unsigned(3 downto 0);
        variable v_count      : unsigned(4 downto 0);
        variable v_commits    : integer range 0 to 2;
        variable v_idx1       : integer;
        variable v_idx2       : integer;
        variable v_store_used : boolean;
        variable v_flush      : std_logic; 
    begin
        if rising_edge(clk) then
            log_flush <= '0';
            
            if rst = '1' then
                for i in 0 to 15 loop v_rob(i).valid := '0'; end loop;
                v_head  := (others => '0'); v_tail  := (others => '0'); v_count := (others => '0');
                global_flush <= '0'; commit_valid_1_s <= '0'; commit_valid_2_s <= '0';
                commit_flag_valid_1 <= '0'; commit_flag_valid_2 <= '0'; commit_store_valid <= '0';
                last_allocated_pc1 <= (others => 'U'); last_allocated_pc2 <= (others => 'U');
            else
                v_rob   := rob_mem; v_head  := head_ptr; v_tail  := tail_ptr; v_count := entry_count;
                v_flush := '0'; global_flush <= '0'; commit_valid_1_s <= '0'; commit_valid_2_s <= '0';
                commit_flag_valid_1 <= '0'; commit_flag_valid_2 <= '0'; commit_store_valid <= '0';

                -- PHASE 1: COMMIT
                v_commits := 0; v_store_used := false;
                v_idx1 := to_integer(v_head); v_idx2 := to_integer(v_head + 1); 

                if v_rob(v_idx1).valid = '1' and v_rob(v_idx1).executed = '1' then
                    if v_rob(v_idx1).is_branch = '1' and v_rob(v_idx1).mispredicted = '1' then
                        v_flush := '1'; global_flush <= '1'; flush_target_pc <= v_rob(v_idx1).correct_target;
                        last_allocated_pc1 <= (others => 'U'); last_allocated_pc2 <= (others => 'U');
                        for i in 0 to 15 loop v_rob(i).valid := '0'; end loop;
                        v_head := (others => '0'); v_tail := (others => '0'); v_count := (others => '0');
                        log_flush <= '1'; log_flush_pc <= v_rob(v_idx1).correct_target;
                    else
                        if v_rob(v_idx1).we_gpr = '1' then
                            commit_valid_1_s <= '1'; commit_arch_dest_1_s <= v_rob(v_idx1).arch_dest;
                            commit_pd_1_s <= v_rob(v_idx1).pd_new; commit_data_1_s <= v_rob(v_idx1).gpr_data; 
                        end if;
                        if v_rob(v_idx1).we_flag = '1' then
                            commit_flag_valid_1 <= '1'; commit_pf_1 <= v_rob(v_idx1).pf_new; commit_flag_1 <= v_rob(v_idx1).flag_data; 
                        end if;
                        if v_rob(v_idx1).op_type = "10" then 
                            commit_store_valid <= '1'; commit_store_id <= std_logic_vector(to_unsigned(v_idx1, 4)); v_store_used := true; 
                        end if;
                        v_commits := 1; v_count := v_count - 1;

                        if v_rob(v_idx2).valid = '1' and v_rob(v_idx2).executed = '1' then
                            if v_rob(v_idx2).op_type = "10" and v_store_used then null; 
                            elsif v_rob(v_idx2).is_branch = '1' and v_rob(v_idx2).mispredicted = '1' then
                                v_flush := '1'; global_flush <= '1'; flush_target_pc <= v_rob(v_idx2).correct_target;
                                last_allocated_pc1 <= (others => 'U'); last_allocated_pc2 <= (others => 'U');
                                for i in 0 to 15 loop v_rob(i).valid := '0'; end loop;
                                v_head := (others => '0'); v_tail := (others => '0'); v_count := (others => '0');
                                log_flush <= '1'; log_flush_pc <= v_rob(v_idx2).correct_target;
                            else
                                if v_rob(v_idx2).we_gpr = '1' then
                                    commit_valid_2_s <= '1'; commit_arch_dest_2_s <= v_rob(v_idx2).arch_dest;
                                    commit_pd_2_s <= v_rob(v_idx2).pd_new; commit_data_2_s <= v_rob(v_idx2).gpr_data; 
                                end if;
                                if v_rob(v_idx2).we_flag = '1' then
                                    commit_flag_valid_2 <= '1'; commit_pf_2 <= v_rob(v_idx2).pf_new; commit_flag_2 <= v_rob(v_idx2).flag_data; 
                                end if;
                                if v_rob(v_idx2).op_type = "10" then 
                                    commit_store_valid <= '1'; commit_store_id <= std_logic_vector(to_unsigned(v_idx2, 4));
                                end if;
                                v_commits := 2; v_count := v_count - 1;
                            end if;
                        end if;
                    end if;
                end if;

                if v_flush = '0' then
                    for k in 1 to 2 loop
                        if k <= v_commits then
                            v_rob(to_integer(v_head)).valid := '0'; v_head := v_head + 1;
                        end if;
                    end loop;
                end if;

                -- PHASE 2: WAKEUP
                if alu_complete = '1' then
                    v_rob(to_integer(unsigned(alu_rob_id))).executed  := '1';
                    v_rob(to_integer(unsigned(alu_rob_id))).gpr_data  := alu_data;  
                    v_rob(to_integer(unsigned(alu_rob_id))).flag_data := alu_flags; 
                    
                    if alu_cond_fail = '1' then
                        v_rob(to_integer(unsigned(alu_rob_id))).is_branch := '1';
                        v_rob(to_integer(unsigned(alu_rob_id))).mispredicted := '1';
                        v_rob(to_integer(unsigned(alu_rob_id))).correct_target := std_logic_vector(unsigned(v_rob(to_integer(unsigned(alu_rob_id))).pc) + 2);
                    end if;
                end if;
                if lsu_complete = '1' then
                    v_rob(to_integer(unsigned(lsu_rob_id))).executed  := '1';
                    v_rob(to_integer(unsigned(lsu_rob_id))).gpr_data  := lsu_data;  
                    v_rob(to_integer(unsigned(lsu_rob_id))).flag_data := lsu_flags; 
                end if;
                if sq_complete = '1' then v_rob(to_integer(unsigned(sq_rob_id))).executed := '1'; end if;
                if br_complete = '1' then
                    v_rob(to_integer(unsigned(br_rob_id))).mispredicted   := br_mispredicted;
                    v_rob(to_integer(unsigned(br_rob_id))).correct_target := br_correct_target;
                    v_rob(to_integer(unsigned(br_rob_id))).gpr_data       := br_data; 
                    v_rob(to_integer(unsigned(br_rob_id))).executed       := '1';
                end if;

                -- PHASE 3: DISPATCH
                if v_flush = '0' and is_full = '0' and dispatch_stall = '0' then
                    if disp_valid_1 = '1' then
                        if disp_packet_1.pc /= last_allocated_pc1 then
                            last_allocated_pc1 <= disp_packet_1.pc;
                            v_rob(to_integer(v_tail)).valid := '1'; 
                            v_rob(to_integer(v_tail)).mispredicted := '0';
                            v_rob(to_integer(v_tail)).is_branch := '0';
                            v_rob(to_integer(v_tail)).executed := '0'; 
                            v_rob(to_integer(v_tail)).pc := disp_packet_1.pc; 
                            v_rob(to_integer(v_tail)).pd_new := disp_packet_1.pd_new;
                            v_rob(to_integer(v_tail)).arch_dest := disp_packet_1.arch_dest; 
                            v_rob(to_integer(v_tail)).we_gpr := disp_packet_1.we_gpr;
                            v_rob(to_integer(v_tail)).we_flag := disp_packet_1.we_flag; 
                            v_rob(to_integer(v_tail)).pf_new := disp_packet_1.pf_new;   
                            if disp_packet_1.op = OP_SW or disp_packet_1.op = OP_SM then v_rob(to_integer(v_tail)).op_type := "10";
                            elsif disp_packet_1.op = OP_LW or disp_packet_1.op = OP_LM then v_rob(to_integer(v_tail)).op_type := "01";
                            elsif disp_packet_1.op = OP_BEQ or disp_packet_1.op = OP_JAL or disp_packet_1.op = OP_JLR then 
                                v_rob(to_integer(v_tail)).op_type := "11"; v_rob(to_integer(v_tail)).is_branch := '1';
                            else v_rob(to_integer(v_tail)).op_type := "00";
                            end if;
                            v_tail := v_tail + 1; v_count := v_count + 1;
                        end if;
                    else
                        last_allocated_pc1 <= (others => 'U');
                    end if;
                    
                    if disp_valid_2 = '1' then
                        if disp_packet_2.pc /= last_allocated_pc2 then
                            last_allocated_pc2 <= disp_packet_2.pc;
                            v_rob(to_integer(v_tail)).valid := '1';
                            v_rob(to_integer(v_tail)).mispredicted := '0';
                            v_rob(to_integer(v_tail)).is_branch := '0';
                            v_rob(to_integer(v_tail)).executed := '0'; 
                            v_rob(to_integer(v_tail)).pc := disp_packet_2.pc; 
                            v_rob(to_integer(v_tail)).pd_new := disp_packet_2.pd_new;
                            v_rob(to_integer(v_tail)).arch_dest := disp_packet_2.arch_dest;
                            v_rob(to_integer(v_tail)).we_gpr := disp_packet_2.we_gpr;
                            v_rob(to_integer(v_tail)).we_flag := disp_packet_2.we_flag; 
                            v_rob(to_integer(v_tail)).pf_new := disp_packet_2.pf_new;   
                            if disp_packet_2.op = OP_SW or disp_packet_2.op = OP_SM then v_rob(to_integer(v_tail)).op_type := "10";
                            elsif disp_packet_2.op = OP_LW or disp_packet_2.op = OP_LM then v_rob(to_integer(v_tail)).op_type := "01";
                            elsif disp_packet_2.op = OP_BEQ or disp_packet_2.op = OP_JAL or disp_packet_2.op = OP_JLR then 
                                v_rob(to_integer(v_tail)).op_type := "11"; v_rob(to_integer(v_tail)).is_branch := '1';
                            else v_rob(to_integer(v_tail)).op_type := "00";
                            end if;
                            v_tail := v_tail + 1; v_count := v_count + 1;
                        end if;
                    else
                        last_allocated_pc2 <= (others => 'U');
                    end if;
                end if;
            end if;
            rob_mem <= v_rob; head_ptr <= v_head; tail_ptr <= v_tail; entry_count <= v_count;
        end if;
    end process;

-- =========================================================
    -- PROFESSIONAL X-RAY: ROB TRACKER & COMPLETION SNOOPING
    -- =========================================================
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' then
                
                -- SNOOPING THE COMPLETION BUSES
                if alu_complete = '1' then
                    write(l, string'("[ROB ] ALU Complete Arrived -> ROB ID: ")); write(l, integer'image(to_integer(unsigned(alu_rob_id)))); writeline(output, l);
                end if;
                if lsu_complete = '1' then
                    write(l, string'("[ROB] LSU (Load) Complete Arrived -> ROB ID: ")); write(l, integer'image(to_integer(unsigned(lsu_rob_id)))); writeline(output, l);
                end if;
                if sq_complete = '1' then
                    write(l, string'("[ROB] SQ (Store) Complete Arrived -> ROB ID: ")); write(l, integer'image(to_integer(unsigned(sq_rob_id)))); writeline(output, l);
                end if;
                if br_complete = '1' then
                    write(l, string'("[ROB] BRU Complete Arrived -> ROB ID: ")); write(l, integer'image(to_integer(unsigned(br_rob_id)))); writeline(output, l);
                end if;

                -- REGULAR LOGS
                if log_flush = '1' then
                    write(l, string'("=================================================================")); writeline(output, l);
                    write(l, string'("[ROB] FLUSH TRIGGERED! Branch Mispredict or Condition Failed.")); writeline(output, l);
                    write(l, string'("[ROB] Wiping Pipeline & Redirecting Fetch to PC: ")); 
                    write(l, integer'image(to_integer(unsigned(log_flush_pc)))); writeline(output, l);
                    write(l, string'("=================================================================")); writeline(output, l);
                else
                    if commit_valid_1_s = '1' then
                        write(l, string'("[ROB] COMMIT SLOT 1 -> Arch R")); write(l, integer'image(to_integer(unsigned(commit_arch_dest_1_s))));
                        write(l, string'(" (Phys P")); write(l, integer'image(to_integer(unsigned(commit_pd_1_s))));
                        write(l, string'(") <- Data: ")); write(l, integer'image(to_integer(signed(commit_data_1_s))));
                        writeline(output, l);
                    end if;
                    if commit_valid_2_s = '1' then
                        write(l, string'("[ROB] COMMIT SLOT 2 -> Arch R")); write(l, integer'image(to_integer(unsigned(commit_arch_dest_2_s))));
                        write(l, string'(" (Phys P")); write(l, integer'image(to_integer(unsigned(commit_pd_2_s))));
                        write(l, string'(") <- Data: ")); write(l, integer'image(to_integer(signed(commit_data_2_s))));
                        writeline(output, l);
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
