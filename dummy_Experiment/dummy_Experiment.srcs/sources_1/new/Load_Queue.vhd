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
        rob_complete_en : out std_logic; rob_id_out : out std_logic_vector(3 downto 0); rob_gpr_data : out std_logic_vector(15 downto 0); rob_flag_data : out std_logic_vector(1 downto 0)
    );
end Load_Queue;

architecture Behavioral of Load_Queue is
    type lq_array_t is array (0 to 3) of lq_entry_t;
    signal lq_array : lq_array_t;
begin
    process(clk)
        variable v_lq : lq_array_t;
        variable v_match : boolean;
        variable v_ram_busy : boolean;
        variable v_cdb_busy : boolean;
        variable final_z : std_logic;
        variable min_diff : unsigned(3 downto 0);
        variable curr_diff : unsigned(3 downto 0);
        variable best_sq_idx : integer;
        variable l : line;
    begin
        if rising_edge(clk) then
            cdb_gpr_en <= '0'; cdb_flag_en <= '0'; rob_complete_en <= '0'; ram_read_en <= '0';
            
            if rst = '1' or flush = '1' then
                for i in 0 to 3 loop v_lq(i).valid := '0'; end loop;
                lq_array <= v_lq;
            else
                v_lq := lq_array;
                v_ram_busy := false; v_cdb_busy := false;

                -- PHASE 1: INGEST FROM AGU
                if agu_valid = '1' and agu_is_store = '0' then
                    for i in 0 to 3 loop
                        if v_lq(i).valid = '0' then
                            v_lq(i).valid    := '1'; v_lq(i).state    := "00"; 
                            v_lq(i).mem_addr := agu_addr; v_lq(i).pd_new   := agu_packet.pd_new;
                            v_lq(i).pf_new   := agu_packet.pf_new; v_lq(i).we_gpr   := agu_packet.we_gpr;
                            v_lq(i).we_flag  := agu_packet.we_flag; v_lq(i).rob_id   := agu_packet.rob_id;
                            
                            write(l, string'("[LOAD QUEUE] ADDED LOAD -> ROB ID: ")); write(l, integer'image(to_integer(unsigned(agu_packet.rob_id))));
                            write(l, string'(" | Addr: ")); write(l, integer'image(to_integer(unsigned(agu_addr)))); writeline(output, l);
                            exit;
                        end if;
                    end loop;
                end if;

                -- PHASE 2: PROCESS
                for i in 0 to 3 loop
                    if v_lq(i).valid = '1' then
                        if v_lq(i).state = "00" then
                            v_match := false; min_diff := "1111"; best_sq_idx := -1;
                            
                            -- Check Store Queue via sq_state_bus
                            for j in 0 to 3 loop
                                if sq_state_in(j).valid = '1' and sq_state_in(j).mem_addr = v_lq(i).mem_addr then
                                    curr_diff := unsigned(v_lq(i).rob_id) - unsigned(sq_state_in(j).rob_id);
                                    if curr_diff > 0 and curr_diff < 8 then -- Store is older
                                        if curr_diff < min_diff then
                                            min_diff := curr_diff; best_sq_idx := j; v_match := true;
                                        end if;
                                    end if;
                                end if;
                            end loop;

                            if v_match then
                                if sq_state_in(best_sq_idx).data_ready = '1' then
                                    v_lq(i).final_data := sq_state_in(best_sq_idx).store_data;
                                    v_lq(i).state := "10";
                                    
                                    write(l, string'("[LOAD QUEUE] STORE-TO-LOAD FORWARD! Load ROB ID: ")); write(l, integer'image(to_integer(unsigned(v_lq(i).rob_id))));
                                    write(l, string'(" got Data: ")); write(l, integer'image(to_integer(signed(v_lq(i).final_data))));
                                    write(l, string'(" from Store ROB ID: ")); write(l, integer'image(to_integer(unsigned(sq_state_in(best_sq_idx).rob_id))));
                                    writeline(output, l);
                                end if;
                            else
                                if not v_ram_busy then
                                    ram_read_en <= '1'; ram_read_addr <= v_lq(i).mem_addr;
                                    v_lq(i).state := "01"; v_ram_busy := true;
                                    
                                    write(l, string'("[LOAD QUEUE] REQUESTING RAM READ -> Addr: ")); write(l, integer'image(to_integer(unsigned(v_lq(i).mem_addr)))); writeline(output, l);
                                end if;
                            end if;
                        
                        elsif v_lq(i).state = "01" then
                            v_lq(i).final_data := ram_data_in; v_lq(i).state := "10";
                            
                            write(l, string'("[LOAD QUEUE] RAM READ COMPLETE -> Data: ")); write(l, integer'image(to_integer(signed(ram_data_in)))); writeline(output, l);

                        elsif v_lq(i).state = "10" then
                            if not v_cdb_busy then
                                cdb_gpr_en <= v_lq(i).we_gpr; cdb_gpr_tag <= v_lq(i).pd_new; cdb_gpr_data <= v_lq(i).final_data;
                                if v_lq(i).final_data = x"0000" then final_z := '1'; else final_z := '0'; end if;
                                cdb_flag_en <= v_lq(i).we_flag; cdb_flag_tag <= v_lq(i).pf_new; cdb_flag_data <= '0' & final_z;
                                
                                rob_complete_en <= '1'; rob_id_out <= v_lq(i).rob_id; 
                                rob_gpr_data <= v_lq(i).final_data; rob_flag_data <= '0' & final_z;
                                
                                write(l, string'("[LOAD QUEUE] BROADCASTING TO CDB -> Load ROB ID: ")); write(l, integer'image(to_integer(unsigned(v_lq(i).rob_id))));
                                write(l, string'(" | Data: ")); write(l, integer'image(to_integer(signed(v_lq(i).final_data)))); writeline(output, l);
                                
                                v_lq(i).valid := '0'; v_cdb_busy := true;
                            end if;
                        end if;
                    end if;
                end loop;
                
                lq_array <= v_lq;
            end if;
        end if;
    end process;
end Behavioral;