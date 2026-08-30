library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use work.iitb_risc_pkg.ALL; 

entity Store_Queue is
    Port (
        clk             : in std_logic; rst : in std_logic; flush : in std_logic; 
        agu_valid       : in std_logic; 
        agu_is_store : in std_logic; agu_addr : in std_logic_vector(15 downto 0); 
        agu_packet : in lsu_issue_packet_t;
        cdb_gpr_en      : in std_logic_vector(2 downto 0); 
        cdb_gpr_tag : in array_of_5bit(0 to 2); 
        cdb_gpr_data : in array_of_16bit(0 to 2);
        commit_valid    : in std_logic; 
        commit_rob_id : in std_logic_vector(3 downto 0);
        ram_write_en    : out std_logic; 
        ram_write_addr : out std_logic_vector(15 downto 0); 
        ram_write_data : out std_logic_vector(15 downto 0);
        rob_complete_en : out std_logic; 
        rob_id_out : out std_logic_vector(3 downto 0);
        sq_state_out    : out sq_array_t 
    );
end Store_Queue;

architecture Behavioral of Store_Queue is
    signal sq_array : sq_array_t;
    
    -- X-Ray Signals
    signal log_ingest_active : std_logic := '0';
    signal log_ingest_addr   : std_logic_vector(15 downto 0);
    signal log_ingest_data   : std_logic_vector(15 downto 0);
    signal log_ingest_rob    : std_logic_vector(3 downto 0);
    
    signal log_write_active  : std_logic := '0';
    signal log_write_addr    : std_logic_vector(15 downto 0);
    signal log_write_data    : std_logic_vector(15 downto 0);
begin
    sq_state_out <= sq_array;

    process(clk)
        variable v_sq : sq_array_t;
        variable v_rob_notify : boolean;
    begin
        if rising_edge(clk) then
            log_write_active <= '0'; log_ingest_active <= '0';
            rob_complete_en <= '0'; ram_write_en <= '0';
            v_rob_notify := false;
            
            if rst = '1' or flush = '1' then
                for i in 0 to 3 loop v_sq(i).valid := '0'; end loop;
                sq_array <= v_sq;
            else
                v_sq := sq_array;
                
                -- PHASE 1: COMMIT TO RAM
                if commit_valid = '1' then
                    for i in 0 to 3 loop
                        if v_sq(i).valid = '1' and v_sq(i).rob_id = commit_rob_id then
                            ram_write_en   <= '1';
                            ram_write_addr <= v_sq(i).mem_addr;
                            ram_write_data <= v_sq(i).store_data;
                            
                            log_write_active <= '1'; log_write_addr <= v_sq(i).mem_addr; log_write_data <= v_sq(i).store_data;
                            v_sq(i).valid := '0';
                        end if;
                    end loop;
                end if;

                -- PHASE 2: INGEST FROM AGU
                if agu_valid = '1' and agu_is_store = '1' then
                    for i in 0 to 3 loop
                        if v_sq(i).valid = '0' then 
                            v_sq(i).valid      := '1';
                            v_sq(i).mem_addr   := agu_addr; 
                            v_sq(i).rob_id     := agu_packet.rob_id;
                            v_sq(i).prt_tag    := agu_packet.prt_tag; 
                            
                            -- THE FIX: RS_LSU ALREADY WAITED FOR THE DATA! FORCE IT READY!
                            v_sq(i).data_ready := '1';
                            v_sq(i).store_data := agu_packet.prt_data;
                            
                            if not v_rob_notify then
                                rob_complete_en <= '1'; rob_id_out <= agu_packet.rob_id; v_rob_notify := true;
                            end if;
                            
                            log_ingest_active <= '1'; 
                            log_ingest_addr <= agu_addr; 
                            log_ingest_data <= agu_packet.prt_data;
                            log_ingest_rob <= agu_packet.rob_id;
                            exit;
                        end if;
                    end loop;
                end if;

                sq_array <= v_sq;
            end if;
        end if;
    end process;

    -- =========================================================
    -- PROFESSIONAL X-RAY
    -- =========================================================
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if log_ingest_active = '1' then
                write(l, string'("[STORE QUEUE] ADDED STORE -> ROB ID: ")); write(l, integer'image(to_integer(unsigned(log_ingest_rob))));
                write(l, string'(" | Addr: ")); write(l, integer'image(to_integer(unsigned(log_ingest_addr))));
                write(l, string'(" | Data READY: ")); write(l, integer'image(to_integer(signed(log_ingest_data))));
                writeline(output, l);
            end if;
            if log_write_active = '1' then
                write(l, string'("[STORE QUEUE] OFFICIALLY WRITING TO RAM -> Addr: ")); write(l, integer'image(to_integer(unsigned(log_write_addr))));
                write(l, string'(" | Data: ")); write(l, integer'image(to_integer(signed(log_write_data)))); writeline(output, l);
            end if;
        end if;
    end process;
end Behavioral;