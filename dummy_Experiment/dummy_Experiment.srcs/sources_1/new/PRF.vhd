library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; -- NEW: Clean Logging!

entity PRF is
    Port (
        clk                 : in std_logic;
        rst                 : in std_logic;

        -- 1. ASYNCHRONOUS READ PORTS
        r_tag_rs1_1         : in std_logic_vector(4 downto 0);
        r_data_rs1_1        : out std_logic_vector(15 downto 0);
        r_tag_rs2_1         : in std_logic_vector(4 downto 0);
        r_data_rs2_1        : out std_logic_vector(15 downto 0);
        r_tag_flag_1        : in std_logic_vector(4 downto 0); 
        r_flags_1           : out std_logic_vector(1 downto 0); 

        r_tag_rs1_2         : in std_logic_vector(4 downto 0);
        r_data_rs1_2        : out std_logic_vector(15 downto 0);
        r_tag_rs2_2         : in std_logic_vector(4 downto 0);
        r_data_rs2_2        : out std_logic_vector(15 downto 0);
        r_tag_flag_2        : in std_logic_vector(4 downto 0); 
        r_flags_2           : out std_logic_vector(1 downto 0); 

        -- 2. SYNCHRONOUS WRITE PORTS 
        we_alu_gpr          : in std_logic;
        tag_alu_gpr         : in std_logic_vector(4 downto 0);
        data_alu_gpr        : in std_logic_vector(15 downto 0);
        we_alu_flag         : in std_logic;
        tag_alu_flag        : in std_logic_vector(4 downto 0);
        data_alu_flag       : in std_logic_vector(1 downto 0);

        we_lsu_gpr          : in std_logic;
        tag_lsu_gpr         : in std_logic_vector(4 downto 0);
        data_lsu_gpr        : in std_logic_vector(15 downto 0);
        we_lsu_flag         : in std_logic;
        tag_lsu_flag        : in std_logic_vector(4 downto 0);
        data_lsu_flag       : in std_logic_vector(1 downto 0);

        we_br_gpr           : in std_logic;
        tag_br_gpr          : in std_logic_vector(4 downto 0);
        data_br_gpr         : in std_logic_vector(15 downto 0)
    );
end PRF;

architecture Behavioral of PRF is
    type prf_data_array is array (0 to 31) of std_logic_vector(15 downto 0);
    type prf_flag_array is array (0 to 31) of std_logic_vector(1 downto 0);

    signal prf_data  : prf_data_array := (others => (others => '0'));
    signal prf_flags : prf_flag_array := (others => (others => '0'));
begin

    -- =========================================================
    -- ASYNCHRONOUS READ LOGIC
    -- =========================================================
    r_data_rs1_1  <= prf_data(to_integer(unsigned(r_tag_rs1_1)));
    r_data_rs2_1  <= prf_data(to_integer(unsigned(r_tag_rs2_1)));
    r_flags_1     <= prf_flags(to_integer(unsigned(r_tag_flag_1)));

    r_data_rs1_2  <= prf_data(to_integer(unsigned(r_tag_rs1_2)));
    r_data_rs2_2  <= prf_data(to_integer(unsigned(r_tag_rs2_2)));
    r_flags_2     <= prf_flags(to_integer(unsigned(r_tag_flag_2)));

    -- =========================================================
    -- SYNCHRONOUS WRITE LOGIC & PROFESSIONAL X-RAY
    -- =========================================================
    process(clk)
        variable l : line;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                for i in 0 to 31 loop
                    prf_data(i)  <= (others => '0');
                    prf_flags(i) <= (others => '0');
                end loop;
            else
                
                -- ALU Writeback
                if we_alu_gpr = '1' then
                    prf_data(to_integer(unsigned(tag_alu_gpr))) <= data_alu_gpr;
                    write(l, string'("[PRF] WRITE ALU    -> Phys P")); write(l, integer'image(to_integer(unsigned(tag_alu_gpr))));
                    write(l, string'(" | DATA: ")); write(l, integer'image(to_integer(signed(data_alu_gpr)))); writeline(output, l);
                end if;
                if we_alu_flag = '1' then
                    prf_flags(to_integer(unsigned(tag_alu_flag))) <= data_alu_flag;
                end if;

                -- LSU Writeback 
                if we_lsu_gpr = '1' then
                    prf_data(to_integer(unsigned(tag_lsu_gpr))) <= data_lsu_gpr;
                    write(l, string'("[PRF] WRITE LSU    -> Phys P")); write(l, integer'image(to_integer(unsigned(tag_lsu_gpr))));
                    write(l, string'(" | DATA: ")); write(l, integer'image(to_integer(signed(data_lsu_gpr)))); writeline(output, l);
                end if;
                if we_lsu_flag = '1' then
                    prf_flags(to_integer(unsigned(tag_lsu_flag))) <= data_lsu_flag;
                end if;

                -- Branch Writeback
                if we_br_gpr = '1' then
                    prf_data(to_integer(unsigned(tag_br_gpr))) <= data_br_gpr;
                    write(l, string'("[PRF] WRITE BRANCH -> Phys P")); write(l, integer'image(to_integer(unsigned(tag_br_gpr))));
                    write(l, string'(" | DATA: ")); write(l, integer'image(to_integer(signed(data_br_gpr)))); writeline(output, l);
                end if;

            end if;
        end if;
    end process;

end Behavioral;