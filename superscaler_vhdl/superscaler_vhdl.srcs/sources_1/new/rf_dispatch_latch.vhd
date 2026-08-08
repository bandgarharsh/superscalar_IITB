library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rf_dispatch_latch is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        -- Instruction information
        pc1_in : in std_logic_vector(15 downto 0);
        pc2_in : in std_logic_vector(15 downto 0);

        op1_in : in std_logic_vector(3 downto 0);
        op2_in : in std_logic_vector(3 downto 0);

        imm1_in : in std_logic_vector(15 downto 0);
        imm2_in : in std_logic_vector(15 downto 0);

        comp_bit1_in : in std_logic;
        comp_bit2_in : in std_logic;

        cz_bits1_in : in std_logic_vector(1 downto 0);
        cz_bits2_in : in std_logic_vector(1 downto 0);

        -- Destination
        dest_tag1_in : in std_logic_vector(4 downto 0);
        dest_tag2_in : in std_logic_vector(4 downto 0);

        we_dest1_in : in std_logic;
        we_dest2_in : in std_logic;

        -- Source Tags
        tag_rs1_in : in std_logic_vector(4 downto 0);
        tag_rt1_in : in std_logic_vector(4 downto 0);
        tag_rs2_in : in std_logic_vector(4 downto 0);
        tag_rt2_in : in std_logic_vector(4 downto 0);

        -- Source Data
        data_rs1_in : in std_logic_vector(15 downto 0);
        data_rt1_in : in std_logic_vector(15 downto 0);
        data_rs2_in : in std_logic_vector(15 downto 0);
        data_rt2_in : in std_logic_vector(15 downto 0);

        -- Valid bits
        valid_rs1_in : in std_logic;
        valid_rt1_in : in std_logic;
        valid_rs2_in : in std_logic;
        valid_rt2_in : in std_logic;

        -- Outputs
        pc1_out : out std_logic_vector(15 downto 0);
        pc2_out : out std_logic_vector(15 downto 0);

        op1_out : out std_logic_vector(3 downto 0);
        op2_out : out std_logic_vector(3 downto 0);

        imm1_out : out std_logic_vector(15 downto 0);
        imm2_out : out std_logic_vector(15 downto 0);

        comp_bit1_out : out std_logic;
        comp_bit2_out : out std_logic;

        cz_bits1_out : out std_logic_vector(1 downto 0);
        cz_bits2_out : out std_logic_vector(1 downto 0);

        dest_tag1_out : out std_logic_vector(4 downto 0);
        dest_tag2_out : out std_logic_vector(4 downto 0);

        we_dest1_out : out std_logic;
        we_dest2_out : out std_logic;

        payload_rs1 : out std_logic_vector(15 downto 0);
        payload_rt1 : out std_logic_vector(15 downto 0);
        payload_rs2 : out std_logic_vector(15 downto 0);
        payload_rt2 : out std_logic_vector(15 downto 0);

        is_tag_rs1 : out std_logic;
        is_tag_rt1 : out std_logic;
        is_tag_rs2 : out std_logic;
        is_tag_rt2 : out std_logic
    );
end rf_dispatch_latch;

architecture Behavioral of rf_dispatch_latch is

    signal pc1_reg, pc2_reg : std_logic_vector(15 downto 0);
    signal op1_reg, op2_reg : std_logic_vector(3 downto 0);
    signal imm1_reg, imm2_reg : std_logic_vector(15 downto 0);

    signal comp1_reg, comp2_reg : std_logic;
    signal cz1_reg, cz2_reg : std_logic_vector(1 downto 0);

    signal dest1_reg, dest2_reg : std_logic_vector(4 downto 0);
    signal we1_reg, we2_reg : std_logic;

    signal prs1_reg, prt1_reg : std_logic_vector(15 downto 0);
    signal prs2_reg, prt2_reg : std_logic_vector(15 downto 0);

    signal tagrs1_reg, tagrt1_reg : std_logic;
    signal tagrs2_reg, tagrt2_reg : std_logic;

begin

    process(clk,rst)
    begin
        if rst='1' then

            pc1_reg <= (others=>'0');
            pc2_reg <= (others=>'0');

            op1_reg <= (others=>'0');
            op2_reg <= (others=>'0');

            imm1_reg <= (others=>'0');
            imm2_reg <= (others=>'0');

            comp1_reg <= '0';
            comp2_reg <= '0';

            cz1_reg <= (others=>'0');
            cz2_reg <= (others=>'0');

            dest1_reg <= (others=>'0');
            dest2_reg <= (others=>'0');

            we1_reg <= '0';
            we2_reg <= '0';

            prs1_reg <= (others=>'0');
            prt1_reg <= (others=>'0');
            prs2_reg <= (others=>'0');
            prt2_reg <= (others=>'0');

            tagrs1_reg <= '0';
            tagrt1_reg <= '0';
            tagrs2_reg <= '0';
            tagrt2_reg <= '0';

        elsif rising_edge(clk) then

            pc1_reg <= pc1_in;
            pc2_reg <= pc2_in;

            op1_reg <= op1_in;
            op2_reg <= op2_in;

            imm1_reg <= imm1_in;
            imm2_reg <= imm2_in;

            comp1_reg <= comp_bit1_in;
            comp2_reg <= comp_bit2_in;

            cz1_reg <= cz_bits1_in;
            cz2_reg <= cz_bits2_in;

            dest1_reg <= dest_tag1_in;
            dest2_reg <= dest_tag2_in;

            we1_reg <= we_dest1_in;
            we2_reg <= we_dest2_in;

            if valid_rs1_in='1' then
                prs1_reg <= data_rs1_in;
                tagrs1_reg <= '0';
            else
                prs1_reg <= "00000000000" & tag_rs1_in;
                tagrs1_reg <= '1';
            end if;

            if valid_rt1_in='1' then
                prt1_reg <= data_rt1_in;
                tagrt1_reg <= '0';
            else
                prt1_reg <= "00000000000" & tag_rt1_in;
                tagrt1_reg <= '1';
            end if;

            if valid_rs2_in='1' then
                prs2_reg <= data_rs2_in;
                tagrs2_reg <= '0';
            else
                prs2_reg <= "00000000000" & tag_rs2_in;
                tagrs2_reg <= '1';
            end if;

            if valid_rt2_in='1' then
                prt2_reg <= data_rt2_in;
                tagrt2_reg <= '0';
            else
                prt2_reg <= "00000000000" & tag_rt2_in;
                tagrt2_reg <= '1';
            end if;

        end if;
    end process;

    pc1_out <= pc1_reg;
    pc2_out <= pc2_reg;

    op1_out <= op1_reg;
    op2_out <= op2_reg;

    imm1_out <= imm1_reg;
    imm2_out <= imm2_reg;

    comp_bit1_out <= comp1_reg;
    comp_bit2_out <= comp2_reg;

    cz_bits1_out <= cz1_reg;
    cz_bits2_out <= cz2_reg;

    dest_tag1_out <= dest1_reg;
    dest_tag2_out <= dest2_reg;

    we_dest1_out <= we1_reg;
    we_dest2_out <= we2_reg;

    payload_rs1 <= prs1_reg;
    payload_rt1 <= prt1_reg;
    payload_rs2 <= prs2_reg;
    payload_rt2 <= prt2_reg;

    is_tag_rs1 <= tagrs1_reg;
    is_tag_rt1 <= tagrt1_reg;
    is_tag_rs2 <= tagrs2_reg;
    is_tag_rt2 <= tagrt2_reg;

end Behavioral;