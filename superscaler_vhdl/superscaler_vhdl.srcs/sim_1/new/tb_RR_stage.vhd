library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_RR_stage is
end tb_RR_stage;

architecture Behavioral of tb_RR_stage is

    component RR_stage is
        Port (
            clk, rst : in std_logic;

            valid1_in, valid2_in : in std_logic;
            op1_in, op2_in : in std_logic_vector(3 downto 0);

            ra1_in, ra2_in : in std_logic_vector(2 downto 0);
            rb1_in, rb2_in : in std_logic_vector(2 downto 0);
            rc1_in, rc2_in : in std_logic_vector(2 downto 0);

            imm1_in, imm2_in : in std_logic_vector(15 downto 0);
            cz1_in, cz2_in : in std_logic_vector(1 downto 0);
            comp1_in, comp2_in : in std_logic;
            pc1_in, pc2_in : in std_logic_vector(15 downto 0);

            route_rs2, route_rt2 : in std_logic;

            flush : in std_logic;
            rrat_map_flat : in std_logic_vector(44 downto 0);

            rob_push_gpr1  : in std_logic;
            rob_freed_gpr1 : in std_logic_vector(4 downto 0);

            rob_push_flag1  : in std_logic;
            rob_freed_flag1 : in std_logic_vector(4 downto 0);

            rob_push_gpr2  : in std_logic;
            rob_freed_gpr2 : in std_logic_vector(4 downto 0);

            rob_push_flag2  : in std_logic;
            rob_freed_flag2 : in std_logic_vector(4 downto 0);

            rr_stall : out std_logic;

            valid1_out : out std_logic;
            valid2_out : out std_logic;

            op1_out : out std_logic_vector(3 downto 0);
            op2_out : out std_logic_vector(3 downto 0);

            p_ra1        : out std_logic_vector(4 downto 0);
            p_flag1_dest : out std_logic_vector(4 downto 0);
            p_rb1        : out std_logic_vector(4 downto 0);
            p_rc1        : out std_logic_vector(4 downto 0);
            pr_flag1     : out std_logic_vector(4 downto 0);
            old_p_ra1    : out std_logic_vector(4 downto 0);
            old_pr_flag1 : out std_logic_vector(4 downto 0);
            we_flag1_out : out std_logic;

            imm1_out  : out std_logic_vector(15 downto 0);
            cz1_out   : out std_logic_vector(1 downto 0);
            comp1_out : out std_logic;
            pc1_out   : out std_logic_vector(15 downto 0);

            p_ra2        : out std_logic_vector(4 downto 0);
            p_flag2_dest : out std_logic_vector(4 downto 0);
            p_rb2        : out std_logic_vector(4 downto 0);
            p_rc2        : out std_logic_vector(4 downto 0);
            pr_flag2     : out std_logic_vector(4 downto 0);
            old_p_ra2    : out std_logic_vector(4 downto 0);
            old_pr_flag2 : out std_logic_vector(4 downto 0);
            we_flag2_out : out std_logic;

            imm2_out  : out std_logic_vector(15 downto 0);
            cz2_out   : out std_logic_vector(1 downto 0);
            comp2_out : out std_logic;
            pc2_out   : out std_logic_vector(15 downto 0)
        );
    end component;


    ----------------------------------------------------------------
    -- CLOCK / RESET
    ----------------------------------------------------------------

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    constant clk_period : time := 10 ns;


    ----------------------------------------------------------------
    -- INPUTS
    ----------------------------------------------------------------

    signal v1, v2 : std_logic := '0';

    signal op1, op2 : std_logic_vector(3 downto 0) := "0000";

    signal ra1, ra2 : std_logic_vector(2 downto 0) := "000";
    signal rb1, rb2 : std_logic_vector(2 downto 0) := "000";
    signal rc1, rc2 : std_logic_vector(2 downto 0) := "000";

    signal cz1, cz2 : std_logic_vector(1 downto 0) := "00";

    signal route_rs2 : std_logic := '0';
    signal route_rt2 : std_logic := '0';

    signal flush : std_logic := '0';


    ----------------------------------------------------------------
    -- RRAT
    --
    -- Architectural mappings:
    --
    -- R0 -> PR0
    -- R1 -> PR1
    -- ...
    -- R7 -> PR7
    --
    -- Flag -> PR8
    --
    -- Therefore speculative/free GPR tags start from PR9.
    ----------------------------------------------------------------

    signal rrat_map : std_logic_vector(44 downto 0) :=
        "01000" &   -- FLAG -> PR8
        "00111" &   -- R7 -> PR7
        "00110" &   -- R6 -> PR6
        "00101" &   -- R5 -> PR5
        "00100" &   -- R4 -> PR4
        "00011" &   -- R3 -> PR3
        "00010" &   -- R2 -> PR2
        "00001" &   -- R1 -> PR1
        "00000";    -- R0 -> PR0


    ----------------------------------------------------------------
    -- RETIREMENT INPUTS
    ----------------------------------------------------------------

    signal rob_push_gpr1  : std_logic := '0';
    signal rob_freed_gpr1 : std_logic_vector(4 downto 0) := "00000";

    signal rob_push_flag1  : std_logic := '0';
    signal rob_freed_flag1 : std_logic_vector(4 downto 0) := "00000";

    signal rob_push_gpr2  : std_logic := '0';
    signal rob_freed_gpr2 : std_logic_vector(4 downto 0) := "00000";

    signal rob_push_flag2  : std_logic := '0';
    signal rob_freed_flag2 : std_logic_vector(4 downto 0) := "00000";


    ----------------------------------------------------------------
    -- OUTPUTS
    ----------------------------------------------------------------

    signal rr_stall : std_logic;

    signal valid1_out, valid2_out : std_logic;

    signal op1_out, op2_out : std_logic_vector(3 downto 0);

    signal p_ra1, p_ra2 : std_logic_vector(4 downto 0);

    signal p_flag1_dest, p_flag2_dest :
        std_logic_vector(4 downto 0);

    signal p_rb1, p_rb2 : std_logic_vector(4 downto 0);
    signal p_rc1, p_rc2 : std_logic_vector(4 downto 0);

    signal pr_flag1, pr_flag2 : std_logic_vector(4 downto 0);

    signal old_p_ra1, old_p_ra2 :
        std_logic_vector(4 downto 0);

    signal old_pr_flag1, old_pr_flag2 :
        std_logic_vector(4 downto 0);

    signal we_flag1_out, we_flag2_out : std_logic;


begin

    ----------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------

    uut : RR_stage
        port map (
            clk => clk,
            rst => rst,

            valid1_in => v1,
            valid2_in => v2,

            op1_in => op1,
            op2_in => op2,

            ra1_in => ra1,
            ra2_in => ra2,

            rb1_in => rb1,
            rb2_in => rb2,

            rc1_in => rc1,
            rc2_in => rc2,

            imm1_in => x"0000",
            imm2_in => x"0000",

            cz1_in => cz1,
            cz2_in => cz2,

            comp1_in => '0',
            comp2_in => '0',

            pc1_in => x"0000",
            pc2_in => x"0000",

            route_rs2 => route_rs2,
            route_rt2 => route_rt2,

            flush => flush,
            rrat_map_flat => rrat_map,

            rob_push_gpr1 => rob_push_gpr1,
            rob_freed_gpr1 => rob_freed_gpr1,

            rob_push_flag1 => rob_push_flag1,
            rob_freed_flag1 => rob_freed_flag1,

            rob_push_gpr2 => rob_push_gpr2,
            rob_freed_gpr2 => rob_freed_gpr2,

            rob_push_flag2 => rob_push_flag2,
            rob_freed_flag2 => rob_freed_flag2,

            rr_stall => rr_stall,

            valid1_out => valid1_out,
            valid2_out => valid2_out,

            op1_out => op1_out,
            op2_out => op2_out,

            p_ra1 => p_ra1,
            p_flag1_dest => p_flag1_dest,
            p_rb1 => p_rb1,
            p_rc1 => p_rc1,
            pr_flag1 => pr_flag1,
            old_p_ra1 => old_p_ra1,
            old_pr_flag1 => old_pr_flag1,
            we_flag1_out => we_flag1_out,

            p_ra2 => p_ra2,
            p_flag2_dest => p_flag2_dest,
            p_rb2 => p_rb2,
            p_rc2 => p_rc2,
            pr_flag2 => pr_flag2,
            old_p_ra2 => old_p_ra2,
            old_pr_flag2 => old_pr_flag2,
            we_flag2_out => we_flag2_out,

            imm1_out => open,
            cz1_out => open,
            comp1_out => open,
            pc1_out => open,

            imm2_out => open,
            cz2_out => open,
            comp2_out => open,
            pc2_out => open
        );


    ----------------------------------------------------------------
    -- CLOCK
    ----------------------------------------------------------------

    clk_process : process
    begin
        clk <= '0';
        wait for clk_period / 2;

        clk <= '1';
        wait for clk_period / 2;
    end process;


    ----------------------------------------------------------------
    -- TEST PROCESS
    ----------------------------------------------------------------

    stim_proc : process
    begin

        ------------------------------------------------------------
        -- RESET
        ------------------------------------------------------------

        wait for 20 ns;

        rst <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;


        ------------------------------------------------------------
        -- TEST 1
        --
        -- ADD R1,R2,R3
        -- ADD R4,R5,R6
        --
        -- Expected allocations:
        --
        -- GPR  : PR9, PR10
        -- FLAG : PR? depending on your free-list organization
        --
        ------------------------------------------------------------

        report "==============================================";
        report "TEST 1: TWO GPR/FLAG UPDATES";
        report "==============================================";

        v1  <= '1';
        op1 <= "0001";
        ra1 <= "001";
        rb1 <= "010";
        rc1 <= "011";
        cz1 <= "11";

        v2  <= '1';
        op2 <= "0001";
        ra2 <= "100";
        rb2 <= "101";
        rc2 <= "110";
        cz2 <= "11";

        wait until rising_edge(clk);
        wait for 1 ns;


        ------------------------------------------------------------
        -- DISPLAY TEST 1
        ------------------------------------------------------------

        report "TEST1 SLOT1 GPR = PR" &
            integer'image(to_integer(unsigned(p_ra1)));

        report "TEST1 SLOT2 GPR = PR" &
            integer'image(to_integer(unsigned(p_ra2)));

        report "TEST1 SLOT1 FLAG = PR" &
            integer'image(to_integer(unsigned(p_flag1_dest)));

        report "TEST1 SLOT2 FLAG = PR" &
            integer'image(to_integer(unsigned(p_flag2_dest)));


        ------------------------------------------------------------
        -- TEST 2
        --
        -- Another two instructions updating GPR + FLAG.
        --
        -- Expected next free tags.
        --
        ------------------------------------------------------------

        report "==============================================";
        report "TEST 2: WAW HAZARD ON FLAGS";
        report "==============================================";

        v1  <= '1';
        op1 <= "0001";
        ra1 <= "010";
        rb1 <= "011";
        rc1 <= "100";
        cz1 <= "11";

        v2  <= '1';
        op2 <= "0001";
        ra2 <= "011";
        rb2 <= "100";
        rc2 <= "101";
        cz2 <= "11";

        wait until rising_edge(clk);
        wait for 1 ns;


        ------------------------------------------------------------
        -- DISPLAY TEST 2
        ------------------------------------------------------------

        report "TEST2 SLOT1 GPR = PR" &
            integer'image(to_integer(unsigned(p_ra1)));

        report "TEST2 SLOT2 GPR = PR" &
            integer'image(to_integer(unsigned(p_ra2)));

        report "TEST2 SLOT1 FLAG = PR" &
            integer'image(to_integer(unsigned(p_flag1_dest)));

        report "TEST2 SLOT2 FLAG = PR" &
            integer'image(to_integer(unsigned(p_flag2_dest)));

        report "TEST2 SLOT1 FLAG SRC = PR" &
            integer'image(to_integer(unsigned(pr_flag1)));

        report "TEST2 SLOT2 FLAG SRC = PR" &
            integer'image(to_integer(unsigned(pr_flag2)));


        ------------------------------------------------------------
        -- TEST 3
        --
        -- FLUSH
        --
        -- All speculative mappings must disappear.
        --
        -- RAT -> RRAT
        -- Free List -> state corresponding to RRAT
        --
        ------------------------------------------------------------

        report "==============================================";
        report "TEST 3: MISPREDICTION FLUSH";
        report "==============================================";

        v1 <= '0';
        v2 <= '0';

        flush <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        flush <= '0';

        wait for 1 ns;


        ------------------------------------------------------------
        -- TEST 4
        --
        -- After flush the free list should again contain
        -- speculative tags.
        --
        -- Since RRAT occupies PR0-PR8:
        --
        -- Expected first GPR allocation = PR9
        --
        ------------------------------------------------------------

        report "==============================================";
        report "TEST 4: POST-FLUSH ALLOCATION";
        report "==============================================";

        v1  <= '1';
        op1 <= "0001";

        ra1 <= "111";
        rb1 <= "001";
        rc1 <= "010";

        cz1 <= "11";

        v2 <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;


        ------------------------------------------------------------
        -- CHECK POST-FLUSH ALLOCATION
        ------------------------------------------------------------

        report "POST-FLUSH SLOT1 GPR = PR" &
            integer'image(to_integer(unsigned(p_ra1)));

        report "POST-FLUSH SLOT1 FLAG = PR" &
            integer'image(to_integer(unsigned(p_flag1_dest)));


        ------------------------------------------------------------
        -- IMPORTANT ASSERTION
        --
        -- If your free-list really restores to RRAT state,
        -- first GPR allocation should be PR9.
        ------------------------------------------------------------

        assert p_ra1 = "01001"
            report "ERROR: Post-flush GPR allocation is NOT PR9!"
            severity error;


        ------------------------------------------------------------
        -- CLEANUP
        ------------------------------------------------------------

        v1 <= '0';
        v2 <= '0';
        -- =========================================================
        -- TEST 5: RR STALL WHEN FREE LIST IS INSUFFICIENT
        -- =========================================================
        report "==============================================";
        report "TEST 5: RR STALL";
        report "==============================================";
        
        v1 <= '1';
        v2 <= '1';
        
        -- request two GPR + two FLAG = 4 physical registers
        op1 <= "0001";
        op2 <= "0001";
        cz1 <= "11";
        cz2 <= "11";
        
        wait for 1 ns;
        
        if rr_stall = '1' then
            report "RR STALL = 1 : CORRECT";
        else
            report "ERROR: RR STALL should be 1";
        end if;
        report "==============================================";
        report "ALL TESTS COMPLETE";
        report "==============================================";

        std.env.stop;

        wait;

    end process;

end Behavioral;