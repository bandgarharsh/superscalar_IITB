library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ID_RF is
    Port (
        clk  : in std_logic;
        rst  : in std_logic;

        -- Program Counters
        pc1_in : in std_logic_vector(15 downto 0);
        pc2_in : in std_logic_vector(15 downto 0);

        -- Instruction 1
        op1_in       : in std_logic_vector(3 downto 0);
        ra1_in       : in std_logic_vector(2 downto 0);
        rb1_in       : in std_logic_vector(2 downto 0);
        rc1_in       : in std_logic_vector(2 downto 0);
        imm1_in      : in std_logic_vector(15 downto 0);
        comp_bit1_in : in std_logic;
        cz_bits1_in  : in std_logic_vector(1 downto 0);

        -- Instruction 2
        op2_in       : in std_logic_vector(3 downto 0);
        ra2_in       : in std_logic_vector(2 downto 0);
        rb2_in       : in std_logic_vector(2 downto 0);
        rc2_in       : in std_logic_vector(2 downto 0);
        imm2_in      : in std_logic_vector(15 downto 0);
        comp_bit2_in : in std_logic;
        cz_bits2_in  : in std_logic_vector(1 downto 0);

        -- Dependency flags
        route_inst1_tag_to_inst2_rb_in : in std_logic;
        route_inst1_tag_to_inst2_rc_in : in std_logic;
        inst2_overrides_rat_in         : in std_logic;

        -- Outputs
        pc1_op : out std_logic_vector(15 downto 0);
        pc2_op : out std_logic_vector(15 downto 0);

        op1_op : out std_logic_vector(3 downto 0);
        ra1_op : out std_logic_vector(2 downto 0);
        rb1_op : out std_logic_vector(2 downto 0);
        rc1_op : out std_logic_vector(2 downto 0);
        imm1_op : out std_logic_vector(15 downto 0);
        comp_bit1_op : out std_logic;
        cz_bits1_op : out std_logic_vector(1 downto 0);

        op2_op : out std_logic_vector(3 downto 0);
        ra2_op : out std_logic_vector(2 downto 0);
        rb2_op : out std_logic_vector(2 downto 0);
        rc2_op : out std_logic_vector(2 downto 0);
        imm2_op : out std_logic_vector(15 downto 0);
        comp_bit2_op : out std_logic;
        cz_bits2_op : out std_logic_vector(1 downto 0);

        route_inst1_tag_to_inst2_rb_op : out std_logic;
        route_inst1_tag_to_inst2_rc_op : out std_logic;
        inst2_overrides_rat_op         : out std_logic
    );
end ID_RF;

architecture Behavioral of ID_RF is

    signal pc1_reg, pc2_reg : std_logic_vector(15 downto 0);

    signal op1_reg : std_logic_vector(3 downto 0);
    signal ra1_reg, rb1_reg, rc1_reg : std_logic_vector(2 downto 0);
    signal imm1_reg : std_logic_vector(15 downto 0);
    signal comp_bit1_reg : std_logic;
    signal cz_bits1_reg : std_logic_vector(1 downto 0);

    signal op2_reg : std_logic_vector(3 downto 0);
    signal ra2_reg, rb2_reg, rc2_reg : std_logic_vector(2 downto 0);
    signal imm2_reg : std_logic_vector(15 downto 0);
    signal comp_bit2_reg : std_logic;
    signal cz_bits2_reg : std_logic_vector(1 downto 0);

    signal route_rb_reg : std_logic;
    signal route_rc_reg : std_logic;
    signal override_reg : std_logic;

begin

    process(clk, rst)
    begin
        if rst = '1' then

            pc1_reg <= (others => '0');
            pc2_reg <= (others => '0');

            op1_reg <= (others => '0');
            ra1_reg <= (others => '0');
            rb1_reg <= (others => '0');
            rc1_reg <= (others => '0');
            imm1_reg <= (others => '0');
            comp_bit1_reg <= '0';
            cz_bits1_reg <= (others => '0');

            op2_reg <= (others => '0');
            ra2_reg <= (others => '0');
            rb2_reg <= (others => '0');
            rc2_reg <= (others => '0');
            imm2_reg <= (others => '0');
            comp_bit2_reg <= '0';
            cz_bits2_reg <= (others => '0');

            route_rb_reg <= '0';
            route_rc_reg <= '0';
            override_reg <= '0';

        elsif rising_edge(clk) then

            pc1_reg <= pc1_in;
            pc2_reg <= pc2_in;

            op1_reg <= op1_in;
            ra1_reg <= ra1_in;
            rb1_reg <= rb1_in;
            rc1_reg <= rc1_in;
            imm1_reg <= imm1_in;
            comp_bit1_reg <= comp_bit1_in;
            cz_bits1_reg <= cz_bits1_in;

            op2_reg <= op2_in;
            ra2_reg <= ra2_in;
            rb2_reg <= rb2_in;
            rc2_reg <= rc2_in;
            imm2_reg <= imm2_in;
            comp_bit2_reg <= comp_bit2_in;
            cz_bits2_reg <= cz_bits2_in;

            route_rb_reg <= route_inst1_tag_to_inst2_rb_in;
            route_rc_reg <= route_inst1_tag_to_inst2_rc_in;
            override_reg <= inst2_overrides_rat_in;

        end if;
    end process;

    pc1_op <= pc1_reg;
    pc2_op <= pc2_reg;

    op1_op <= op1_reg;
    ra1_op <= ra1_reg;
    rb1_op <= rb1_reg;
    rc1_op <= rc1_reg;
    imm1_op <= imm1_reg;
    comp_bit1_op <= comp_bit1_reg;
    cz_bits1_op <= cz_bits1_reg;

    op2_op <= op2_reg;
    ra2_op <= ra2_reg;
    rb2_op <= rb2_reg;
    rc2_op <= rc2_reg;
    imm2_op <= imm2_reg;
    comp_bit2_op <= comp_bit2_reg;
    cz_bits2_op <= cz_bits2_reg;

    route_inst1_tag_to_inst2_rb_op <= route_rb_reg;
    route_inst1_tag_to_inst2_rc_op <= route_rc_reg;
    inst2_overrides_rat_op <= override_reg;

end Behavioral;