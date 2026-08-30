library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; 
use work.iitb_risc_pkg.ALL; 

entity RS_ALU is
    Port (
        clk             : in std_logic;
        rst             : in std_logic;
        flush           : in std_logic; 

        disp_port1      : in dispatch_packet_t;
        disp_port2      : in dispatch_packet_t;
        free_slots      : out unsigned(1 downto 0); 

        cdb_gpr_en      : in std_logic_vector(2 downto 0);
        cdb_gpr_tag     : in array_of_5bit(0 to 2); 
        cdb_gpr_data    : in array_of_16bit(0 to 2);
        
        cdb_flag_en     : in std_logic_vector(1 downto 0);
        cdb_flag_tag    : in array_of_5bit(0 to 1);
        cdb_flag_data   : in array_of_2bit(0 to 1);

        issue_valid     : out std_logic;
        issue_packet    : out issue_packet_t
    );
end RS_ALU;

architecture Behavioral of RS_ALU is
    type rs_array_t is array (0 to 3) of dispatch_packet_t;
    signal rs_queue : rs_array_t;
    signal round_robin_ptr : integer range 0 to 3 := 0;
    
    signal internal_issue_valid : std_logic;
    signal internal_issue_pkt   : issue_packet_t;
begin

    process(rs_queue) 
        variable count : integer range 0 to 4;
    begin
        count := 0;
        for i in 0 to 3 loop
            if rs_queue(i).valid = '0' then 
                count := count + 1;
            end if;
        end loop;
        if count >= 3 then free_slots <= "11";
        elsif count = 2 then free_slots <= "10";
        elsif count = 1 then free_slots <= "01";
        else free_slots <= "00";
        end if;
    end process;
    
    process(clk)
        variable v_rs         : rs_array_t;
        variable v_issued     : boolean;
        variable v_idx        : integer range 0 to 3;
    begin
        if rising_edge(clk) then
            if rst = '1' or flush = '1' then
                for i in 0 to 3 loop v_rs(i).valid := '0'; end loop;
                internal_issue_valid <= '0';
                round_robin_ptr <= 0;
            else
                v_rs := rs_queue;
                
                -- PHASE 1: ISSUE 
                v_issued := false;
                internal_issue_valid <= '0';
                
                for offset in 0 to 3 loop
                    v_idx := (round_robin_ptr + offset) mod 4; 
                    
                    if not v_issued and v_rs(v_idx).valid = '1' then 
                        if v_rs(v_idx).prs_rdy = '1' and v_rs(v_idx).prt_rdy = '1' and v_rs(v_idx).pr_flag_rdy = '1' then 
                            
                            internal_issue_valid           <= '1';
                            internal_issue_pkt.valid      <= '1';
                            internal_issue_pkt.pc         <= v_rs(v_idx).pc;
                            internal_issue_pkt.op         <= v_rs(v_idx).op;
                            internal_issue_pkt.imm        <= v_rs(v_idx).imm;
                            internal_issue_pkt.comp_bit   <= v_rs(v_idx).comp_bit;
                            internal_issue_pkt.cz_bits    <= v_rs(v_idx).cz_bits;
                            internal_issue_pkt.rs1_data   <= v_rs(v_idx).prs_data;
                            internal_issue_pkt.rs2_data   <= v_rs(v_idx).prt_data;
                            internal_issue_pkt.flag_data  <= v_rs(v_idx).pr_flag_data;
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
                end loop;

                -- PHASE 2: ALLOCATE 
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

                -- PHASE 3: WAKEUP 
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
                            for b in 0 to 1 loop
                                if cdb_flag_en(b) = '1' and cdb_flag_tag(b) = v_rs(i).pr_flag_tag then
                                    v_rs(i).pr_flag_data := cdb_flag_data(b); v_rs(i).pr_flag_rdy  := '1';
                                end if;
                            end loop;
                        end if;
                    end if;
                end loop;
            end if;
            rs_queue <= v_rs;
        end if;
    end process;

    issue_valid <= internal_issue_valid;
    issue_packet <= internal_issue_pkt;

    -- =================================================================
    -- PROFESSIONAL X-RAY: ALU DIAGNOSTICS
    -- =================================================================
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '0' and flush = '0' then
                if internal_issue_valid = '1' then
                    write(l, string'("[RS ALU] ISSUED -> PC: "));
                    write(l, integer'image(to_integer(unsigned(internal_issue_pkt.pc))));
                    write(l, string'(" | ROB ID: "));
                    write(l, integer'image(to_integer(unsigned(internal_issue_pkt.rob_id))));
                    writeline(output, l);
                else
                    -- IF NOTHING ISSUED, TELL US EXACTLY WHY THE INSTRUCTIONS ARE STUCK!
                    for i in 0 to 3 loop
                        if rs_queue(i).valid = '1' then
                            write(l, string'("[RS ALU DUMP] STUCK PC: "));
                            write(l, integer'image(to_integer(unsigned(rs_queue(i).pc))));
                            write(l, string'(" | PRS_RDY: ")); write(l, std_logic'image(rs_queue(i).prs_rdy));
                            write(l, string'(" | PRT_RDY: ")); write(l, std_logic'image(rs_queue(i).prt_rdy));
                            write(l, string'(" | FLG_RDY: ")); write(l, std_logic'image(rs_queue(i).pr_flag_rdy));
                            writeline(output, l);
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;
end Behavioral;