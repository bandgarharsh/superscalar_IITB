library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; 
use work.iitb_risc_pkg.ALL; 

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

        issue_valid     : out std_logic;
        issue_is_store  : out std_logic; 
        issue_packet    : out lsu_issue_packet_t 
    );
end RS_LSU;

architecture Behavioral of RS_LSU is
    type rs_array_t is array (0 to 3) of dispatch_packet_t;
    signal rs_queue : rs_array_t;
    signal round_robin_ptr : integer range 0 to 3 := 0;
    
    signal internal_issue_valid : std_logic;
    signal internal_issue_pkt   : lsu_issue_packet_t;
begin

    -- Free Slots Calculation
    process(rs_queue)
        variable empty_count : integer range 0 to 4;
    begin
        empty_count := 0;
        for i in 0 to 3 loop
            if rs_queue(i).valid = '0' then
                empty_count := empty_count + 1;
            end if;
        end loop;
        if empty_count >= 3 then lsu_free_slots <= "11";
        elsif empty_count = 2 then lsu_free_slots <= "10";
        elsif empty_count = 1 then lsu_free_slots <= "01";
        else lsu_free_slots <= "00";
        end if;
    end process;

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
            else
                v_rs := rs_queue;
                v_issued := false;
                internal_issue_valid <= '0';
                
                -- =========================================================
                -- 1. CDB SNOOP PHASE (Update existing instructions)
                -- =========================================================
                for i in 0 to 3 loop
                    if v_rs(i).valid = '1' then
                        if v_rs(i).prs_rdy = '0' then
                            for b in 0 to 2 loop
                                if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_rs(i).prs_tag then
                                    v_rs(i).prs_data := cdb_gpr_data(b); v_rs(i).prs_rdy := '1';
                                end if;
                            end loop;
                        end if;
                        if v_rs(i).prt_rdy = '0' then
                            for b in 0 to 2 loop
                                if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_rs(i).prt_tag then
                                    v_rs(i).prt_data := cdb_gpr_data(b); v_rs(i).prt_rdy := '1';
                                end if;
                            end loop;
                        end if;
                    end if;
                end loop;

                -- =========================================================
                -- 2. PURE OUT-OF-ORDER ISSUE PHASE (ZERO BARRIERS!)
                -- =========================================================
                for offset in 0 to 3 loop
                    v_idx := (round_robin_ptr + offset) mod 4;
                    if not v_issued and v_rs(v_idx).valid = '1' then
                        
                        -- The Base Address MUST be ready for both Load and Store
                        if v_rs(v_idx).prs_rdy = '1' then
                            
                            if v_rs(v_idx).op = OP_SW or v_rs(v_idx).op = OP_SM then v_is_store := '1'; else v_is_store := '0'; end if;
                            
                            -- Load goes instantly. Store waits for data. NO AGE CHECKS!
                            if v_is_store = '0' or (v_is_store = '1' and v_rs(v_idx).prt_rdy = '1') then
                                internal_issue_valid    <= '1';
                                issue_is_store <= v_is_store;
                                
                                internal_issue_pkt.valid      <= '1';
                                internal_issue_pkt.pc         <= v_rs(v_idx).pc;
                                internal_issue_pkt.op         <= v_rs(v_idx).op;
                                internal_issue_pkt.imm        <= v_rs(v_idx).imm;
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

                -- =========================================================
                -- 3. DISPATCH INGEST PHASE (WITH INSTANT CDB BYPASS!)
                -- =========================================================
                v_disp1 := disp_port1;
                v_disp2 := disp_port2;
                
                if v_disp1.valid = '1' then
                    if v_disp1.prs_rdy = '0' then
                        for b in 0 to 2 loop
                            if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_disp1.prs_tag then v_disp1.prs_data := cdb_gpr_data(b); v_disp1.prs_rdy := '1'; end if;
                        end loop;
                    end if;
                    if v_disp1.prt_rdy = '0' then
                        for b in 0 to 2 loop
                            if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_disp1.prt_tag then v_disp1.prt_data := cdb_gpr_data(b); v_disp1.prt_rdy := '1'; end if;
                        end loop;
                    end if;
                    for i in 0 to 3 loop
                        if v_rs(i).valid = '0' then v_rs(i) := v_disp1; exit; end if;
                    end loop;
                end if;
                
                if v_disp2.valid = '1' then
                    if v_disp2.prs_rdy = '0' then
                        for b in 0 to 2 loop
                            if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_disp2.prs_tag then v_disp2.prs_data := cdb_gpr_data(b); v_disp2.prs_rdy := '1'; end if;
                        end loop;
                    end if;
                    if v_disp2.prt_rdy = '0' then
                        for b in 0 to 2 loop
                            if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_disp2.prt_tag then v_disp2.prt_data := cdb_gpr_data(b); v_disp2.prt_rdy := '1'; end if;
                        end loop;
                    end if;
                    for i in 0 to 3 loop
                        if v_rs(i).valid = '0' then v_rs(i) := v_disp2; exit; end if;
                    end loop;
                end if;
            end if;
            rs_queue <= v_rs;
        end if;
    end process;
    
    issue_valid <= internal_issue_valid;
    issue_packet <= internal_issue_pkt;

    -- =================================================================
    -- PROFESSIONAL X-RAY LOGGING
    -- =================================================================
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' and flush = '0' then
                if internal_issue_valid = '1' then
                    write(l, string'("[RS LSU] ISSUED -> PC: ")); write(l, integer'image(to_integer(unsigned(internal_issue_pkt.pc))));
                    write(l, string'(" | ROB ID: ")); write(l, integer'image(to_integer(unsigned(internal_issue_pkt.rob_id))));
                    if internal_issue_pkt.op = OP_SW or internal_issue_pkt.op = OP_SM then write(l, string'(" [STORE]")); else write(l, string'(" [LOAD]")); end if;
                    write(l, string'(" | Base Data: ")); write(l, integer'image(to_integer(signed(internal_issue_pkt.base_data))));
                    write(l, string'(" | Offset: ")); write(l, integer'image(to_integer(signed(internal_issue_pkt.imm))));
                    if internal_issue_pkt.op = OP_SW or internal_issue_pkt.op = OP_SM then
                        write(l, string'(" | Store Data: ")); write(l, integer'image(to_integer(signed(internal_issue_pkt.prt_data))));
                    end if;
                    writeline(output, l);
                end if;
                
                for i in 0 to 3 loop
                    if rs_queue(i).valid = '1' then
                        if rs_queue(i).prs_rdy = '0' or ((rs_queue(i).op = OP_SW or rs_queue(i).op = OP_SM) and rs_queue(i).prt_rdy = '0') then
                            write(l, string'("[RS LSU DUMP] STUCK PC: ")); write(l, integer'image(to_integer(unsigned(rs_queue(i).pc))));
                            write(l, string'(" | Base_RDY: ")); write(l, std_logic'image(rs_queue(i).prs_rdy));
                            if rs_queue(i).op = OP_SW or rs_queue(i).op = OP_SM then
                                write(l, string'(" | StoreData_RDY: ")); write(l, std_logic'image(rs_queue(i).prt_rdy));
                            end if;
                            writeline(output, l);
                        end if;
                    end if;
                end loop;
            end if;
        end if;
    end process;
end Behavioral;