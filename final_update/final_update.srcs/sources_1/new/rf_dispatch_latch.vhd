library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rf_dispatch_latch is
Port (
    clk   : in std_logic;
    rst   : in std_logic;
    stall : in std_logic;
    flush : in std_logic;

    -- ============================================================
    -- INPUTS FROM RR / RENAME STAGE
    -- ============================================================

    -- =========================
    -- SLOT 1
    -- =========================
    in_valid1        : in std_logic;
    in_pc1           : in std_logic_vector(15 downto 0);
    in_op1           : in std_logic_vector(3 downto 0);
    in_imm1          : in std_logic_vector(15 downto 0);
    in_comp_bit1     : in std_logic;
    in_cz_bits1      : in std_logic_vector(1 downto 0);

    in_reads_rs1_1   : in std_logic;
    in_reads_rs2_1   : in std_logic;
    in_dest_is_r0_1  : in std_logic;
    in_we_gpr1       : in std_logic;
    in_we_flag1      : in std_logic;

    in_is_alu1       : in std_logic;
    in_is_lsu1       : in std_logic;
    in_is_branch1    : in std_logic;
    in_is_multimem1  : in std_logic;
    in_is_store1     : in std_logic;
    in_illegal_op1   : in std_logic;

    in_prs1          : in std_logic_vector(4 downto 0);
    in_prt1          : in std_logic_vector(4 downto 0);
    in_prs1_rdy      : in std_logic;
    in_prt1_rdy      : in std_logic;

    in_pr_flag1      : in std_logic_vector(4 downto 0);
    in_pr_flag1_rdy  : in std_logic;

    in_pd1_new       : in std_logic_vector(4 downto 0);
    in_pd1_old       : in std_logic_vector(4 downto 0);

    in_pf1_new       : in std_logic_vector(4 downto 0);
    in_pf1_old       : in std_logic_vector(4 downto 0);

    in_rob_id1       : in std_logic_vector(3 downto 0);
    
    in_arch_dest1    : in std_logic_vector(2 downto 0);
    -- prediction branch
    in_pred_taken1      : in std_logic;
    in_pred_target1     : in std_logic_vector(15 downto 0);

    -- =========================
    -- SLOT 2
    -- =========================
    in_valid2        : in std_logic;
    in_pc2           : in std_logic_vector(15 downto 0);
    in_op2           : in std_logic_vector(3 downto 0);
    in_imm2          : in std_logic_vector(15 downto 0);
    in_comp_bit2     : in std_logic;
    in_cz_bits2      : in std_logic_vector(1 downto 0);

    in_reads_rs1_2   : in std_logic;
    in_reads_rs2_2   : in std_logic;
    in_dest_is_r0_2  : in std_logic;
    in_we_gpr2       : in std_logic;
    in_we_flag2      : in std_logic;

    in_is_alu2       : in std_logic;
    in_is_lsu2       : in std_logic;
    in_is_branch2    : in std_logic;
    in_is_multimem2  : in std_logic;
    in_is_store2     : in std_logic;
    in_illegal_op2   : in std_logic;

    in_prs2          : in std_logic_vector(4 downto 0);
    in_prt2          : in std_logic_vector(4 downto 0);
    in_prs2_rdy      : in std_logic;
    in_prt2_rdy      : in std_logic;

    in_pr_flag2      : in std_logic_vector(4 downto 0);
    in_pr_flag2_rdy  : in std_logic;

    in_pd2_new       : in std_logic_vector(4 downto 0);
    in_pd2_old       : in std_logic_vector(4 downto 0);

    in_pf2_new       : in std_logic_vector(4 downto 0);
    in_pf2_old       : in std_logic_vector(4 downto 0);

    in_rob_id2       : in std_logic_vector(3 downto 0);
    
    in_arch_dest2    : in std_logic_vector(2 downto 0);
    -- prediction branch 
    in_pred_taken2      : in std_logic;
    in_pred_target2     : in std_logic_vector(15 downto 0);
    -- ============================================================
    -- OUTPUTS TO DISPATCH / RS
    -- ============================================================

    -- =========================
    -- SLOT 1
    -- =========================
    out_valid1        : out std_logic;
    out_pc1           : out std_logic_vector(15 downto 0);
    out_op1           : out std_logic_vector(3 downto 0);
    out_imm1          : out std_logic_vector(15 downto 0);
    out_comp_bit1     : out std_logic;
    out_cz_bits1      : out std_logic_vector(1 downto 0);

    out_reads_rs1_1   : out std_logic;
    out_reads_rs2_1   : out std_logic;
    out_dest_is_r0_1  : out std_logic;
    out_we_gpr1       : out std_logic;
    out_we_flag1      : out std_logic;

    out_is_alu1       : out std_logic;
    out_is_lsu1       : out std_logic;
    out_is_branch1    : out std_logic;
    out_is_multimem1  : out std_logic;
    out_is_store1     : out std_logic;
    out_illegal_op1   : out std_logic;

    out_prs1          : out std_logic_vector(4 downto 0);
    out_prt1          : out std_logic_vector(4 downto 0);
    out_prs1_rdy      : out std_logic;
    out_prt1_rdy      : out std_logic;

    out_pr_flag1      : out std_logic_vector(4 downto 0);
    out_pr_flag1_rdy  : out std_logic;

    out_pd1_new       : out std_logic_vector(4 downto 0);
    out_pd1_old       : out std_logic_vector(4 downto 0);

    out_pf1_new       : out std_logic_vector(4 downto 0);
    out_pf1_old       : out std_logic_vector(4 downto 0);

    out_rob_id1       : out std_logic_vector(3 downto 0);
    
    out_arch_dest1    : out std_logic_vector(2 downto 0);
    
    out_pred_taken1      : out std_logic;
    out_pred_target1     : out std_logic_vector(15 downto 0);
    -- =========================
    -- SLOT 2
    -- =========================
    out_valid2        : out std_logic;
    out_pc2           : out std_logic_vector(15 downto 0);
    out_op2           : out std_logic_vector(3 downto 0);
    out_imm2          : out std_logic_vector(15 downto 0);
    out_comp_bit2     : out std_logic;
    out_cz_bits2      : out std_logic_vector(1 downto 0);

    out_reads_rs1_2   : out std_logic;
    out_reads_rs2_2   : out std_logic;
    out_dest_is_r0_2  : out std_logic;
    out_we_gpr2       : out std_logic;
    out_we_flag2      : out std_logic;

    out_is_alu2       : out std_logic;
    out_is_lsu2       : out std_logic;
    out_is_branch2    : out std_logic;
    out_is_multimem2  : out std_logic;
    out_is_store2     : out std_logic;
    out_illegal_op2   : out std_logic;

    out_prs2          : out std_logic_vector(4 downto 0);
    out_prt2          : out std_logic_vector(4 downto 0);
    out_prs2_rdy      : out std_logic;
    out_prt2_rdy      : out std_logic;

    out_pr_flag2      : out std_logic_vector(4 downto 0);
    out_pr_flag2_rdy  : out std_logic;

    out_pd2_new       : out std_logic_vector(4 downto 0);
    out_pd2_old       : out std_logic_vector(4 downto 0);

    out_pf2_new       : out std_logic_vector(4 downto 0);
    out_pf2_old       : out std_logic_vector(4 downto 0);

    out_rob_id2       : out std_logic_vector(3 downto 0);
    
    out_arch_dest2    : out std_logic_vector(2 downto 0);
    
    out_pred_taken2      : out std_logic;
    out_pred_target2     : out std_logic_vector(15 downto 0)
);
end rf_dispatch_latch;


architecture Behavioral of rf_dispatch_latch is

begin

    process(clk, rst)
    begin

        -- ========================================================
        -- RESET
        -- ========================================================
        if rst = '1' then

            out_valid1       <= '0';
            out_valid2       <= '0';

            out_pc1          <= (others => '0');
            out_op1          <= (others => '0');
            out_imm1         <= (others => '0');
            out_comp_bit1    <= '0';
            out_cz_bits1     <= (others => '0');

            out_reads_rs1_1  <= '0';
            out_reads_rs2_1  <= '0';
            out_dest_is_r0_1 <= '0';
            out_we_gpr1      <= '0';
            out_we_flag1     <= '0';

            out_is_alu1      <= '0';
            out_is_lsu1      <= '0';
            out_is_branch1   <= '0';
            out_is_multimem1 <= '0';
            out_is_store1    <= '0';
            out_illegal_op1  <= '0';

            out_prs1         <= (others => '0');
            out_prt1         <= (others => '0');
            out_prs1_rdy     <= '0';
            out_prt1_rdy     <= '0';

            out_pr_flag1     <= (others => '0');
            out_pr_flag1_rdy <= '0';

            out_pd1_new      <= (others => '0');
            out_pd1_old      <= (others => '0');
            out_pf1_new      <= (others => '0');
            out_pf1_old      <= (others => '0');
            out_rob_id1      <= (others => '0');
            
            out_arch_dest1   <= (others => '0');
            
            out_pred_taken1      <= '0';
            out_pred_target1      <= (others => '0');


            out_pc2          <= (others => '0');
            out_op2          <= (others => '0');
            out_imm2         <= (others => '0');
            out_comp_bit2    <= '0';
            out_cz_bits2     <= (others => '0');

            out_reads_rs1_2  <= '0';
            out_reads_rs2_2  <= '0';
            out_dest_is_r0_2 <= '0';
            out_we_gpr2      <= '0';
            out_we_flag2     <= '0';

            out_is_alu2      <= '0';
            out_is_lsu2      <= '0';
            out_is_branch2   <= '0';
            out_is_multimem2 <= '0';
            out_is_store2    <= '0';
            out_illegal_op2  <= '0';

            out_prs2         <= (others => '0');
            out_prt2         <= (others => '0');
            out_prs2_rdy     <= '0';
            out_prt2_rdy     <= '0';

            out_pr_flag2     <= (others => '0');
            out_pr_flag2_rdy <= '0';

            out_pd2_new      <= (others => '0');
            out_pd2_old      <= (others => '0');
            out_pf2_new      <= (others => '0');
            out_pf2_old      <= (others => '0');
            out_rob_id2      <= (others => '0');
            
            out_arch_dest2   <= (others => '0');
            
            out_pred_taken2      <= '0';
            out_pred_target2      <= (others => '0');

        elsif rising_edge(clk) then

            -- ====================================================
            -- FLUSH
            --
            -- Only validity is required to be killed.
            -- The remaining bits may contain stale data, but
            -- downstream logic must ignore them when valid = 0.
            -- ====================================================
            if flush = '1' then

                out_valid1 <= '0';
                out_valid2 <= '0';

            -- ====================================================
            -- STALL
            --
            -- HOLD CURRENT CONTENTS.
            -- No assignments are made.
            -- ====================================================
            elsif stall = '1' then

                null;

            -- ====================================================
            -- NORMAL LOAD
            -- ====================================================
            else

                -- ==================================================
                -- SLOT 1
                -- ==================================================

                out_valid1        <= in_valid1;
                out_pc1           <= in_pc1;
                out_op1           <= in_op1;
                out_imm1          <= in_imm1;
                out_comp_bit1     <= in_comp_bit1;
                out_cz_bits1      <= in_cz_bits1;

                out_reads_rs1_1   <= in_reads_rs1_1;
                out_reads_rs2_1   <= in_reads_rs2_1;
                out_dest_is_r0_1  <= in_dest_is_r0_1;
                out_we_gpr1       <= in_we_gpr1;
                out_we_flag1      <= in_we_flag1;

                out_is_alu1       <= in_is_alu1;
                out_is_lsu1       <= in_is_lsu1;
                out_is_branch1    <= in_is_branch1;
                out_is_multimem1  <= in_is_multimem1;
                out_is_store1     <= in_is_store1;
                out_illegal_op1   <= in_illegal_op1;

                out_prs1          <= in_prs1;
                out_prt1          <= in_prt1;
                out_prs1_rdy      <= in_prs1_rdy;
                out_prt1_rdy      <= in_prt1_rdy;

                out_pr_flag1      <= in_pr_flag1;
                out_pr_flag1_rdy  <= in_pr_flag1_rdy;

                out_pd1_new       <= in_pd1_new;
                out_pd1_old       <= in_pd1_old;

                out_pf1_new       <= in_pf1_new;
                out_pf1_old       <= in_pf1_old;

                out_rob_id1       <= in_rob_id1;
                
                out_arch_dest1   <= in_arch_dest1;
                
                out_pred_taken1      <= in_pred_taken1;
                out_pred_target1      <= in_pred_target1;

                -- ==================================================
                -- SLOT 2
                -- ==================================================

                out_valid2        <= in_valid2;
                out_pc2           <= in_pc2;
                out_op2           <= in_op2;
                out_imm2          <= in_imm2;
                out_comp_bit2     <= in_comp_bit2;
                out_cz_bits2      <= in_cz_bits2;

                out_reads_rs1_2   <= in_reads_rs1_2;
                out_reads_rs2_2   <= in_reads_rs2_2;
                out_dest_is_r0_2  <= in_dest_is_r0_2;
                out_we_gpr2       <= in_we_gpr2;
                out_we_flag2      <= in_we_flag2;

                out_is_alu2       <= in_is_alu2;
                out_is_lsu2       <= in_is_lsu2;
                out_is_branch2    <= in_is_branch2;
                out_is_multimem2  <= in_is_multimem2;
                out_is_store2     <= in_is_store2;
                out_illegal_op2   <= in_illegal_op2;

                out_prs2          <= in_prs2;
                out_prt2          <= in_prt2;
                out_prs2_rdy      <= in_prs2_rdy;
                out_prt2_rdy      <= in_prt2_rdy;

                out_pr_flag2      <= in_pr_flag2;
                out_pr_flag2_rdy  <= in_pr_flag2_rdy;

                out_pd2_new       <= in_pd2_new;
                out_pd2_old       <= in_pd2_old;

                out_pf2_new       <= in_pf2_new;
                out_pf2_old       <= in_pf2_old;

                out_rob_id2       <= in_rob_id2;
                
                out_arch_dest2   <= in_arch_dest2;
                
                out_pred_taken2      <= in_pred_taken2;
                out_pred_target2      <= in_pred_target2;
            end if;
        end if;
    end process;

end Behavioral;