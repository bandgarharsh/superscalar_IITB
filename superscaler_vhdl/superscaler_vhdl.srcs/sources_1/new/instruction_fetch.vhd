library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity instruction_fetch is
    Port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        
        stall_fetch: in  std_logic;  -- ADDED: Stall signal from ID stage
        
        pc_bran    : in  std_logic_vector(15 downto 0);
        sel        : in  std_logic_vector(1 downto 0);

        instruct1  : out std_logic_vector(15 downto 0);
        instruct2  : out std_logic_vector(15 downto 0);
        
        pc1_out         : out std_logic_vector(15 downto 0);
        pc2_out         : out std_logic_vector(15 downto 0);
        
        valid1      : out std_logic;
        valid2      : out std_logic;
        
        pred_taken1 : out std_logic;
        pred_target1 : out std_logic_vector(15 downto 0);
        
        pred_taken2 : out std_logic;
        pred_target2 : out std_logic_vector(15 downto 0)
    );
end instruction_fetch;

architecture Behavioral of instruction_fetch is

    signal pc_in  : std_logic_vector(15 downto 0);
    signal pc_4   : std_logic_vector(15 downto 0);
    signal pc_int : std_logic_vector(15 downto 0);
    
    signal instruct1_s  :  std_logic_vector(15 downto 0);
    signal instruct2_s  :  std_logic_vector(15 downto 0);
begin

    ------------------------------------------------------------------
    -- PC Register
    ------------------------------------------------------------------

    pc_Reg : entity work.pc_reg
        port map(
            clk    => clk,
            rst    => rst,
            pc_in  => pc_in,
            pc_out => pc_int
        );

    ------------------------------------------------------------------
    -- PC Adder
    ------------------------------------------------------------------

    pc_Adder : entity work.pc_adder
        port map(
            pc     => pc_int,
            pc_out => pc_4
        );

    ------------------------------------------------------------------
    -- Instruction Memory
    ------------------------------------------------------------------

    instru_Mem : entity work.instru_mem
        port map(
            addr      => pc_int,
            instruct1 => instruct1_s,
            instruct2 => instruct2_s
        );

    ------------------------------------------------------------------
    -- Next PC Selection
    ------------------------------------------------------------------

    -- ADDED stall_fetch to the sensitivity list
    ------------------------------------------------------------------
    -- PURE COMBINATIONAL LOGIC: Next PC Selection
    ------------------------------------------------------------------
    process(sel, pc_4, pc_bran, pc_int, stall_fetch)
    begin
        -- PRIORITY 1: A Pipeline Flush ALWAYS overrides a Stall!
        if sel = "01" then
            pc_in <= pc_bran(15 downto 0);
            
        -- PRIORITY 2: If stalled, freeze the PC where it is!
        elsif stall_fetch = '1' then
            pc_in <= pc_int;
            
        -- PRIORITY 3: Normal Fetching
        else
            case sel is
                when "00" =>
                    pc_in <= pc_4;
                when others =>
                    pc_in <= pc_int;
            end case;
        end if;
        if rising_edge(clk) then
            if rst = '0' and stall_fetch = '0' then
                report "[X-RAY FETCH] PC: " & integer'image(to_integer(unsigned(pc_int))) & 
                       " | Inst1: " & integer'image(to_integer(unsigned(instruct1_s))) & 
                       " | Inst2: " & integer'image(to_integer(unsigned(instruct2_s)));
            end if;
        end if;
    end process;

    pc1_out <= pc_int;
    pc2_out <= std_logic_vector(unsigned(pc_int) + 2);
    instruct1 <= instruct1_s;
    instruct2 <= instruct2_s;
    valid1 <= '1' when rst = '0' else '0';
    valid2 <= '1' when rst = '0' else '0';
end Behavioral;