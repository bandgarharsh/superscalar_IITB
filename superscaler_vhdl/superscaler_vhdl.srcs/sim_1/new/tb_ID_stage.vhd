library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_ID_stage is
-- Testbench has no ports
end tb_ID_stage;

architecture behavior of tb_ID_stage is

    -- Component Declaration
    component ID_stage
        Port (
            clk : in std_logic;
            rst : in std_logic;
            stall_fetch : out std_logic;
            
            pc1_in : in std_logic_vector(15 downto 0);
            pc2_in : in std_logic_vector(15 downto 0);
            instruct1_in : in std_logic_vector(15 downto 0);
            instruct2_in : in std_logic_vector(15 downto 0);

            op1 : out std_logic_vector(3 downto 0);
            ra1 : out std_logic_vector(2 downto 0);
            rb1 : out std_logic_vector(2 downto 0);
            rc1 : out std_logic_vector(2 downto 0);
            imm1 : out std_logic_vector(15 downto 0);
            comp_bit1 : out std_logic;
            cz_bits1 : out std_logic_vector(1 downto 0);
            op1_valid : out std_logic;
            pc1_out : out std_logic_vector(15 downto 0);
            
            op2 : out std_logic_vector(3 downto 0);
            ra2 : out std_logic_vector(2 downto 0);
            rb2 : out std_logic_vector(2 downto 0);
            rc2 : out std_logic_vector(2 downto 0);
            imm2 : out std_logic_vector(15 downto 0);
            comp_bit2 : out std_logic;
            cz_bits2 : out std_logic_vector(1 downto 0);
            op2_valid : out std_logic;
            pc2_out : out std_logic_vector(15 downto 0);
            
            slide_inst2 : out std_logic;
            
            route_inst1_tag_to_inst2_rb : out std_logic;
            route_inst1_tag_to_inst2_rc : out std_logic;
            inst2_overrides_rat : out std_logic
        );
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    
    signal pc1_in, pc2_in : std_logic_vector(15 downto 0) := (others => '0');
    signal instruct1_in, instruct2_in : std_logic_vector(15 downto 0) := (others => '0');
    
    signal stall_fetch : std_logic;
    signal op1, op2 : std_logic_vector(3 downto 0);
    signal ra1, ra2 : std_logic_vector(2 downto 0);
    signal rb1, rb2 : std_logic_vector(2 downto 0);
    signal imm1, imm2 : std_logic_vector(15 downto 0);
    signal cz1, cz2 : std_logic_vector(1 downto 0);
    signal val1, val2 : std_logic;
    signal slide_inst2_sig : std_logic;

    constant clk_period : time := 10 ns;

begin

    uut: ID_stage port map (
        clk => clk, rst => rst, stall_fetch => stall_fetch,
        pc1_in => pc1_in, pc2_in => pc2_in,
        instruct1_in => instruct1_in, instruct2_in => instruct2_in,
        
        op1 => op1, ra1 => ra1, rb1 => rb1, rc1 => open,
        imm1 => imm1, comp_bit1 => open, cz_bits1 => cz1, op1_valid => val1, pc1_out => open,
        
        op2 => op2, ra2 => ra2, rb2 => rb2, rc2 => open,
        imm2 => imm2, comp_bit2 => open, cz_bits2 => cz2, op2_valid => val2, pc2_out => open,
        
        slide_inst2 => slide_inst2_sig,
        route_inst1_tag_to_inst2_rb => open,
        route_inst1_tag_to_inst2_rc => open,
        inst2_overrides_rat => open
    );

    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus Process
    stim_proc: process
    begin
        wait for 20 ns;
        rst <= '0';
        wait for clk_period;
        
        -- =====================================================================
        -- TEST 1: FULL MASK (11111111)
        -- Should take exactly 4 clock cycles to output 8 registers, 
        -- piggybacking the flag on the 8th register!
        -- =====================================================================
        report "--- TEST 1: FULL MASK (xFF) ---";
        instruct1_in <= "0110010111111111"; -- LM R2, Flag=1, Mask=11111111
        pc1_in <= x"0010";
        instruct2_in <= x"0000"; 
        
        wait for clk_period;
        while stall_fetch = '0' loop wait for clk_period; end loop;
        report "--- CRACKER STARTED (FULL MASK) ---";
        while stall_fetch = '1' loop wait for clk_period; end loop;
        report "--- CRACKER FINISHED (FULL MASK) ---";
        
        instruct1_in <= x"0000"; -- Clear it out
        wait for clk_period * 2;

        -- =====================================================================
        -- TEST 2: ZERO MASK (00000000)
        -- Should take exactly 1 clock cycle, using the edge-case fallback logic.
        -- =====================================================================
        report "--- TEST 2: ZERO MASK (x00) ---";
        instruct1_in <= "0110010100000000"; -- LM R2, Flag=1, Mask=00000000
        pc1_in <= x"0020";
        instruct2_in <= x"0000"; 
        
        wait for clk_period;
        while stall_fetch = '0' loop wait for clk_period; end loop;
        report "--- CRACKER STARTED (ZERO MASK) ---";
        while stall_fetch = '1' loop wait for clk_period; end loop;
        report "--- CRACKER FINISHED (ZERO MASK) ---";

        instruct1_in <= x"0000"; -- Clear it out
        wait for clk_period * 2;
        
        -- =====================================================================
        -- TEST 3: SINGLE REGISTER MASK (00000001)
        -- Should take exactly 1 clock cycle, piggybacking the flag onto R7!
        -- =====================================================================
        report "--- TEST 3: SINGLE REG MASK (x01) ---";
        instruct1_in <= "0110010100000001"; -- LM R2, Flag=1, Mask=00000001
        pc1_in <= x"0030";
        instruct2_in <= x"0000"; 
        
        wait for clk_period;
        while stall_fetch = '0' loop wait for clk_period; end loop;
        report "--- CRACKER STARTED (SINGLE REG) ---";
        while stall_fetch = '1' loop wait for clk_period; end loop;
        report "--- CRACKER FINISHED (SINGLE REG) ---";

        report "--- ALL TESTS COMPLETE ---";
        std.env.stop;
        wait;
    end process;

end behavior;