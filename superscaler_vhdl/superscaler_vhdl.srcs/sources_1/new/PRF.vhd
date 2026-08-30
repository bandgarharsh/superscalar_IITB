library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PRF is
    Port (
        clk                 : in std_logic;
        rst                 : in std_logic;

        -- =========================================================
        -- 1. ASYNCHRONOUS READ PORTS (To feed Dispatch/RS Data)
        -- =========================================================
        -- Instruction 1 Sources
        r_tag_rs1_1         : in std_logic_vector(4 downto 0);
        r_data_rs1_1        : out std_logic_vector(15 downto 0);
        
        r_tag_rs2_1         : in std_logic_vector(4 downto 0);
        r_data_rs2_1        : out std_logic_vector(15 downto 0);
        
        r_tag_flag_1        : in std_logic_vector(4 downto 0); 
        r_flags_1           : out std_logic_vector(1 downto 0); 

        -- Instruction 2 Sources
        r_tag_rs1_2         : in std_logic_vector(4 downto 0);
        r_data_rs1_2        : out std_logic_vector(15 downto 0);
        
        r_tag_rs2_2         : in std_logic_vector(4 downto 0);
        r_data_rs2_2        : out std_logic_vector(15 downto 0);
        
        r_tag_flag_2        : in std_logic_vector(4 downto 0); 
        r_flags_2           : out std_logic_vector(1 downto 0); 

        -- =========================================================
        -- 2. SYNCHRONOUS WRITE PORTS (Connected directly to CDBs)
        -- =========================================================
        -- ALU Execution Unit CDB (GPR & Flags)
        we_alu_gpr          : in std_logic;
        tag_alu_gpr         : in std_logic_vector(4 downto 0);
        data_alu_gpr        : in std_logic_vector(15 downto 0);
        
        we_alu_flag         : in std_logic;
        tag_alu_flag        : in std_logic_vector(4 downto 0);
        data_alu_flag       : in std_logic_vector(1 downto 0);

        -- LSU Execution Unit CDB (GPR & Flags)
        we_lsu_gpr          : in std_logic;
        tag_lsu_gpr         : in std_logic_vector(4 downto 0);
        data_lsu_gpr        : in std_logic_vector(15 downto 0);
        
        we_lsu_flag         : in std_logic;
        tag_lsu_flag        : in std_logic_vector(4 downto 0);
        data_lsu_flag       : in std_logic_vector(1 downto 0);

        -- Branch Execution Unit CDB (GPR Only - No flags modified by Branch)
        we_br_gpr           : in std_logic;
        tag_br_gpr          : in std_logic_vector(4 downto 0);
        data_br_gpr         : in std_logic_vector(15 downto 0)
    );
end PRF;

architecture Behavioral of PRF is

    -- 32 Physical Registers for GPRs
    type prf_data_array is array (0 to 31) of std_logic_vector(15 downto 0);
    -- 32 Physical Registers for Flags
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
    -- SYNCHRONOUS WRITE LOGIC (CDB Snoop)
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                for i in 0 to 31 loop
                    prf_data(i)  <= (others => '0');
                    prf_flags(i) <= (others => '0');
                end loop;
            else
                
                -- ALU Writeback (Separated into GPR and Flag)
                if we_alu_gpr = '1' then
                    prf_data(to_integer(unsigned(tag_alu_gpr))) <= data_alu_gpr;
                    report "[X-RAY PRF] WRITE from ALU -> PRF_TAG: " & integer'image(to_integer(unsigned(tag_alu_gpr))) & 
                           " | DATA: " & integer'image(to_integer(unsigned(data_alu_gpr)));
                end if;
                
                if we_alu_flag = '1' then
                    prf_flags(to_integer(unsigned(tag_alu_flag))) <= data_alu_flag;
                    report "[X-RAY PRF] WRITE from ALU -> FLAG_TAG: " & integer'image(to_integer(unsigned(tag_alu_flag))) & 
                           " | DATA: " & integer'image(to_integer(unsigned(data_alu_flag)));
                end if;

                -- LSU Writeback (Separated into GPR and Flag)
                if we_lsu_gpr = '1' then
                    prf_data(to_integer(unsigned(tag_lsu_gpr))) <= data_lsu_gpr;
                    report "[X-RAY PRF] WRITE from LSU -> PRF_TAG: " & integer'image(to_integer(unsigned(tag_lsu_gpr))) & 
                           " | DATA: " & integer'image(to_integer(unsigned(data_lsu_gpr)));
                end if;
                
                if we_lsu_flag = '1' then
                    prf_flags(to_integer(unsigned(tag_lsu_flag))) <= data_lsu_flag;
                    report "[X-RAY PRF] WRITE from LSU -> FLAG_TAG: " & integer'image(to_integer(unsigned(tag_lsu_flag))) & 
                           " | DATA: " & integer'image(to_integer(unsigned(data_lsu_flag)));
                end if;

                -- Branch Writeback (GPR Only)
                if we_br_gpr = '1' then
                    prf_data(to_integer(unsigned(tag_br_gpr))) <= data_br_gpr;
                    report "[X-RAY PRF] WRITE from BRANCH -> PRF_TAG: " & integer'image(to_integer(unsigned(tag_br_gpr))) & 
                           " | DATA: " & integer'image(to_integer(unsigned(data_br_gpr)));
                end if;

            end if;
        end if;
    end process;

end Behavioral;