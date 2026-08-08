library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity free_list is
    Port(
        clk : in std_logic;
        rst : in std_logic;

        pop1 : in std_logic;
        pop2 : in std_logic;

        free_pr1 : out std_logic_vector(4 downto 0);
        free_pr2 : out std_logic_vector(4 downto 0);

        empty_stall : out std_logic;

        push1 : in std_logic;
        freed_pr1 : in std_logic_vector(4 downto 0);

        push2 : in std_logic;
        freed_pr2 : in std_logic_vector(4 downto 0)
    );
end free_list;

architecture Behavioral of free_list is

    type fifo_array is array (0 to 31) of std_logic_vector(4 downto 0);
    signal fifo : fifo_array;

    signal head  : unsigned(4 downto 0);
    signal tail  : unsigned(4 downto 0);
    signal count : unsigned(5 downto 0);

    signal empty_stall_s : std_logic;

begin

    ------------------------------------------------------------------
    -- Read Ports
    ------------------------------------------------------------------

    free_pr1 <= fifo(to_integer(head));
    free_pr2 <= fifo(to_integer(head + 1));

    ------------------------------------------------------------------
    -- Empty Stall Logic
    ------------------------------------------------------------------

    empty_stall_s <= '1' when
        ((pop1 = '1' and pop2 = '1' and count < to_unsigned(2,6)) or
         (pop1 = '1' and pop2 = '0' and count < to_unsigned(1,6)))
    else
        '0';

    empty_stall <= empty_stall_s;

    ------------------------------------------------------------------
    -- FIFO Logic
    ------------------------------------------------------------------

    process(clk, rst)
        variable cnt : integer;
    begin

        if rst = '1' then

            for i in 0 to 23 loop
                fifo(i) <= std_logic_vector(to_unsigned(i + 8,5));
            end loop;

            head  <= to_unsigned(0,5);
            tail  <= to_unsigned(24,5);
            count <= to_unsigned(24,6);

        elsif rising_edge(clk) then

            ----------------------------------------------------------
            -- Pop
            ----------------------------------------------------------

            if (pop1='1' and pop2='1' and empty_stall_s='0') then
                head <= head + 2;

            elsif (pop1='1' and empty_stall_s='0') then
                head <= head + 1;

            end if;

            ----------------------------------------------------------
            -- Push
            ----------------------------------------------------------

            if (push1='1' and push2='1') then

                fifo(to_integer(tail)) <= freed_pr1;
                fifo(to_integer(tail + 1)) <= freed_pr2;
                tail <= tail + 2;

            elsif push1='1' then

                fifo(to_integer(tail)) <= freed_pr1;
                tail <= tail + 1;

            elsif push2='1' then

                fifo(to_integer(tail)) <= freed_pr2;
                tail <= tail + 1;

            end if;

            ----------------------------------------------------------
            -- Count Update
            ----------------------------------------------------------

            cnt := to_integer(count);

            if pop1='1' then
                cnt := cnt - 1;
            end if;

            if pop2='1' then
                cnt := cnt - 1;
            end if;

            if push1='1' then
                cnt := cnt + 1;
            end if;

            if push2='1' then
                cnt := cnt + 1;
            end if;

            count <= to_unsigned(cnt,6);

        end if;

    end process;

end Behavioral;