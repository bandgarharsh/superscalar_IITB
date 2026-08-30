library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.iitb_risc_pkg.ALL; 

entity Load_Queue is
    Port (
        clk             : in std_logic;
        rst             : in std_logic;
        flush           : in std_logic; -- Branch mispredict wipes uncommitted loads
        
        -- ==========================================
        -- 1. INPUT FROM AGU
        -- ==========================================
        agu_valid       : in std_logic;
        agu_is_store    : in std_logic;
        agu_addr        : in std_logic_vector(15 downto 0);
        agu_packet      : in lsu_issue_packet_t;
        
        -- ==========================================
        -- 2. INPUT FROM STORE QUEUE (The Disambiguation Bus!)
        -- ==========================================
        sq_state_in     : in sq_array_t;
        
        -- ==========================================
        -- 3. DATA RAM INTERFACE
        -- ==========================================
        ram_read_en     : out std_logic;
        ram_read_addr   : out std_logic_vector(15 downto 0);
        ram_data_in     : in std_logic_vector(15 downto 0); -- Arrives 1 cycle after read_en
        
        -- ==========================================
        -- 4. CDB BROADCAST & ROB COMPLETION
        -- ==========================================
        cdb_gpr_en      : out std_logic;
        cdb_gpr_tag     : out std_logic_vector(4 downto 0);
        cdb_gpr_data    : out std_logic_vector(15 downto 0);
        
        cdb_flag_en     : out std_logic;
        cdb_flag_tag    : out std_logic_vector(4 downto 0);
        cdb_flag_data   : out std_logic_vector(1 downto 0);
        
        -- rob informing signals 
        rob_complete_en : out std_logic;
        rob_id_out      : out std_logic_vector(3 downto 0);
        rob_gpr_data    : out std_logic_vector(15 downto 0);
        rob_flag_data   : out std_logic_vector(1 downto 0)
    );
end Load_Queue;

architecture Behavioral of Load_Queue is

    -- The LQ State Machine for each slot
    -- 00: WAIT_SAFE (Checking SQ)
    -- 01: WAIT_RAM  (Sent read_en, waiting for data)
    -- 10: BROADCAST (Data is ready, fire to CDB!)
    
    

    type lq_array_t is array (0 to 3) of lq_entry_t;
    signal lq_array : lq_array_t;

begin

    process(clk)
        variable v_lq         : lq_array_t;
        variable match_found  : boolean;
        variable data_ready   : std_logic;
        variable fwd_data     : std_logic_vector(15 downto 0);
        
        variable diff         : unsigned(3 downto 0);
        variable min_diff     : unsigned(3 downto 0);
        
        variable final_z      : std_logic;
    begin
        if rising_edge(clk) then
            if rst = '1' or flush = '1' then
                for i in 0 to 3 loop
                    v_lq(i).valid := '0';
                end loop;
                ram_read_en     <= '0';
                cdb_gpr_en      <= '0';
                rob_complete_en <= '0';
            else
                v_lq := lq_array;
                
                -- Default strobes
                ram_read_en     <= '0';
                cdb_gpr_en      <= '0';
                cdb_flag_en     <= '0';
                rob_complete_en <= '0';
                
                -- -------------------------------------------------------------
                -- PHASE 1: INGEST FROM AGU (If it's a Load)
                -- -------------------------------------------------------------
                if agu_valid = '1' and agu_is_store = '0' then
                    for i in 0 to 3 loop
                        if v_lq(i).valid = '0' then
                            v_lq(i).valid    := '1';
                            v_lq(i).state    := "00"; -- Start in WAIT_SAFE
                            v_lq(i).mem_addr := agu_addr;
                            v_lq(i).pd_new   := agu_packet.pd_new;
                            v_lq(i).pf_new   := agu_packet.pf_new;
                            v_lq(i).we_gpr   := agu_packet.we_gpr;
                            v_lq(i).we_flag  := agu_packet.we_flag;
                            v_lq(i).rob_id   := agu_packet.rob_id;
                            exit;
                        end if;
                    end loop;
                end if;

                -- -------------------------------------------------------------
                -- PHASE 2: PROCESS THE QUEUE
                -- -------------------------------------------------------------
                for i in 0 to 3 loop
                    if v_lq(i).valid = '1' then
                        
                        -- STATE 00: WAIT SAFE (The Detective Work!)
                        if v_lq(i).state = "00" then
                            match_found := false;
                            min_diff    := "1111"; -- Start with max distance
                            
                            -- Scan the Store Queue!
                            for j in 0 to 3 loop
                                if sq_state_in(j).valid = '1' then
                                    
                                    -- Calculate Age Difference
                                    diff := unsigned(v_lq(i).rob_id) - unsigned(sq_state_in(j).rob_id);
                                    
                                    -- If diff > 0 and diff < 8, the Store is older!
                                    if diff > 0 and diff < 8 then
                                        if sq_state_in(j).mem_addr = v_lq(i).mem_addr then
                                            -- Address match! Is it the most recent one?
                                            if diff < min_diff then
                                                min_diff    := diff;
                                                match_found := true;
                                                data_ready  := sq_state_in(j).data_ready;
                                                fwd_data    := sq_state_in(j).store_data;
                                            end if;
                                        end if;
                                    end if;
                                end if;
                            end loop;

                            -- Evaluate the Detective Work
                            if match_found then
                                if data_ready = '1' then
                                    -- FORWARDING MAGIC! Skip RAM entirely!
                                    v_lq(i).final_data := fwd_data;
                                    v_lq(i).state      := "10"; -- Go straight to Broadcast
                                end if;
                                -- If match_found but data_ready='0', do nothing. (Stall)
                            else
                                -- NO MATCH! Safe to read RAM!
                                ram_read_en   <= '1';
                                ram_read_addr <= v_lq(i).mem_addr;
                                v_lq(i).state := "01"; -- Move to WAIT_RAM
                            end if;
                            
                        -- STATE 01: WAIT RAM (Data comes back this cycle)
                        elsif v_lq(i).state = "01" then
                            v_lq(i).final_data := ram_data_in;
                            v_lq(i).state      := "10"; -- Ready to Broadcast
                            
                        -- STATE 10: BROADCAST TO CDB
                        elsif v_lq(i).state = "10" then
                            
                            -- Calculate Zero Flag for LW
                            if v_lq(i).final_data = x"0000" then
                                final_z := '1';
                            else
                                final_z := '0';
                            end if;
                            
                            -- Blast GPR Data
                            cdb_gpr_en      <= v_lq(i).we_gpr;
                            cdb_gpr_tag     <= v_lq(i).pd_new;
                            cdb_gpr_data    <= v_lq(i).final_data;
                            
                            -- Blast Flag Data (You called this out!)
                            cdb_flag_en     <= v_lq(i).we_flag;
                            cdb_flag_tag    <= v_lq(i).pf_new;
                            cdb_flag_data   <= '0' & final_z;
                            
                            -- Tell the ROB we are completely done!
                            rob_complete_en <= '1';
                            rob_id_out      <= v_lq(i).rob_id;
                            rob_gpr_data    <= v_lq(i).final_data;
                            rob_flag_data   <= '0' & final_z;
                            
                            -- =========================================================
                            -- X-RAY 2: WHAT DATA IS THE LOAD QUEUE BROADCASTING?
                            -- =========================================================
                            report "[X-RAY LOAD QUEUE] MEM_ADDR: " & integer'image(to_integer(unsigned(v_lq(i).mem_addr))) &
                                   " | LOAD_DATA: " & integer'image(to_integer(unsigned(v_lq(i).final_data))) &
                                   " | ROB_ID: " & integer'image(to_integer(unsigned(v_lq(i).rob_id)));
                                   
                            -- Kill the Load, it has successfully retired from execution!
                            v_lq(i).valid := '0';
                            
                        end if;
                    end if;
                end loop;

                -- Commit back to signals
                lq_array <= v_lq;

            end if;
        end if;
    end process;

end Behavioral;