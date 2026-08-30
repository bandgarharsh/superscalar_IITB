library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL; 
 
entity Store_Queue is
    Port (
        clk             : in std_logic;
        rst             : in std_logic;
        
        -- Flush from Branch Unit. 
        -- Note: Because Stores only write to RAM at Commit, ANY store sitting 
        -- in the SQ when a branch mispredicts is speculative garbage! We wipe them all!
        flush           : in std_logic; 
        
        -- ==========================================
        -- 1. INPUT FROM AGU
        -- ==========================================
        agu_valid       : in std_logic;
        agu_is_store    : in std_logic;
        agu_addr        : in std_logic_vector(15 downto 0);
        agu_packet      : in lsu_issue_packet_t;
        
        -- ==========================================
        -- 2. WAKEUP INTERFACE (Snoop CDB for missing Store Data)
        -- ==========================================
        cdb_gpr_en      : in std_logic_vector(2 downto 0);
        cdb_gpr_tag     : in array_of_5bit(0 to 2);
        cdb_gpr_data    : in array_of_16bit(0 to 2);

        -- ==========================================
        -- 3. COMMIT INTERFACE (From ROB)
        -- ==========================================
        commit_valid    : in std_logic;
        commit_rob_id   : in std_logic_vector(3 downto 0);
        
        -- ==========================================
        -- 4. OUTPUT TO DATA RAM (The official write!)
        -- ==========================================
        ram_write_en    : out std_logic;
        ram_write_addr  : out std_logic_vector(15 downto 0);
        ram_write_data  : out std_logic_vector(15 downto 0);
        
        -- missing rob information signal 
        rob_complete_en : out std_logic;
        rob_id_out : out std_logic_vector(3 downto 0);
        -- ==========================================
        -- 5. OUTPUT TO LOAD QUEUE (For your reverse-search Disambiguation!)
        -- ==========================================
        sq_state_out    : out sq_array_t -- Custom array type from pkg
    );
end Store_Queue;

architecture Behavioral of Store_Queue is

    -- The Internal Array Memory (4 slots is plenty for our processor)
    signal sq_array : sq_array_t;

begin
    
    -- Continuously wire the internal array to the output so the LQ can see it in real-time
    sq_state_out <= sq_array;

    process(clk)
        variable v_sq : sq_array_t;
    begin
        if rising_edge(clk) then
            if rst = '1' or flush = '1' then
                for i in 0 to 3 loop
                    v_sq(i).valid := '0';
                end loop;
                ram_write_en <= '0';
                
            else
                v_sq := sq_array;
                
                -- Default: Do not write to RAM unless the ROB tells us to
                ram_write_en <= '0';
                
                -- -------------------------------------------------------------
                -- PHASE 1: COMMIT & WRITE TO RAM (The ROB says it is safe!)
                -- -------------------------------------------------------------
                if commit_valid = '1' then
                    for i in 0 to 3 loop
                        if v_sq(i).valid = '1' and v_sq(i).rob_id = commit_rob_id then
                            -- FIRE TO PHYSICAL RAM!
                            ram_write_en   <= '1';
                            ram_write_addr <= v_sq(i).mem_addr;
                            ram_write_data <= v_sq(i).store_data;
                            
                            -- =========================================================
                            -- X-RAY 3: WHAT IS THE STORE QUEUE OFFICIALLY WRITING TO RAM?
                            -- =========================================================
                            report "[X-RAY STORE QUEUE COMMIT] MEM_ADDR: " & integer'image(to_integer(unsigned(v_sq(i).mem_addr))) &
                                   " | WRITE_DATA: " & integer'image(to_integer(unsigned(v_sq(i).store_data))) &
                                   " | ROB_ID: " & integer'image(to_integer(unsigned(v_sq(i).rob_id)));
                            -- Delete the instruction from the queue, its job is done.
                            v_sq(i).valid := '0';
                        end if;
                    end loop;
                end if;

                -- -------------------------------------------------------------
                -- PHASE 2: INGEST FROM AGU
                -- -------------------------------------------------------------
                if agu_valid = '1' and agu_is_store = '1' then
                    for i in 0 to 3 loop
                        if v_sq(i).valid = '0' then -- Find first empty slot
                            v_sq(i).valid      := '1';
                            v_sq(i).mem_addr   := agu_addr; -- Address is GUARANTEED ready!
                            
                            -- Is the store data already calculated?
                            v_sq(i).data_ready := agu_packet.prt_rdy;
                            v_sq(i).store_data := agu_packet.prt_data;
                            v_sq(i).prt_tag    := agu_packet.prt_tag; 
                            
                            v_sq(i).rob_id     := agu_packet.rob_id;
                            exit;
                        end if;
                    end loop;
                end if;

                -- -------------------------------------------------------------
                -- PHASE 3: WAKEUP (Snoop the CDB for missing Store Data)
                -- -------------------------------------------------------------
                for i in 0 to 3 loop
                    if v_sq(i).valid = '1' and v_sq(i).data_ready = '0' then
                        for b in 0 to 2 loop
                            if cdb_gpr_en(b) = '1' and cdb_gpr_tag(b) = v_sq(i).prt_tag then
                                v_sq(i).store_data := cdb_gpr_data(b);
                                v_sq(i).data_ready := '1';
                                -- Boom! Now the data is ready for whenever the ROB commits it.
                                rob_id_out <= v_sq(i).rob_id;
                                rob_complete_en <= '1';
                            end if;
                        end loop;
                    end if;
                end loop;

                -- Commit variables back to signals
                sq_array <= v_sq;

            end if;
        end if;
    end process;

end Behavioral;