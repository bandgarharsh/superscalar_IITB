library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use work.iitb_risc_pkg.ALL; 

entity Load_Queue is
    Port (
        clk             : in std_logic; rst : in std_logic; flush : in std_logic; 
        agu_valid       : in std_logic; agu_is_store : in std_logic; agu_addr : in std_logic_vector(15 downto 0); agu_packet : in lsu_issue_packet_t;
        sq_state_in     : in sq_array_t;
        ram_read_en     : out std_logic; ram_read_addr : out std_logic_vector(15 downto 0); ram_data_in : in std_logic_vector(15 downto 0); 
        cdb_gpr_en      : out std_logic; cdb_gpr_tag : out std_logic_vector(4 downto 0); cdb_gpr_data : out std_logic_vector(15 downto 0);
        cdb_flag_en     : out std_logic; cdb_flag_tag : out std_logic_vector(4 downto 0); cdb_flag_data : out std_logic_vector(1 downto 0);
        rob_complete_en : out std_logic; rob_id_out : out std_logic_vector(3 downto 0); rob_gpr_data : out std_logic_vector(15 downto 0); rob_flag_data : out std_logic_vector(1 downto 0);
        
        -- THE APPLE SILICON SPECULATION FIX: Memory Violation Wires
        lq_violation_fault  : out std_logic;
        lq_violation_rob_id : out std_logic_vector(3 downto 0)
    );
end Load_Queue;

architecture Behavioral of Load_Queue is
    type lq_array_t is array (0 to 3) of lq_entry_t;
    signal lq_array : lq_array_t;
    
    -- HISTORY BUFFER FOR MEMORY VIOLATIONS
    type addr_array_t is array(0 to 15) of std_logic_vector(15 downto 0);
    signal hist_addr  : addr_array_t := (others => (others => '0'));
    signal hist_pc    : addr_array_t := (others => (others => '0')); 
    signal hist_valid : std_logic_vector(15 downto 0) := (others => '0');
    
    signal log_fwd_active : std_logic := '0'; signal log_fwd_data   : std_logic_vector(15 downto 0); signal log_fwd_addr   : std_logic_vector(15 downto 0);
    signal log_ram_active : std_logic := '0'; signal log_ram_data   : std_logic_vector(15 downto 0);
    
    signal log_violation  : std_logic := '0'; 
    signal log_viol_id    : std_logic_vector(3 downto 0);
    signal log_viol_pc    : std_logic_vector(15 downto 0); 
    
    -- SNOOP X-RAY SIGNALS
    signal log_snoop_active   : std_logic := '0';
    signal log_snoop_store_id : std_logic_vector(3 downto 0);
    signal log_snoop_store_pc : std_logic_vector(15 downto 0); 
    signal log_snoop_load_id  : std_logic_vector(3 downto 0);
    signal log_snoop_load_pc  : std_logic_vector(15 downto 0); 
    signal log_snoop_addr     : std_logic_vector(15 downto 0);
    signal log_snoop_diff     : unsigned(3 downto 0);

    -- RESULT X-RAY SIGNALS
    signal log_lq_complete  : std_logic := '0';
    signal log_lq_comp_id   : std_logic_vector(3 downto 0);
    signal log_lq_comp_pc   : std_logic_vector(15 downto 0);
    signal log_lq_comp_data : std_logic_vector(15 downto 0);
    
    signal log_lq_comp_flag_tag : std_logic_vector(4 downto 0);
    signal log_lq_comp_flag_z   : std_logic;
begin
    process(clk)
        variable v_lq : lq_array_t;
        variable v_match, v_ram_busy, v_cdb_busy : boolean;
        variable final_z : std_logic;
        variable v_diff : unsigned(3 downto 0);
        variable v_hist_valid : std_logic_vector(15 downto 0);
        variable v_hist_addr : addr_array_t;
        variable v_hist_pc   : addr_array_t;
    begin
        if rising_edge(clk) then
            log_fwd_active <= '0'; log_ram_active <= '0'; log_violation <= '0'; log_snoop_active <= '0';
            log_lq_complete <= '0';
            cdb_gpr_en <= '0'; cdb_flag_en <= '0'; rob_complete_en <= '0'; ram_read_en <= '0';
            lq_violation_fault <= '0';
            
            if rst = '1' or flush = '1' then
                for i in 0 to 3 loop v_lq(i).valid := '0'; end loop;
                lq_array <= v_lq;
                hist_valid <= (others => '0'); 
            else
                v_lq := lq_array; v_hist_valid := hist_valid; v_hist_addr := hist_addr; v_hist_pc := hist_pc;
                v_cdb_busy := false;

                -- PHASE 1: INGEST AND SNOOP FOR VIOLATIONS 
                if agu_valid = '1' then
                    if agu_is_store = '0' then -- IT IS A LOAD!
                        v_hist_valid(to_integer(unsigned(agu_packet.rob_id))) := '1';
                        v_hist_addr(to_integer(unsigned(agu_packet.rob_id)))  := agu_addr;
                        v_hist_pc(to_integer(unsigned(agu_packet.rob_id)))    := agu_packet.pc;

                        for i in 0 to 3 loop
                            if v_lq(i).valid = '0' then
                                v_lq(i).valid := '1'; v_lq(i).state := "00"; v_lq(i).mem_addr := agu_addr; v_lq(i).pd_new := agu_packet.pd_new;
                                v_lq(i).pf_new := agu_packet.pf_new; v_lq(i).we_gpr := agu_packet.we_gpr; v_lq(i).we_flag := agu_packet.we_flag; v_lq(i).rob_id := agu_packet.rob_id;
                                exit;
                            end if;
                        end loop;
                    else -- IT IS A STORE!
                        for j in 0 to 15 loop
                            if v_hist_valid(j) = '1' and v_hist_addr(j) = agu_addr then
                                v_diff := to_unsigned(j, 4) - unsigned(agu_packet.rob_id);
                                
                                log_snoop_active <= '1';
                                log_snoop_store_id <= agu_packet.rob_id; log_snoop_store_pc <= agu_packet.pc;
                                log_snoop_load_id <= std_logic_vector(to_unsigned(j, 4)); log_snoop_load_pc <= v_hist_pc(j);
                                log_snoop_addr <= agu_addr; log_snoop_diff <= v_diff;

                                if v_diff > "0000" and v_diff < "1000" then 
                                    lq_violation_fault <= '1'; lq_violation_rob_id <= std_logic_vector(to_unsigned(j, 4)); 
                                    log_violation <= '1'; log_viol_id <= std_logic_vector(to_unsigned(j, 4)); log_viol_pc <= v_hist_pc(j);
                                end if;
                            end if;
                        end loop;
                    end if;
                end if;

                -- THE FIX: RAM BUS LOCK LOGIC!
                v_ram_busy := false;
                for k in 0 to 3 loop
                    if v_lq(k).valid = '1' and (v_lq(k).state = "01" or v_lq(k).state = "11") then
                        v_ram_busy := true; -- RAM is actively reading, lock out all other loads!
                    end if;
                end loop;

                -- PHASE 2: PROCESS
                for i in 0 to 3 loop
                    if lq_array(i).valid = '1' then
                        if lq_array(i).state = "00" then
                            v_match := false;
                            for j in 3 downto 0 loop
                                if sq_state_in(j).valid = '1' and sq_state_in(j).mem_addr = lq_array(i).mem_addr then
                                    v_match := true;
                                    if sq_state_in(j).data_ready = '1' then
                                        v_lq(i).final_data := sq_state_in(j).store_data; v_lq(i).state := "10";
                                        log_fwd_active <= '1'; log_fwd_addr <= lq_array(i).mem_addr; log_fwd_data <= sq_state_in(j).store_data;
                                    end if;
                                    exit;
                                end if;
                            end loop;

                            if not v_match then
                                if not v_ram_busy then
                                    ram_read_en <= '1'; ram_read_addr <= lq_array(i).mem_addr;
                                    v_lq(i).state := "01"; 
                                    v_ram_busy := true; -- Lock it for other loads in this same cycle
                                end if;
                            end if;
                        
                        elsif lq_array(i).state = "01" then
                            v_lq(i).state := "11";
                            
                        elsif lq_array(i).state = "11" then
                            v_lq(i).final_data := ram_data_in; v_lq(i).state := "10";
                            log_ram_active <= '1'; log_ram_data <= ram_data_in;

                        elsif lq_array(i).state = "10" then
                            if not v_cdb_busy then
                                cdb_gpr_en <= lq_array(i).we_gpr; cdb_gpr_tag <= lq_array(i).pd_new; cdb_gpr_data <= lq_array(i).final_data;
                                if lq_array(i).final_data = x"0000" then final_z := '1'; else final_z := '0'; end if;
                                cdb_flag_en <= lq_array(i).we_flag; cdb_flag_tag <= lq_array(i).pf_new; cdb_flag_data <= '0' & final_z;
                                rob_complete_en <= '1'; rob_id_out <= lq_array(i).rob_id; rob_gpr_data <= lq_array(i).final_data; rob_flag_data <= '0' & final_z;
                                
                                log_lq_complete <= '1'; log_lq_comp_id <= lq_array(i).rob_id;
                                log_lq_comp_pc <= v_hist_pc(to_integer(unsigned(lq_array(i).rob_id))); log_lq_comp_data <= lq_array(i).final_data;
                                
                                log_lq_comp_flag_tag <= lq_array(i).pf_new;
                                log_lq_comp_flag_z   <= final_z;
                                
                                v_lq(i).valid := '0'; v_cdb_busy := true;
                            end if;
                        end if;
                    end if;
                end loop;
                lq_array <= v_lq; hist_valid <= v_hist_valid; hist_addr <= v_hist_addr; hist_pc <= v_hist_pc;
            end if;
        end if;
    end process;
    
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if log_snoop_active = '1' then
                write(l, string'("[LOAD QUEUE X-RAY] Store [ROB: ")); write(l, integer'image(to_integer(unsigned(log_snoop_store_id))));
                write(l, string'(", PC: ")); write(l, integer'image(to_integer(unsigned(log_snoop_store_pc))));
                write(l, string'("] checked History Load [ROB: ")); write(l, integer'image(to_integer(unsigned(log_snoop_load_id))));
                write(l, string'(", PC: ")); write(l, integer'image(to_integer(unsigned(log_snoop_load_pc))));
                write(l, string'("] | Shared Addr: ")); write(l, integer'image(to_integer(unsigned(log_snoop_addr))));
                write(l, string'(" | Age Diff: ")); write(l, integer'image(to_integer(unsigned(log_snoop_diff)))); writeline(output, l);
            end if;
            if log_violation = '1' then
                write(l, string'("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")); writeline(output, l);
                write(l, string'("[LOAD QUEUE] MEMORY ORDERING VIOLATION DETECTED! Load [ROB: ")); write(l, integer'image(to_integer(unsigned(log_viol_id))));
                write(l, string'(", PC: ")); write(l, integer'image(to_integer(unsigned(log_viol_pc))));
                write(l, string'("] read early! Requesting Pipeline Flush!")); writeline(output, l);
                write(l, string'("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")); writeline(output, l);
            end if;
            if log_fwd_active = '1' then
                write(l, string'("[LOAD QUEUE] STORE-TO-LOAD FORWARD SUCCESS! Load [ROB: ")); write(l, integer'image(to_integer(unsigned(log_lq_comp_id))));
                write(l, string'(", PC: ")); write(l, integer'image(to_integer(unsigned(log_lq_comp_pc))));
                write(l, string'("] | Addr: ")); write(l, integer'image(to_integer(unsigned(log_fwd_addr))));
                write(l, string'(" | Data: ")); write(l, integer'image(to_integer(signed(log_fwd_data)))); writeline(output, l);
            end if;
            if log_ram_active = '1' then
                write(l, string'("[LOAD QUEUE] RAM READ COMPLETE! Load [ROB: ")); write(l, integer'image(to_integer(unsigned(log_lq_comp_id))));
                write(l, string'(", PC: ")); write(l, integer'image(to_integer(unsigned(log_lq_comp_pc))));
                write(l, string'("] | Data: ")); write(l, integer'image(to_integer(signed(log_ram_data)))); writeline(output, l);
            end if;
            if log_lq_complete = '1' then
                write(l, string'("------------------------------------------------------------------")); writeline(output, l);
                write(l, string'("[LSU RESULT] PC: ")); write(l, integer'image(to_integer(unsigned(log_lq_comp_pc))));
                write(l, string'(" | ROB ID: ")); write(l, integer'image(to_integer(unsigned(log_lq_comp_id))));
                write(l, string'(" | LOADED DATA: ")); write(l, integer'image(to_integer(signed(log_lq_comp_data)))); 
                -- THE NEW DEEP X-RAY LOG:
                write(l, string'(" | BROADCASTING FLAG ON TAG: ")); write(l, integer'image(to_integer(unsigned(log_lq_comp_flag_tag))));
                write(l, string'(" | Z-FLAG: ")); write(l, std_logic'image(log_lq_comp_flag_z));
                writeline(output, l);
                write(l, string'("------------------------------------------------------------------")); writeline(output, l);
            end if;
        end if;
    end process;
end Behavioral;