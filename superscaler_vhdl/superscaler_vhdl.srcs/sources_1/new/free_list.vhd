library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity free_list is
    Port(
        clk : in std_logic;
        rst : in std_logic;

        -- --- MISPREDICTION RECOVERY ---
        flush         : in std_logic;
        rrat_map_flat : in std_logic_vector(44 downto 0); -- 9 registers * 5 bits

        -- 4 Independent Requests (Combinational inputs)
        req_gpr1  : in std_logic;
        req_flag1 : in std_logic;
        req_gpr2  : in std_logic;
        req_flag2 : in std_logic;

        -- 4 Independent PR Allocations
        free_gpr1  : out std_logic_vector(4 downto 0);
        free_flag1 : out std_logic_vector(4 downto 0);
        free_gpr2  : out std_logic_vector(4 downto 0);
        free_flag2 : out std_logic_vector(4 downto 0);

        empty_stall : out std_logic;

        -- 4 Independent Push Requests (From ROB Retirement)
        push_gpr1  : in std_logic; freed_gpr1  : in std_logic_vector(4 downto 0);
        push_flag1 : in std_logic; freed_flag1 : in std_logic_vector(4 downto 0);
        push_gpr2  : in std_logic; freed_gpr2  : in std_logic_vector(4 downto 0);
        push_flag2 : in std_logic; freed_flag2 : in std_logic_vector(4 downto 0)
    );
end free_list;

architecture Behavioral of free_list is

    type fifo_array is array (0 to 31) of std_logic_vector(4 downto 0);
    signal fifo : fifo_array;

    signal head  : unsigned(4 downto 0);
    signal tail  : unsigned(4 downto 0);
    signal count : unsigned(5 downto 0);

    signal empty_stall_s : std_logic;
    signal num_reqs : integer range 0 to 4;
    signal p1, p2, p3, p4 : integer range 0 to 1;

begin

    p1 <= 1 when req_gpr1 = '1' else 0;
    p2 <= 1 when req_flag1 = '1' else 0;
    p3 <= 1 when req_gpr2 = '1' else 0;
    p4 <= 1 when req_flag2 = '1' else 0;
    
    num_reqs <= p1 + p2 + p3 + p4;

    free_gpr1  <= fifo(to_integer(head));
    free_flag1 <= fifo(to_integer(head + p1));
    free_gpr2  <= fifo(to_integer(head + p1 + p2));
    free_flag2 <= fifo(to_integer(head + p1 + p2 + p3));

    empty_stall_s <= '1' when count < to_unsigned(num_reqs, 6) else '0';
    empty_stall   <= empty_stall_s;

    process(clk, rst)
        variable active_pops   : integer range 0 to 4;
        variable push_offset   : integer range 0 to 4;
        variable cnt           : integer range -4 to 63;
        
        -- Flush Rebuild Variables
        variable is_allocated  : boolean;
        variable rebuild_count : integer range 0 to 32;
    begin
        if rst = '1' then
            for i in 0 to 22 loop
                fifo(i) <= std_logic_vector(to_unsigned(i + 9,5));
            end loop;
            head  <= to_unsigned(0,5);
            tail  <= to_unsigned(23,5);
            count <= to_unsigned(23,6);

        elsif rising_edge(clk) then
            
            -- =======================================================
            -- FLUSH RECOVERY (1-Cycle Hardware Rebuild)
            -- =======================================================
            if flush = '1' then
                rebuild_count := 0;
                
                -- Sweep all 32 Physical Registers
                for i in 0 to 31 loop
                    is_allocated := false;
                    
                    -- Check if 'i' is currently safe inside the RRAT
                    for j in 0 to 8 loop
                        if to_unsigned(i, 5) = unsigned(rrat_map_flat((j*5)+4 downto j*5)) then
                            is_allocated := true;
                        end if;
                    end loop;
                    
                    -- If it's not in the RRAT, it is free! Push it to the new FIFO.
                    if not is_allocated then
                        fifo(rebuild_count) <= std_logic_vector(to_unsigned(i, 5));
                        rebuild_count := rebuild_count + 1;
                    end if;
                end loop;
                
                head <= to_unsigned(0,5);
                tail <= to_unsigned(rebuild_count, 5);
                count <= to_unsigned(rebuild_count, 6);
                
            -- =======================================================
            -- NORMAL OPERATION
            -- =======================================================
            else
                active_pops := 0;
                if empty_stall_s = '0' then
                    active_pops := num_reqs;
                    head <= head + to_unsigned(active_pops, 5);
                end if;

                push_offset := 0;
                if push_gpr1 = '1' then
                    fifo(to_integer(tail + to_unsigned(push_offset, 5))) <= freed_gpr1;
                    push_offset := push_offset + 1;
                end if;
                if push_flag1 = '1' then
                    fifo(to_integer(tail + to_unsigned(push_offset, 5))) <= freed_flag1;
                    push_offset := push_offset + 1;
                end if;
                if push_gpr2 = '1' then
                    fifo(to_integer(tail + to_unsigned(push_offset, 5))) <= freed_gpr2;
                    push_offset := push_offset + 1;
                end if;
                if push_flag2 = '1' then
                    fifo(to_integer(tail + to_unsigned(push_offset, 5))) <= freed_flag2;
                    push_offset := push_offset + 1;
                end if;
                
                tail <= tail + to_unsigned(push_offset, 5);

                cnt := to_integer(count);
                cnt := cnt - active_pops + push_offset;
                count <= to_unsigned(cnt, 6);
            end if;
        end if;
    end process;
end Behavioral;