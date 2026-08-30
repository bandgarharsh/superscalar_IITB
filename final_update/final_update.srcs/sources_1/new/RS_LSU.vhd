library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; 
use work.iitb_risc_pkg.ALL; 

----------------------------------------------------------------------------------
-- MODULE: Reservation Station - Load/Store Unit (LSU)
-- DESCRIPTION:
--   Queue specifically tasked with evaluating memory instructions. 
--   Intelligently determines issue readiness based on instruction type:
--   Loads (LW/LM): Issue instantly once the Base Address (PRS) is ready.
--   Stores (SW/SM): Must wait for both the Base (PRS) AND Data (PRT) to be ready.
----------------------------------------------------------------------------------
entity RS_LSU is
    Port (
        clk             : in std_logic;
        rst             : in std_logic;
        flush           : in std_logic; 

        disp_port1      : in dispatch_packet_t;
        disp_port2      : in dispatch_packet_t;
        lsu_free_slots  : out unsigned(1 downto 0); 

        cdb_gpr_en      : in std_logic_vector(2 downto 0);
        cdb_gpr_tag     : in array_of_5bit(0 to 2);
        cdb_gpr_data    : in array_of_16bit(0 to 2);

        cdb_flag_en     : in std_logic_vector(1 downto 0);
        cdb_flag_tag    : in array_of_5bit(0 to 1);
        cdb_flag_data   : in array_of_2bit(0 to 1);

        issue_valid     : out std_logic;
        issue_is_store  : out std_logic; 
        issue_packet    : out lsu_issue_packet_t 
    );
end RS_LSU;

architecture Behavioral of RS_LSU is
    type rs_array_t is array (0 to 3) of dispatch_packet_t;
    signal rs_queue : rs_array_t;
    
    -- Asynchronous Snoop Network
    signal snoop_queue : rs_array_t;

    signal round_robin_ptr : integer range 0 to 3 := 0;
    signal internal_issue_valid : std_logic;
    signal internal_issue_pkt   : lsu_issue_packet_t;
    
    -- Prevents processing duplicate requests on stalls
    signal last_ingest_rob1 : std_logic_vector(3 downto 0) := (others => '1');
    signal last_ingest_rob2 : std_logic_vector(3 downto 0) := (others => '1');

begin

    -- Continuously monitor free slots for the Dispatch stage
    process(rs_queue)
        variable empty_count : integer range 0 to 4;
    begin
        empty_count := 0;
        for i in 0 to 3 loop
            if rs_queue(i).valid = '0' then empty_count := empty_count + 1; end if;
        end loop;
        if empty_count >= 3 then lsu_free_slots <= "11";
        elsif empty_count = 2 then lsu_free_slots <= "10";
        elsif empty_count = 1 then lsu_free_slots <= "01";
        else lsu_free_slots <= "00";
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- ASYNCHRONOUS CDB SNOOPING
    -- Pre-evaluates dependencies combinationally before the clock edge hits.
    ------------------------------------------------------------------------------
    process(rs_queue, cdb_gpr_en, cdb_gpr_tag, cdb_gpr_data, cdb_flag_en, cdb_flag_tag, cdb_flag_data)
        variable v_snoop : rs_array_t;
    begin
        v_snoop := rs_queue;
        for i in 0 to 3 loop
            if v_snoop(i).valid = '1' then
                if v_snoop(i).prs_rdy = '0' then
                    for b in 0 to 2 loop
                        if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_snoop(i).prs_tag then
                            v_snoop(i).prs_data := cdb_gpr_data(b); v_snoop(i).prs_rdy := '1';
                        end if;
                    end loop;
                end if;
                if v_snoop(i).prt_rdy = '0' then
                    if v_snoop(i).cz_bits = "11" then
                        for b in 0 to 1 loop
                            if cdb_flag_en(b) = '1' and cdb_flag_tag(b) = v_snoop(i).prt_tag then
                                v_snoop(i).prt_data := (15 downto 1 => '0') & cdb_flag_data(b)(0); 
                                v_snoop(i).prt_rdy := '1';
                            end if;
                        end loop;
                    else
                        for b in 0 to 2 loop
                            if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_snoop(i).prt_tag then
                                v_snoop(i).prt_data := cdb_gpr_data(b); v_snoop(i).prt_rdy := '1';
                            end if;
                        end loop;
                    end if;
                end if;
            end if;
        end loop;
        snoop_queue <= v_snoop;
    end process;

    ------------------------------------------------------------------------------
    -- INGEST & ISSUE PHASE
    ------------------------------------------------------------------------------
    process(clk)
        variable v_rs         : rs_array_t;
        variable v_issued     : boolean;
        variable v_is_store   : std_logic;
        variable v_idx        : integer range 0 to 3;
        variable v_disp1      : dispatch_packet_t;
        variable v_disp2      : dispatch_packet_t;
    begin
        if rising_edge(clk) then
            if rst = '1' or flush = '1' then
                for i in 0 to 3 loop v_rs(i).valid := '0'; end loop;
                internal_issue_valid <= '0';
                round_robin_ptr <= 0;
                last_ingest_rob1 <= (others => '1');
                last_ingest_rob2 <= (others => '1');
            else
                v_rs := snoop_queue;
                v_issued := false;
                internal_issue_valid <= '0';

                -- PHASE 1: ISSUE (Determines readiness based on instruction type)
                for offset in 0 to 3 loop
                    v_idx := (round_robin_ptr + offset) mod 4;
                    if not v_issued and v_rs(v_idx).valid = '1' then
                        if v_rs(v_idx).prs_rdy = '1' then
                            if v_rs(v_idx).op = OP_SW or v_rs(v_idx).op = OP_SM then v_is_store := '1'; else v_is_store := '0'; end if;
                            
                            -- Load -> Fires immediately on Base Ready
                            -- Store -> Waits for Base Ready AND Data Ready
                            if v_is_store = '0' or (v_is_store = '1' and v_rs(v_idx).prt_rdy = '1') then
                                internal_issue_valid    <= '1';
                                issue_is_store <= v_is_store;
                                
                                internal_issue_pkt.valid      <= '1';
                                internal_issue_pkt.pc         <= v_rs(v_idx).pc;
                                internal_issue_pkt.op         <= v_rs(v_idx).op;
                                internal_issue_pkt.imm        <= v_rs(v_idx).imm;
                                internal_issue_pkt.cz_bits    <= v_rs(v_idx).cz_bits;
                                internal_issue_pkt.base_data  <= v_rs(v_idx).prs_data;
                                internal_issue_pkt.prt_tag    <= v_rs(v_idx).prt_tag;
                                internal_issue_pkt.prt_rdy    <= v_rs(v_idx).prt_rdy;
                                internal_issue_pkt.prt_data   <= v_rs(v_idx).prt_data;
                                internal_issue_pkt.pd_new     <= v_rs(v_idx).pd_new;
                                internal_issue_pkt.pf_new     <= v_rs(v_idx).pf_new;
                                internal_issue_pkt.rob_id     <= v_rs(v_idx).rob_id;
                                internal_issue_pkt.we_gpr     <= v_rs(v_idx).we_gpr;
                                internal_issue_pkt.we_flag    <= v_rs(v_idx).we_flag; 

                                v_rs(v_idx).valid := '0'; 
                                v_issued := true;
                                round_robin_ptr <= (v_idx + 1) mod 4;
                            end if;
                        end if;
                    end if;
                end loop;

                -- PHASE 2: DISPATCH INGEST
                v_disp1 := disp_port1;
                v_disp2 := disp_port2;
                
                if v_disp1.valid = '1' and v_disp1.rob_id /= last_ingest_rob1 then
                    if v_disp1.prs_rdy = '0' then
                        for b in 0 to 2 loop
                            if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_disp1.prs_tag then v_disp1.prs_data := cdb_gpr_data(b); v_disp1.prs_rdy := '1'; end if;
                        end loop;
                    end if;
                    if v_disp1.prt_rdy = '0' then
                        if v_disp1.cz_bits = "11" then
                            for b in 0 to 1 loop
                                if cdb_flag_en(b) = '1' and cdb_flag_tag(b) = v_disp1.prt_tag then
                                    v_disp1.prt_data := (15 downto 1 => '0') & cdb_flag_data(b)(0); v_disp1.prt_rdy := '1'; 
                                end if;
                            end loop;
                        else
                            for b in 0 to 2 loop
                                if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_disp1.prt_tag then v_disp1.prt_data := cdb_gpr_data(b); v_disp1.prt_rdy := '1'; end if;
                            end loop;
                        end if;
                    end if;
                    for i in 0 to 3 loop
                        if v_rs(i).valid = '0' then 
                            v_rs(i) := v_disp1; last_ingest_rob1 <= v_disp1.rob_id; exit; 
                        end if;
                    end loop;
                end if;
                
                if v_disp2.valid = '1' and v_disp2.rob_id /= last_ingest_rob2 then
                    if v_disp2.prs_rdy = '0' then
                        for b in 0 to 2 loop
                            if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_disp2.prs_tag then v_disp2.prs_data := cdb_gpr_data(b); v_disp2.prs_rdy := '1'; end if;
                        end loop;
                    end if;
                    if v_disp2.prt_rdy = '0' then
                        if v_disp2.cz_bits = "11" then
                            for b in 0 to 1 loop
                                if cdb_flag_en(b) = '1' and cdb_flag_tag(b) = v_disp2.prt_tag then
                                    v_disp2.prt_data := (15 downto 1 => '0') & cdb_flag_data(b)(0); v_disp2.prt_rdy := '1'; 
                                end if;
                            end loop;
                        else
                            for b in 0 to 2 loop
                                if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_disp2.prt_tag then v_disp2.prt_data := cdb_gpr_data(b); v_disp2.prt_rdy := '1'; end if;
                            end loop;
                        end if;
                    end if;
                    for i in 0 to 3 loop
                        if v_rs(i).valid = '0' then 
                            v_rs(i) := v_disp2; last_ingest_rob2 <= v_disp2.rob_id; exit; 
                        end if;
                    end loop;
                end if;
            end if;
            rs_queue <= v_rs;
        end if;
    end process;
    
    issue_valid <= internal_issue_valid;
    issue_packet <= internal_issue_pkt;

    ------------------------------------------------------------------------------
    -- DIAGNOSTICS & LOGGING
    ------------------------------------------------------------------------------
    process(clk)
        variable l : line;
        variable empty_queue : boolean;
    begin
        if rising_edge(clk) then
            if rst = '0' and flush = '0' then
                
                -- Log Issue Events
                if internal_issue_valid = '1' then
                    write(l, string'("-----------------------------------------------------------------")); writeline(output, l);
                    write(l, string'("[RS LSU X-RAY] *** ISSUE FIRE *** -> PC: ")); write(l, integer'image(to_integer(unsigned(internal_issue_pkt.pc))));
                    write(l, string'(" | ROB ID: ")); write(l, integer'image(to_integer(unsigned(internal_issue_pkt.rob_id))));
                    if internal_issue_pkt.op = OP_SW or internal_issue_pkt.op = OP_SM then write(l, string'(" [STORE]")); else write(l, string'(" [LOAD]")); end if;
                    write(l, string'(" | Base Data: ")); write(l, integer'image(to_integer(signed(internal_issue_pkt.base_data))));
                    write(l, string'(" | Offset: ")); write(l, integer'image(to_integer(signed(internal_issue_pkt.imm))));
                    if internal_issue_pkt.op = OP_SW or internal_issue_pkt.op = OP_SM then
                        write(l, string'(" | Store Data: ")); write(l, integer'image(to_integer(signed(internal_issue_pkt.prt_data))));
                    end if;
                    writeline(output, l);
                    write(l, string'("-----------------------------------------------------------------")); writeline(output, l);
                end if;
                
                -- Log Ingest Events (Ghost Check prevention tracking)
                if disp_port1.valid = '1' and disp_port1.rob_id /= last_ingest_rob1 then
                    write(l, string'("[RS LSU INGEST] Successfully queued -> PC: ")); write(l, integer'image(to_integer(unsigned(disp_port1.pc))));
                    write(l, string'(" | ROB ID: ")); write(l, integer'image(to_integer(unsigned(disp_port1.rob_id))));
                    writeline(output, l);
                end if;
                if disp_port2.valid = '1' and disp_port2.rob_id /= last_ingest_rob2 then
                    write(l, string'("[RS LSU INGEST] Successfully queued -> PC: ")); write(l, integer'image(to_integer(unsigned(disp_port2.pc))));
                    write(l, string'(" | ROB ID: ")); write(l, integer'image(to_integer(unsigned(disp_port2.rob_id))));
                    writeline(output, l);
                end if;

                -- Dump Active Statuses
                empty_queue := true;
                for i in 0 to 3 loop
                    if rs_queue(i).valid = '1' then
                        empty_queue := false;
                        write(l, string'("[RS LSU DUMP] Slot ")); write(l, integer'image(i));
                        write(l, string'(" -> PC: ")); write(l, integer'image(to_integer(unsigned(rs_queue(i).pc))));
                        write(l, string'(" | ROB ID: ")); write(l, integer'image(to_integer(unsigned(rs_queue(i).rob_id))));
                        write(l, string'(" | Base_RDY: ")); write(l, std_logic'image(rs_queue(i).prs_rdy));
                        if rs_queue(i).prs_rdy = '0' then
                            write(l, string'(" (WAITING ON TAG: ")); write(l, integer'image(to_integer(unsigned(rs_queue(i).prs_tag)))); write(l, string'(")"));
                        end if;
                        
                        if rs_queue(i).op = OP_SW or rs_queue(i).op = OP_SM then
                            write(l, string'(" | StoreData_RDY: ")); write(l, std_logic'image(rs_queue(i).prt_rdy));
                            if rs_queue(i).prt_rdy = '0' then
                                write(l, string'(" (WAITING ON TAG: ")); write(l, integer'image(to_integer(unsigned(rs_queue(i).prt_tag)))); write(l, string'(")"));
                            end if;
                        end if;
                        writeline(output, l);
                    end if;
                end loop;
            end if;
        end if;
    end process;
end Behavioral;