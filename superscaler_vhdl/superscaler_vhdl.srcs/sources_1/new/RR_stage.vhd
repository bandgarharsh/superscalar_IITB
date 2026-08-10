library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RR_stage is
    Port (
        clk : in std_logic;
        rst : in std_logic;

        -- Inputs from ID Stage
        valid1_in : in std_logic; op1_in : in std_logic_vector(3 downto 0);
        ra1_in, rb1_in, rc1_in : in std_logic_vector(2 downto 0);
        imm1_in : in std_logic_vector(15 downto 0); cz1_in : in std_logic_vector(1 downto 0);
        comp1_in : in std_logic; pc1_in : in std_logic_vector(15 downto 0);

        valid2_in : in std_logic; op2_in : in std_logic_vector(3 downto 0);
        ra2_in, rb2_in, rc2_in : in std_logic_vector(2 downto 0);
        imm2_in : in std_logic_vector(15 downto 0); cz2_in : in std_logic_vector(1 downto 0);
        comp2_in : in std_logic; pc2_in : in std_logic_vector(15 downto 0);

        route_rs2, route_rt2 : in std_logic;

        -- Recovery / Retirement Inputs
        flush         : in std_logic;
        rrat_map_flat : in std_logic_vector(44 downto 0); 
        
        -- Independent Retirement Pushes
        rob_push_gpr1  : in std_logic; rob_freed_gpr1  : in std_logic_vector(4 downto 0);
        rob_push_flag1 : in std_logic; rob_freed_flag1 : in std_logic_vector(4 downto 0);
        rob_push_gpr2  : in std_logic; rob_freed_gpr2  : in std_logic_vector(4 downto 0);
        rob_push_flag2 : in std_logic; rob_freed_flag2 : in std_logic_vector(4 downto 0);

        -- Outputs to Dispatch Stage
        rr_stall  : out std_logic; 

        valid1_out, we_flag1_out : out std_logic;
        op1_out : out std_logic_vector(3 downto 0);
        p_ra1, p_flag1_dest, p_rb1, p_rc1, pr_flag1, old_p_ra1, old_pr_flag1 : out std_logic_vector(4 downto 0);
        imm1_out : out std_logic_vector(15 downto 0); cz1_out : out std_logic_vector(1 downto 0);
        comp1_out : out std_logic; pc1_out : out std_logic_vector(15 downto 0);

        valid2_out, we_flag2_out : out std_logic;
        op2_out : out std_logic_vector(3 downto 0);
        p_ra2, p_flag2_dest, p_rb2, p_rc2, pr_flag2, old_p_ra2, old_pr_flag2 : out std_logic_vector(4 downto 0);
        imm2_out : out std_logic_vector(15 downto 0); cz2_out : out std_logic_vector(1 downto 0);
        comp2_out : out std_logic; pc2_out : out std_logic_vector(15 downto 0)
    );
end RR_stage;

architecture Behavioral of RR_stage is

    signal inst1_writes_reg, inst2_writes_reg : std_logic;
    signal we_flag1_s, we_flag2_s : std_logic;
    
    signal req_gpr1_s, req_flag1_s : std_logic;
    signal req_gpr2_s, req_flag2_s : std_logic;
    
    signal we_gpr1_rat, we_flag1_rat : std_logic;
    signal we_gpr2_rat, we_flag2_rat : std_logic;
    
    signal free_gpr1_s, free_flag1_s : std_logic_vector(4 downto 0);
    signal free_gpr2_s, free_flag2_s : std_logic_vector(4 downto 0);
    signal empty_stall_s : std_logic;

    -- Combinational RAT outputs
    signal p_rb1_s, p_rc1_s, pr_flag1_s, old_p_ra1_s, old_pr_flag1_s : std_logic_vector(4 downto 0);
    signal p_rb2_s, p_rc2_s, pr_flag2_s, old_p_ra2_s, old_pr_flag2_s : std_logic_vector(4 downto 0);

    -- ==============================================================
    -- LATCH REGISTERS (Synchronizes outputs for Dispatch Stage)
    -- ==============================================================
    signal val1_reg, val2_reg : std_logic;
    signal op1_reg, op2_reg : std_logic_vector(3 downto 0);
    signal we_f1_reg, we_f2_reg : std_logic;
    
    signal p_ra1_reg, p_flag1_dest_reg, p_rb1_reg, p_rc1_reg, pr_flag1_reg, old_ra1_reg, old_f1_reg : std_logic_vector(4 downto 0);
    signal p_ra2_reg, p_flag2_dest_reg, p_rb2_reg, p_rc2_reg, pr_flag2_reg, old_ra2_reg, old_f2_reg : std_logic_vector(4 downto 0);

begin

    -- 1. Intentions & Requests
    inst1_writes_reg <= '1' when (valid1_in = '1' and (op1_in = "0001" or op1_in = "0010" or op1_in = "0100" or op1_in = "0011")) else '0';
    inst2_writes_reg <= '1' when (valid2_in = '1' and (op2_in = "0001" or op2_in = "0010" or op2_in = "0100" or op2_in = "0011")) else '0';

    we_flag1_s <= '1' when (valid1_in = '1' and (op1_in = "0001" or op1_in = "0010" or cz1_in = "11")) else '0';
    we_flag2_s <= '1' when (valid2_in = '1' and (op2_in = "0001" or op2_in = "0010" or cz2_in = "11")) else '0';

    req_gpr1_s  <= inst1_writes_reg and not flush;
    req_flag1_s <= we_flag1_s and not flush;
    req_gpr2_s  <= inst2_writes_reg and not flush;
    req_flag2_s <= we_flag2_s and not flush;
    
    rr_stall <= empty_stall_s;

    -- 2. Modules
    free_list_inst : entity work.free_list port map (
        clk => clk, rst => rst, flush => flush, rrat_map_flat => rrat_map_flat,
        req_gpr1 => req_gpr1_s, req_flag1 => req_flag1_s, req_gpr2 => req_gpr2_s, req_flag2 => req_flag2_s,
        free_gpr1 => free_gpr1_s, free_flag1 => free_flag1_s, free_gpr2 => free_gpr2_s, free_flag2 => free_flag2_s,
        empty_stall => empty_stall_s,
        push_gpr1 => rob_push_gpr1, freed_gpr1 => rob_freed_gpr1, push_flag1 => rob_push_flag1, freed_flag1 => rob_freed_flag1,
        push_gpr2 => rob_push_gpr2, freed_gpr2 => rob_freed_gpr2, push_flag2 => rob_push_flag2, freed_flag2 => rob_freed_flag2
    );

    we_gpr1_rat  <= req_gpr1_s and not empty_stall_s;
    we_flag1_rat <= req_flag1_s and not empty_stall_s;
    we_gpr2_rat  <= req_gpr2_s and not empty_stall_s;
    we_flag2_rat <= req_flag2_s and not empty_stall_s;

    rat_inst : entity work.RAT port map (
        clk => clk, rst => rst, flush => flush, rrat_map_flat => rrat_map_flat,
        rs1 => rb1_in, rt1 => rc1_in, rs2 => rb2_in, rt2 => rc2_in, rd1 => ra1_in, rd2 => ra2_in,
        route_rs2_from_inst1 => route_rs2, route_rt2_from_inst1 => route_rt2,
        
        prs1 => p_rb1_s, prt1 => p_rc1_s, prs2 => p_rb2_s, prt2 => p_rc2_s,
        old_pr1 => old_p_ra1_s, old_pr2 => old_p_ra2_s,
        pr_flag1 => pr_flag1_s, pr_flag2 => pr_flag2_s,
        old_pr_flag1 => old_pr_flag1_s, old_pr_flag2 => old_pr_flag2_s,
        
        we1 => we_gpr1_rat, we_flag1 => we_flag1_rat, rd1_in => ra1_in, new_gpr1 => free_gpr1_s, new_flag1 => free_flag1_s,
        we2 => we_gpr2_rat, we_flag2 => we_flag2_rat, rd2_in => ra2_in, new_gpr2 => free_gpr2_s, new_flag2 => free_flag2_s
    );

    -- 3. Pipeline Register (Captures allocations BEFORE the Free List head advances)
    process(clk, rst)
    begin
        if rst = '1' then
            val1_reg <= '0'; val2_reg <= '0';
        elsif rising_edge(clk) then
            if flush = '1' then
                val1_reg <= '0'; val2_reg <= '0';
            elsif empty_stall_s = '0' then
                val1_reg <= valid1_in; val2_reg <= valid2_in;
                op1_reg <= op1_in; op2_reg <= op2_in;
                we_f1_reg <= we_flag1_s; we_f2_reg <= we_flag2_s;
                
                -- Capture the exact tags generated this cycle
                p_ra1_reg <= free_gpr1_s; p_flag1_dest_reg <= free_flag1_s;
                p_rb1_reg <= p_rb1_s; p_rc1_reg <= p_rc1_s; pr_flag1_reg <= pr_flag1_s;
                old_ra1_reg <= old_p_ra1_s; old_f1_reg <= old_pr_flag1_s;
                
                p_ra2_reg <= free_gpr2_s; p_flag2_dest_reg <= free_flag2_s;
                p_rb2_reg <= p_rb2_s; p_rc2_reg <= p_rc2_s; pr_flag2_reg <= pr_flag2_s;
                old_ra2_reg <= old_p_ra2_s; old_f2_reg <= old_pr_flag2_s;
            end if;
        end if;
    end process;

    -- Drive registered outputs
    valid1_out <= val1_reg; op1_out <= op1_reg; we_flag1_out <= we_f1_reg;
    p_ra1 <= p_ra1_reg; p_flag1_dest <= p_flag1_dest_reg; p_rb1 <= p_rb1_reg; p_rc1 <= p_rc1_reg; 
    pr_flag1 <= pr_flag1_reg; old_p_ra1 <= old_ra1_reg; old_pr_flag1 <= old_f1_reg;

    valid2_out <= val2_reg; op2_out <= op2_reg; we_flag2_out <= we_f2_reg;
    p_ra2 <= p_ra2_reg; p_flag2_dest <= p_flag2_dest_reg; p_rb2 <= p_rb2_reg; p_rc2 <= p_rc2_reg;
    pr_flag2 <= pr_flag2_reg; old_p_ra2 <= old_ra2_reg; old_pr_flag2 <= old_f2_reg;

    -- Un-renamed pass-throughs
    imm1_out <= imm1_in; cz1_out <= cz1_in; comp1_out <= comp1_in; pc1_out <= pc1_in;
    imm2_out <= imm2_in; cz2_out <= cz2_in; comp2_out <= comp2_in; pc2_out <= pc2_in;

    -- =================================================================
    -- SIMULATION DEBUG PRINTING (Now checks registered outputs!)
    -- =================================================================
    -- synthesis translate_off
    process
    begin
        wait until rising_edge(clk);
        wait for 1 ns;

        if rst = '0' and (val1_reg = '1' or val2_reg = '1' or flush = '1') then
            report "-------------------------------------------------------------";
            report "TIME: " & time'image(now) & " | FLUSH: " & std_logic'image(flush);

            if val1_reg = '1' then
                report "  SLOT 1 | OP: " & integer'image(to_integer(unsigned(op1_reg))) &
                       " | GPR_DEST: " & integer'image(to_integer(unsigned(p_ra1_reg))) &
                       " | FLAG_DEST: " & integer'image(to_integer(unsigned(p_flag1_dest_reg))) &
                       " | SRC1: " & integer'image(to_integer(unsigned(p_rb1_reg))) &
                       " | SRC2: " & integer'image(to_integer(unsigned(p_rc1_reg))) &
                       " | FLAG_SRC: " & integer'image(to_integer(unsigned(pr_flag1_reg)));
            end if;

            if val2_reg = '1' then
                report "  SLOT 2 | OP: " & integer'image(to_integer(unsigned(op2_reg))) &
                       " | GPR_DEST: " & integer'image(to_integer(unsigned(p_ra2_reg))) &
                       " | FLAG_DEST: " & integer'image(to_integer(unsigned(p_flag2_dest_reg))) &
                       " | SRC1: " & integer'image(to_integer(unsigned(p_rb2_reg))) &
                       " | SRC2: " & integer'image(to_integer(unsigned(p_rc2_reg))) &
                       " | FLAG_SRC: " & integer'image(to_integer(unsigned(pr_flag2_reg)));
            end if;
        end if;
    end process;
    -- synthesis translate_on

end Behavioral;