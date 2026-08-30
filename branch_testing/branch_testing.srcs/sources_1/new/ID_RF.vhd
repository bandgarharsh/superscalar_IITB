library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.iitb_risc_pkg.ALL;

entity ID_RF is
Port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    flush         : in  std_logic;
    stall_rename  : in  std_logic;

    -- =========================================================
    -- SLOT 1 INPUTS
    -- =========================================================
    op1_valid     : in std_logic;
    pc1_in        : in std_logic_vector(15 downto 0);
    op1           : in std_logic_vector(3 downto 0);
    imm1          : in std_logic_vector(15 downto 0);
    comp_bit1     : in std_logic;
    cz_bits1      : in std_logic_vector(1 downto 0);

    src1_reg1     : in std_logic_vector(2 downto 0);
    src2_reg1     : in std_logic_vector(2 downto 0);
    dest_reg1     : in std_logic_vector(2 downto 0);

    -- Control flags
    reads_rs1_1   : in std_logic;
    reads_rs2_1   : in std_logic;
    we_gpr1       : in std_logic;
    dest_is_r0_1  : in std_logic;
    we_flag1      : in std_logic;

    -- Routing flags
    is_alu1       : in std_logic;
    is_lsu1       : in std_logic;
    is_branch1    : in std_logic;
    is_multimem1  : in std_logic;
    is_store1     : in std_logic;
    illegal_op1   : in std_logic;

    -- predict
    in_pred_taken1      : in std_logic;
    in_pred_target1     : in std_logic_vector(15 downto 0);
    
    -- =========================================================
    -- SLOT 2 INPUTS
    -- =========================================================
    op2_valid     : in std_logic;
    pc2_in        : in std_logic_vector(15 downto 0);
    op2           : in std_logic_vector(3 downto 0);
    imm2          : in std_logic_vector(15 downto 0);
    comp_bit2     : in std_logic;
    cz_bits2      : in std_logic_vector(1 downto 0);

    src1_reg2     : in std_logic_vector(2 downto 0);
    src2_reg2     : in std_logic_vector(2 downto 0);
    dest_reg2     : in std_logic_vector(2 downto 0);

    -- Control flags
    reads_rs1_2   : in std_logic;
    reads_rs2_2   : in std_logic;
    we_gpr2       : in std_logic;
    dest_is_r0_2  : in std_logic;
    we_flag2      : in std_logic;

    -- Routing flags
    is_alu2       : in std_logic;
    is_lsu2       : in std_logic;
    is_branch2    : in std_logic;
    is_multimem2  : in std_logic;
    is_store2     : in std_logic;
    illegal_op2   : in std_logic;

    -- predict
    in_pred_taken2      : in std_logic;    
    in_pred_target2     : in std_logic_vector(15 downto 0);
    -- =========================================================
    -- SLOT 1 OUTPUTS
    -- =========================================================
    op1_valid_out     : out std_logic;
    pc1_out           : out std_logic_vector(15 downto 0);
    op1_out           : out std_logic_vector(3 downto 0);
    imm1_out          : out std_logic_vector(15 downto 0);
    comp_bit1_out     : out std_logic;
    cz_bits1_out      : out std_logic_vector(1 downto 0);

    src1_reg1_out     : out std_logic_vector(2 downto 0);
    src2_reg1_out     : out std_logic_vector(2 downto 0);
    dest_reg1_out     : out std_logic_vector(2 downto 0);

    -- Control flags
    reads_rs1_1_out  : out std_logic;
    reads_rs2_1_out  : out std_logic;
    we_gpr1_out      : out std_logic;
    dest_is_r0_1_out : out std_logic;
    we_flag1_out     : out std_logic;

    -- Routing flags
    is_alu1_out       : out std_logic;
    is_lsu1_out       : out std_logic;
    is_branch1_out    : out std_logic;
    is_multimem1_out  : out std_logic;
    is_store1_out     : out std_logic;
    illegal_op1_out   : out std_logic;

    out_pred_taken1      : out std_logic;
    out_pred_target1     : out std_logic_vector(15 downto 0);
    -- =========================================================
    -- SLOT 2 OUTPUTS
    -- =========================================================
    op2_valid_out     : out std_logic;
    pc2_out           : out std_logic_vector(15 downto 0);
    op2_out           : out std_logic_vector(3 downto 0);
    imm2_out          : out std_logic_vector(15 downto 0);
    comp_bit2_out     : out std_logic;
    cz_bits2_out      : out std_logic_vector(1 downto 0);

    src1_reg2_out     : out std_logic_vector(2 downto 0);
    src2_reg2_out     : out std_logic_vector(2 downto 0);
    dest_reg2_out     : out std_logic_vector(2 downto 0);

    -- Control flags
    reads_rs1_2_out  : out std_logic;
    reads_rs2_2_out  : out std_logic;
    we_gpr2_out      : out std_logic;
    dest_is_r0_2_out : out std_logic;
    we_flag2_out     : out std_logic;

    -- Routing flags
    is_alu2_out       : out std_logic;
    is_lsu2_out       : out std_logic;
    is_branch2_out    : out std_logic;
    is_multimem2_out  : out std_logic;
    is_store2_out     : out std_logic;
    illegal_op2_out   : out std_logic;
    
    out_pred_taken2      : out std_logic;
    out_pred_target2     : out std_logic_vector(15 downto 0)
);

end ID_RF;


architecture Behavioral of ID_RF is

    -- =========================================================
    -- SLOT 1 REGISTERED DATA
    -- =========================================================
    signal valid1_reg       : std_logic;
    signal pc1_reg          : std_logic_vector(15 downto 0);
    signal op1_reg          : std_logic_vector(3 downto 0);
    signal imm1_reg         : std_logic_vector(15 downto 0);
    signal comp_bit1_reg    : std_logic;
    signal cz_bits1_reg     : std_logic_vector(1 downto 0);

    signal src1_reg1_reg    : std_logic_vector(2 downto 0);
    signal src2_reg1_reg    : std_logic_vector(2 downto 0);
    signal dest_reg1_reg    : std_logic_vector(2 downto 0);

    signal reads_rs1_1_reg  : std_logic;
    signal reads_rs2_1_reg  : std_logic;
    signal we_gpr1_reg      : std_logic;
    signal dest_is_r0_1_reg : std_logic;
    signal we_flag1_reg     : std_logic;

    signal is_alu1_reg      : std_logic;
    signal is_lsu1_reg      : std_logic;
    signal is_branch1_reg   : std_logic;
    signal is_multimem1_reg : std_logic;
    signal is_store1_reg    : std_logic;
    signal illegal_op1_reg  : std_logic;


    -- =========================================================
    -- SLOT 2 REGISTERED DATA
    -- =========================================================
    signal valid2_reg       : std_logic;
    signal pc2_reg          : std_logic_vector(15 downto 0);
    signal op2_reg          : std_logic_vector(3 downto 0);
    signal imm2_reg         : std_logic_vector(15 downto 0);
    signal comp_bit2_reg    : std_logic;
    signal cz_bits2_reg     : std_logic_vector(1 downto 0);

    signal src1_reg2_reg    : std_logic_vector(2 downto 0);
    signal src2_reg2_reg    : std_logic_vector(2 downto 0);
    signal dest_reg2_reg    : std_logic_vector(2 downto 0);

    signal reads_rs1_2_reg  : std_logic;
    signal reads_rs2_2_reg  : std_logic;
    signal we_gpr2_reg      : std_logic;
    signal dest_is_r0_2_reg : std_logic;
    signal we_flag2_reg     : std_logic;

    signal is_alu2_reg      : std_logic;
    signal is_lsu2_reg      : std_logic;
    signal is_branch2_reg   : std_logic;
    signal is_multimem2_reg : std_logic;
    signal is_store2_reg    : std_logic;
    signal illegal_op2_reg  : std_logic;

begin


    -- =========================================================
    -- ID/RF PIPELINE REGISTER
    -- =========================================================
    process(clk, rst)
    begin

        if rst = '1' then

            -- -------------------------------------------------
            -- SLOT 1 RESET
            -- -------------------------------------------------
            valid1_reg       <= '0';
            pc1_reg          <= (others => '0');
            op1_reg          <= (others => '0');
            imm1_reg         <= (others => '0');
            comp_bit1_reg    <= '0';
            cz_bits1_reg     <= (others => '0');

            src1_reg1_reg    <= (others => '0');
            src2_reg1_reg    <= (others => '0');
            dest_reg1_reg    <= (others => '0');

            reads_rs1_1_reg  <= '0';
            reads_rs2_1_reg  <= '0';
            we_gpr1_reg      <= '0';
            dest_is_r0_1_reg <= '0';
            we_flag1_reg     <= '0';

            is_alu1_reg      <= '0';
            is_lsu1_reg      <= '0';
            is_branch1_reg   <= '0';
            is_multimem1_reg <= '0';
            is_store1_reg    <= '0';
            illegal_op1_reg  <= '0';
            
            out_pred_taken1  <= '0';    
            out_pred_target1 <= (others => '0');   

            -- -------------------------------------------------
            -- SLOT 2 RESET
            -- -------------------------------------------------
            valid2_reg       <= '0';
            pc2_reg          <= (others => '0');
            op2_reg          <= (others => '0');
            imm2_reg         <= (others => '0');
            comp_bit2_reg    <= '0';
            cz_bits2_reg     <= (others => '0');

            src1_reg2_reg    <= (others => '0');
            src2_reg2_reg    <= (others => '0');
            dest_reg2_reg    <= (others => '0');

            reads_rs1_2_reg  <= '0';
            reads_rs2_2_reg  <= '0';
            we_gpr2_reg      <= '0';
            dest_is_r0_2_reg <= '0';
            we_flag2_reg     <= '0';

            is_alu2_reg      <= '0';
            is_lsu2_reg      <= '0';
            is_branch2_reg   <= '0';
            is_multimem2_reg <= '0';
            is_store2_reg    <= '0';
            illegal_op2_reg  <= '0';
            
            out_pred_taken2  <= '0';    
            out_pred_target2 <= (others => '0');  

        elsif rising_edge(clk) then

            -- =================================================
            -- FLUSH
            -- =================================================
            if flush = '1' then

                -- Only validity needs to be cleared.
                -- Other fields are don't-care when valid = 0.
                valid1_reg <= '0';
                valid2_reg <= '0';


            -- =================================================
            -- NORMAL OPERATION
            -- =================================================
            elsif stall_rename = '0' then

                -- -------------------------------------------------
                -- SLOT 1
                -- -------------------------------------------------
                valid1_reg       <= op1_valid;
                pc1_reg          <= pc1_in;
                op1_reg          <= op1;
                imm1_reg         <= imm1;
                comp_bit1_reg    <= comp_bit1;
                cz_bits1_reg     <= cz_bits1;

                src1_reg1_reg    <= src1_reg1;
                src2_reg1_reg    <= src2_reg1;
                dest_reg1_reg    <= dest_reg1;

                reads_rs1_1_reg  <= reads_rs1_1;
                reads_rs2_1_reg  <= reads_rs2_1;
                we_gpr1_reg      <= we_gpr1;
                dest_is_r0_1_reg <= dest_is_r0_1;
                we_flag1_reg     <= we_flag1;

                is_alu1_reg      <= is_alu1;
                is_lsu1_reg      <= is_lsu1;
                is_branch1_reg   <= is_branch1;
                is_multimem1_reg <= is_multimem1;
                is_store1_reg    <= is_store1;
                illegal_op1_reg  <= illegal_op1;

                out_pred_taken1      <= in_pred_taken1;
                out_pred_target1      <= in_pred_target1;
                
                -- -------------------------------------------------
                -- SLOT 2
                -- -------------------------------------------------
                valid2_reg       <= op2_valid;
                pc2_reg          <= pc2_in;
                op2_reg          <= op2;
                imm2_reg         <= imm2;
                comp_bit2_reg    <= comp_bit2;
                cz_bits2_reg     <= cz_bits2;

                src1_reg2_reg    <= src1_reg2;
                src2_reg2_reg    <= src2_reg2;
                dest_reg2_reg    <= dest_reg2;

                reads_rs1_2_reg  <= reads_rs1_2;
                reads_rs2_2_reg  <= reads_rs2_2;
                we_gpr2_reg      <= we_gpr2;
                dest_is_r0_2_reg <= dest_is_r0_2;
                we_flag2_reg     <= we_flag2;

                is_alu2_reg      <= is_alu2;
                is_lsu2_reg      <= is_lsu2;
                is_branch2_reg   <= is_branch2;
                is_multimem2_reg <= is_multimem2;
                is_store2_reg    <= is_store2;
                illegal_op2_reg  <= illegal_op2;
                
                out_pred_taken2      <= in_pred_taken2;
                out_pred_target2      <= in_pred_target2;
                
            end if;

        end if;

    end process;


    -- =========================================================
    -- SLOT 1 OUTPUT ASSIGNMENTS
    -- =========================================================
    op1_valid_out     <= valid1_reg;
    pc1_out           <= pc1_reg;
    op1_out           <= op1_reg;
    imm1_out          <= imm1_reg;
    comp_bit1_out     <= comp_bit1_reg;
    cz_bits1_out      <= cz_bits1_reg;

    src1_reg1_out     <= src1_reg1_reg;
    src2_reg1_out     <= src2_reg1_reg;
    dest_reg1_out     <= dest_reg1_reg;

    reads_rs1_1_out   <= reads_rs1_1_reg;
    reads_rs2_1_out   <= reads_rs2_1_reg;
    we_gpr1_out       <= we_gpr1_reg;
    dest_is_r0_1_out  <= dest_is_r0_1_reg;
    we_flag1_out      <= we_flag1_reg;

    is_alu1_out       <= is_alu1_reg;
    is_lsu1_out       <= is_lsu1_reg;
    is_branch1_out    <= is_branch1_reg;
    is_multimem1_out  <= is_multimem1_reg;
    is_store1_out     <= is_store1_reg;
    illegal_op1_out   <= illegal_op1_reg;


    -- =========================================================
    -- SLOT 2 OUTPUT ASSIGNMENTS
    -- =========================================================
    op2_valid_out     <= valid2_reg;
    pc2_out           <= pc2_reg;
    op2_out           <= op2_reg;
    imm2_out          <= imm2_reg;
    comp_bit2_out     <= comp_bit2_reg;
    cz_bits2_out      <= cz_bits2_reg;

    src1_reg2_out     <= src1_reg2_reg;
    src2_reg2_out     <= src2_reg2_reg;
    dest_reg2_out     <= dest_reg2_reg;

    reads_rs1_2_out   <= reads_rs1_2_reg;
    reads_rs2_2_out   <= reads_rs2_2_reg;
    we_gpr2_out       <= we_gpr2_reg;
    dest_is_r0_2_out  <= dest_is_r0_2_reg;
    we_flag2_out      <= we_flag2_reg;

    is_alu2_out       <= is_alu2_reg;
    is_lsu2_out       <= is_lsu2_reg;
    is_branch2_out    <= is_branch2_reg;
    is_multimem2_out  <= is_multimem2_reg;
    is_store2_out     <= is_store2_reg;
    illegal_op2_out   <= illegal_op2_reg;

end Behavioral;