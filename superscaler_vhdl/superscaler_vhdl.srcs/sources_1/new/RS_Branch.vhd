library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL; 

entity RS_Branch is
    Port (
        clk             : in std_logic;
        rst             : in std_logic;
        flush           : in std_logic; 

        -- =========================================================
        -- DISPATCH INTERFACE
        -- =========================================================
        disp_port1      : in dispatch_packet_t;
        disp_port2      : in dispatch_packet_t;
        branch_free_slots: out unsigned(1 downto 0); 

        -- =========================================================
        -- WAKEUP INTERFACE
        -- =========================================================
        cdb_gpr_en      : in std_logic_vector(2 downto 0);
        cdb_gpr_tag     : in array_of_5bit(0 to 2);
        cdb_gpr_data    : in array_of_16bit(0 to 2);
        
        cdb_flag_en     : in std_logic;
        cdb_flag_tag    : in std_logic_vector(4 downto 0);
        cdb_flag_data   : in std_logic_vector(1 downto 0);

        -- =========================================================
        -- ISSUE INTERFACE
        -- =========================================================
        issue_valid     : out std_logic;
        issue_packet    : out branch_issue_packet_t 
    );
end RS_Branch;

architecture Behavioral of RS_Branch is
    type rs_array_t is array (0 to 3) of dispatch_packet_t;
    signal rs_queue : rs_array_t;
    signal round_robin_ptr : integer range 0 to 3 := 0; -- NEW! FAIR SCHEDULING POINTER
begin

    -- SATURATING COMBINATIONAL BACKPRESSURE
    process(rs_queue)
        variable empty_count : integer range 0 to 4;
    begin
        empty_count := 0;
        for i in 0 to 3 loop
            if rs_queue(i).valid = '0' then
                empty_count := empty_count + 1;
            end if;
        end loop;
        
        if empty_count >= 3 then branch_free_slots <= "11";
        elsif empty_count = 2 then branch_free_slots <= "10";
        elsif empty_count = 1 then branch_free_slots <= "01";
        else branch_free_slots <= "00";
        end if;
    end process;

    -- MAIN CLOCKED STATE MACHINE
    process(clk)
        variable v_rs       : rs_array_t;
        variable v_issued   : boolean;
        variable v_idx      : integer range 0 to 3;
    begin
        if rising_edge(clk) then
            if rst = '1' or flush = '1' then
                for i in 0 to 3 loop v_rs(i).valid := '0'; end loop;
                issue_valid <= '0';
                round_robin_ptr <= 0;
            else
                v_rs := rs_queue;
                
                -- -------------------------------------------------------------
                -- PHASE 1: ISSUE (FAIR ROUND-ROBIN SCHEDULING)
                -- -------------------------------------------------------------
                v_issued := false;
                issue_valid <= '0';
                
                for offset in 0 to 3 loop
                    v_idx := (round_robin_ptr + offset) mod 4;
                    
                    if not v_issued and v_rs(v_idx).valid = '1' then
                        if v_rs(v_idx).prs_rdy = '1' and v_rs(v_idx).prt_rdy = '1' and v_rs(v_idx).pr_flag_rdy = '1' then
                            
                            issue_valid <= '1';
                            issue_packet.valid      <= '1';
                            issue_packet.pc         <= v_rs(v_idx).pc;       
                            issue_packet.op         <= v_rs(v_idx).op;
                            issue_packet.imm        <= v_rs(v_idx).imm;
                            issue_packet.comp_bit   <= v_rs(v_idx).comp_bit;
                            issue_packet.cz_bits    <= v_rs(v_idx).cz_bits;
                            
                            issue_packet.rs1_data   <= v_rs(v_idx).prs_data;
                            issue_packet.rs2_data   <= v_rs(v_idx).prt_data;
                            issue_packet.flag_data  <= v_rs(v_idx).pr_flag_data;
                            
                            issue_packet.pd_new     <= v_rs(v_idx).pd_new;
                            issue_packet.pf_new     <= v_rs(v_idx).pf_new;
                            issue_packet.rob_id     <= v_rs(v_idx).rob_id;
                            issue_packet.we_gpr     <= v_rs(v_idx).we_gpr;
                            issue_packet.we_flag    <= v_rs(v_idx).we_flag;
                            issue_packet.pred_taken <= v_rs(v_idx).pred_taken;
                            issue_packet.pred_target <= v_rs(v_idx).pred_target;

                            v_rs(v_idx).valid := '0'; 
                            v_issued := true;
                            
                            round_robin_ptr <= (v_idx + 1) mod 4;
                        end if;
                    end if;
                end loop;

                -- -------------------------------------------------------------
                -- PHASE 2: ALLOCATE 
                -- -------------------------------------------------------------
                if disp_port1.valid = '1' then
                    for i in 0 to 3 loop
                        if v_rs(i).valid = '0' then v_rs(i) := disp_port1; exit; end if;
                    end loop;
                end if;
                
                if disp_port2.valid = '1' then
                    for i in 0 to 3 loop
                        if v_rs(i).valid = '0' then v_rs(i) := disp_port2; exit; end if;
                    end loop;
                end if;

                -- -------------------------------------------------------------
                -- PHASE 3: WAKEUP
                -- -------------------------------------------------------------
                for i in 0 to 3 loop
                    if v_rs(i).valid = '1' then
                        if v_rs(i).prs_rdy = '0' then
                            for b in 0 to 2 loop
                                if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_rs(i).prs_tag then
                                    v_rs(i).prs_data := cdb_gpr_data(b); v_rs(i).prs_rdy  := '1'; 
                                end if;
                            end loop;
                        end if;
                        
                        if v_rs(i).prt_rdy = '0' then
                            for b in 0 to 2 loop
                                if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_rs(i).prt_tag then
                                    v_rs(i).prt_data := cdb_gpr_data(b); v_rs(i).prt_rdy  := '1'; 
                                end if;
                            end loop;
                        end if;

                        if v_rs(i).pr_flag_rdy = '0' then
                            if cdb_flag_en = '1' and cdb_flag_tag = v_rs(i).pr_flag_tag then
                                v_rs(i).pr_flag_data := cdb_flag_data; v_rs(i).pr_flag_rdy  := '1'; 
                            end if;
                        end if;
                    end if;
                end loop;
            end if;
            rs_queue <= v_rs;
        end if;
    end process;
end Behavioral;