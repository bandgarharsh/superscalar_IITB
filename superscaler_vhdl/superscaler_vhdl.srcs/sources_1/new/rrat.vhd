library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RRAT is
    Port (
        clk                 : in  std_logic;
        rst                 : in  std_logic;

        -- =========================================================
        -- 1. INPUTS FROM ROB (2-Way Commit)
        -- =========================================================
        -- Instruction 1 Commit
        commit_valid_1      : in  std_logic;
        commit_arch_dest_1  : in  std_logic_vector(2 downto 0);
        commit_pd_1         : in  std_logic_vector(4 downto 0);
        commit_flag_valid_1 : in  std_logic;
        commit_pf_1         : in  std_logic_vector(4 downto 0);
        
        -- Instruction 2 Commit
        commit_valid_2      : in  std_logic;
        commit_arch_dest_2  : in  std_logic_vector(2 downto 0);
        commit_pd_2         : in  std_logic_vector(4 downto 0);
        commit_flag_valid_2 : in  std_logic;
        commit_pf_2         : in  std_logic_vector(4 downto 0);

        -- =========================================================
        -- 2. NORMAL DEALLOCATION (To Free List)
        -- =========================================================
        -- GPR Free Ports
        free_gpr1_en        : out std_logic;
        free_gpr1_tag       : out std_logic_vector(4 downto 0);
        free_gpr2_en        : out std_logic;
        free_gpr2_tag       : out std_logic_vector(4 downto 0);
        
        -- Flag Free Ports
        free_f1_en          : out std_logic;
        free_f1_tag         : out std_logic_vector(4 downto 0);
        free_f2_en          : out std_logic;
        free_f2_tag         : out std_logic_vector(4 downto 0);

        -- =========================================================
        -- 3. MISPREDICT RECOVERY LOGIC (To Spec RAT & Free List)
        -- =========================================================
        commit_rat_flat     : out std_logic_vector(39 downto 0);
        commit_flag_tag     : out std_logic_vector(4 downto 0);
        commit_gpr_mask     : out std_logic_vector(31 downto 0);
        commit_flag_mask    : out std_logic_vector(31 downto 0)
    );
end RRAT;

architecture Behavioral of RRAT is

    -- The RRAT Memory Array (8 Architectural Registers -> 5-bit Physical Tags)
    type rrat_array_t is array (0 to 7) of std_logic_vector(4 downto 0);
    signal rrat_gpr : rrat_array_t;
    
    -- Single Architectural Flag Register in IITB RISC
    signal rrat_flag : std_logic_vector(4 downto 0);

begin

    -- =========================================================
    -- CONTINUOUS COMBINATIONAL OUTPUTS (Recovery State)
    -- =========================================================
    
    -- 1. Flatten the GPR array into a 40-bit wire for the Spec RAT to copy on flush
    commit_rat_flat <= rrat_gpr(7) & rrat_gpr(6) & rrat_gpr(5) & rrat_gpr(4) & 
                       rrat_gpr(3) & rrat_gpr(2) & rrat_gpr(1) & rrat_gpr(0);
                       
    commit_flag_tag <= rrat_flag;

    -- 2. Generate the 32-bit GPR Safe Mask (For Free List Recovery)
    process(rrat_gpr)
        variable v_mask : std_logic_vector(31 downto 0);
    begin
        v_mask := (others => '0');
        for i in 0 to 7 loop
            v_mask(to_integer(unsigned(rrat_gpr(i)))) := '1';
        end loop;
        commit_gpr_mask <= v_mask;
    end process;

    -- 3. Generate the 32-bit Flag Safe Mask
    process(rrat_flag)
        variable v_mask : std_logic_vector(31 downto 0);
    begin
        v_mask := (others => '0');
        v_mask(to_integer(unsigned(rrat_flag))) := '1';
        commit_flag_mask <= v_mask;
    end process;

    -- =========================================================
    -- SYNCHRONOUS COMMIT LOGIC (Updating the Pointers)
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Initial state: R0=P0, R1=P1 ... R7=P7, Flag=P0
                for i in 0 to 7 loop
                    rrat_gpr(i) <= std_logic_vector(to_unsigned(i, 5));
                end loop;
                rrat_flag <= "00000";
                
                free_gpr1_en <= '0';
                free_gpr2_en <= '0';
                free_f1_en   <= '0';
                free_f2_en   <= '0';
            else
                -- Default strobes to zero
                free_gpr1_en <= '0';
                free_gpr2_en <= '0';
                free_f1_en   <= '0';
                free_f2_en   <= '0';

                -- ----------------------------------------------------
                -- GPR COMMIT LOGIC (With WAW Hazard protection)
                -- ----------------------------------------------------
                if commit_valid_1 = '1' and commit_valid_2 = '1' and (commit_arch_dest_1 = commit_arch_dest_2) then
                    -- HAZARD: Both instructions target the SAME arch register!
                    -- Commit 2 wins. Commit 1's physical tag dies immediately.
                    rrat_gpr(to_integer(unsigned(commit_arch_dest_2))) <= commit_pd_2;
                    
                    -- Free the really old register
                    free_gpr1_en  <= '1';
                    free_gpr1_tag <= rrat_gpr(to_integer(unsigned(commit_arch_dest_1)));
                    
                    -- Instantly free Inst 1's physical register (it got overwritten instantly)
                    free_gpr2_en  <= '1';
                    free_gpr2_tag <= commit_pd_1;
                    
                else
                    -- NORMAL BEHAVIOR
                    if commit_valid_1 = '1' then
                        rrat_gpr(to_integer(unsigned(commit_arch_dest_1))) <= commit_pd_1;
                        free_gpr1_en  <= '1';
                        free_gpr1_tag <= rrat_gpr(to_integer(unsigned(commit_arch_dest_1)));
                    end if;
                    
                    if commit_valid_2 = '1' then
                        rrat_gpr(to_integer(unsigned(commit_arch_dest_2))) <= commit_pd_2;
                        free_gpr2_en  <= '1';
                        free_gpr2_tag <= rrat_gpr(to_integer(unsigned(commit_arch_dest_2)));
                    end if;
                end if;

                -- ----------------------------------------------------
                -- FLAG COMMIT LOGIC 
                -- ----------------------------------------------------
                -- Similar hazard handling. If both instructions write flags, the youngest wins.
                if commit_flag_valid_1 = '1' and commit_flag_valid_2 = '1' then
                    rrat_flag <= commit_pf_2;
                    free_f1_en  <= '1';
                    free_f1_tag <= rrat_flag;     -- Free the really old flag
                    free_f2_en  <= '1';
                    free_f2_tag <= commit_pf_1;   -- Instantly free Inst 1's flag
                    
                else
                    if commit_flag_valid_1 = '1' then
                        rrat_flag <= commit_pf_1;
                        free_f1_en  <= '1';
                        free_f1_tag <= rrat_flag;
                    end if;
                    
                    if commit_flag_valid_2 = '1' then
                        rrat_flag <= commit_pf_2;
                        free_f2_en  <= '1';
                        free_f2_tag <= rrat_flag;
                    end if;
                end if;

            end if;
        end if;
    end process;

end Behavioral;