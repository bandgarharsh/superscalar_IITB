library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; -- NEW: This is the magic library for clean console printing!

entity instruction_fetch is
    Port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Front-end control
        stall_fetch : in  std_logic;
        sel         : in  std_logic_vector(1 downto 0);
        pc_bran     : in  std_logic_vector(15 downto 0);

        -- Two fetched instructions
        instruct1   : out std_logic_vector(15 downto 0);
        instruct2   : out std_logic_vector(15 downto 0);

        -- PCs associated with the instructions
        pc1_out     : out std_logic_vector(15 downto 0);
        pc2_out     : out std_logic_vector(15 downto 0);

        -- Instruction validity
        valid1      : out std_logic;
        valid2      : out std_logic;

        -- Branch prediction interface
        pred_taken1 : out std_logic;
        pred_target1: out std_logic_vector(15 downto 0);
        pred_taken2 : out std_logic;
        pred_target2: out std_logic_vector(15 downto 0)
    );
end instruction_fetch;

architecture Behavioral of instruction_fetch is

    -- Current PC
    signal pc_current : std_logic_vector(15 downto 0);
    -- Next PC
    signal pc_next    : std_logic_vector(15 downto 0);
    -- Sequential next PC (PC + 4)
    signal pc_seq     : std_logic_vector(15 downto 0);
    -- Instructions from memory
    signal instr1_mem : std_logic_vector(15 downto 0);
    signal instr2_mem : std_logic_vector(15 downto 0);

begin

    ------------------------------------------------------------------
    -- PC REGISTER
    ------------------------------------------------------------------
    u_pc_reg : entity work.pc_reg
        port map (
            clk    => clk,
            rst    => rst,
            pc_in  => pc_next,
            pc_out => pc_current
        );

    ------------------------------------------------------------------
    -- SEQUENTIAL PC
    ------------------------------------------------------------------
    u_pc_adder : entity work.pc_adder
        port map (
            pc     => pc_current,
            pc_out => pc_seq
        );

    ------------------------------------------------------------------
    -- INSTRUCTION MEMORY
    ------------------------------------------------------------------
    u_instruction_memory : entity work.instru_mem
        port map (
            addr      => pc_current,
            instruct1 => instr1_mem,
            instruct2 => instr2_mem
        );

    ------------------------------------------------------------------
    -- NEXT-PC SELECTION
    ------------------------------------------------------------------
    process(sel, pc_seq, pc_bran, pc_current, stall_fetch)
    begin
        if sel = "01" then
            -- Branch / recovery redirect (Highest Priority)
            pc_next <= pc_bran;
        elsif stall_fetch = '1' then
            -- Keep fetching from current PC
            pc_next <= pc_current;
        else
            case sel is
                when "00" =>
                    pc_next <= pc_seq;
                when others =>
                    pc_next <= pc_current;
            end case;
        end if;
    end process;

    ------------------------------------------------------------------
    -- OUTPUTS
    ------------------------------------------------------------------
    pc1_out   <= pc_current;
    pc2_out   <= std_logic_vector(unsigned(pc_current) + 2);
    instruct1 <= instr1_mem;
    instruct2 <= instr2_mem;
    valid1 <= not rst;
    valid2 <= not rst;

    pred_taken1  <= '0';
    pred_target1 <= (others => '0');
    pred_taken2  <= '0';
    pred_target2 <= (others => '0');

    ------------------------------------------------------------------
    -- PROFESSIONAL X-RAY (Zero Vivado Spam)
    ------------------------------------------------------------------
    process(clk)
        variable l : line; -- TextIO line buffer
    begin
        if rising_edge(clk) then
            if rst = '0' then
                
                -- We build the string in the buffer 'l', then print it all at once!
                if sel = "01" then
                    write(l, string'("[IF STAGE] FLUSHED  -> Redirecting PC to: "));
                    write(l, integer'image(to_integer(unsigned(pc_bran))));
                    writeline(output, l);
                    
                elsif stall_fetch = '1' then
                    write(l, string'("[IF STAGE] STALLED  -> Holding PC at: "));
                    write(l, integer'image(to_integer(unsigned(pc_current))));
                    writeline(output, l);
                    
                else
                    write(l, string'("[IF STAGE] FETCHING -> PC1: "));
                    write(l, integer'image(to_integer(unsigned(pc_current))));
                    write(l, string'(" (Inst: "));
                    write(l, integer'image(to_integer(unsigned(instr1_mem))));
                    write(l, string'(") | PC2: "));
                    write(l, integer'image(to_integer(unsigned(pc_current) + 2)));
                    write(l, string'(" (Inst: "));
                    write(l, integer'image(to_integer(unsigned(instr2_mem))));
                    write(l, string'(")"));
                    writeline(output, l);
                end if;
                
            end if;
        end if;
    end process;

end Behavioral;