library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cdb_arbiter is
  Port ( 
        clk : in std_logic;
        rst : in std_logic;
        
        alu1_valid   : in std_logic;
        alu1_tag     : in std_logic_vector(4 downto 0);
        alu1_data    : in std_logic_vector(15 downto 0);
        alu1_rob_tag : in std_logic_vector(2 downto 0); -- CHANGED: 3-bit tag
        
        alu2_valid   : in std_logic;
        alu2_tag     : in std_logic_vector(4 downto 0);
        alu2_data    : in std_logic_vector(15 downto 0);
        alu2_rob_tag : in std_logic_vector(2 downto 0); -- CHANGED: 3-bit tag
        
        alu3_valid      : in std_logic;
        alu3_tag        : in std_logic_vector(4 downto 0);
        alu3_data       : in std_logic_vector(15 downto 0);
        alu3_rob_tag    : in std_logic_vector(2 downto 0); -- CHANGED: 3-bit tag
        alu3_mispredict : in std_logic;
        alu3_target_pc  : in std_logic_vector(15 downto 0); 
        
        cdb1_valid      : out std_logic;
        cdb1_tag        : out std_logic_vector(4 downto 0);
        cdb1_data       : out std_logic_vector(15 downto 0);
        cdb1_rob_tag    : out std_logic_vector(2 downto 0); -- CHANGED: 3-bit tag
        cdb1_mispredict : out std_logic;
        cdb1_target_pc  : out std_logic_vector(15 downto 0);
        
        cdb2_valid      : out std_logic;
        cdb2_tag        : out std_logic_vector(4 downto 0);
        cdb2_data       : out std_logic_vector(15 downto 0);
        cdb2_rob_tag    : out std_logic_vector(2 downto 0); -- CHANGED: 3-bit tag
        cdb2_mispredict : out std_logic;
        cdb2_target_pc  : out std_logic_vector(15 downto 0)
    );
end cdb_arbiter;

architecture Behavioral of cdb_arbiter is

    -- Internal Buffer Registers
    signal buf_valid      : std_logic := '0';
    signal buf_tag        : std_logic_vector(4 downto 0) := (others => '0');
    signal buf_data       : std_logic_vector(15 downto 0) := (others => '0');
    signal buf_rob_tag    : std_logic_vector(2 downto 0) := (others => '0');
    signal buf_mispredict : std_logic := '0'; -- 4. NEW: Branch info buffered
    signal buf_target_pc  : std_logic_vector(15 downto 0) := (others => '0'); -- 4. NEW: Branch info buffered
    
begin
    
    process(clk, rst)
        -- 5. FIXED: Variables guarantee instant evaluation, removing timing bugs
        variable cdb_count           : integer range 0 to 2;
        variable next_buf_valid      : std_logic;
        variable next_buf_tag        : std_logic_vector(4 downto 0);
        variable next_buf_data       : std_logic_vector(15 downto 0);
        variable next_buf_rob_tag    : std_logic_vector(2 downto 0);
        variable next_buf_mispredict : std_logic;
        variable next_buf_target_pc  : std_logic_vector(15 downto 0);
        
    begin
        -- 7. FIXED: Reset absolutely all output data and control fields
        if rst = '1' then
            buf_valid      <= '0';
            buf_tag        <= (others => '0');
            buf_data       <= (others => '0');
            buf_rob_tag    <= (others => '0');
            buf_mispredict <= '0';
            buf_target_pc  <= (others => '0');
            
            cdb1_valid      <= '0';
            cdb1_tag        <= (others => '0');
            cdb1_data       <= (others => '0');
            cdb1_rob_tag    <= (others => '0');
            cdb1_mispredict <= '0';
            cdb1_target_pc  <= (others => '0');
            
            cdb2_valid      <= '0';
            cdb2_tag        <= (others => '0');
            cdb2_data       <= (others => '0');
            cdb2_rob_tag    <= (others => '0');
            cdb2_mispredict <= '0';
            cdb2_target_pc  <= (others => '0');
        
        elsif rising_edge(clk) then
            
            -- 1. FIXED: Default all outputs to zero per-clock to prevent stale data
            cdb1_valid      <= '0';
            cdb1_tag        <= (others => '0');
            cdb1_data       <= (others => '0');
            cdb1_rob_tag    <= (others => '0');
            cdb1_mispredict <= '0';
            cdb1_target_pc  <= (others => '0');
            
            cdb2_valid      <= '0';
            cdb2_tag        <= (others => '0');
            cdb2_data       <= (others => '0');
            cdb2_rob_tag    <= (others => '0');
            cdb2_mispredict <= '0';
            cdb2_target_pc  <= (others => '0');
            
            cdb_count := 0;
            
            -- Prepare next buffer state
            next_buf_valid      := '0';
            next_buf_tag        := (others => '0');
            next_buf_data       := (others => '0');
            next_buf_rob_tag    := (others => '0');
            next_buf_mispredict := '0';
            next_buf_target_pc  := (others => '0');
            
            -- ========================================================
            -- ARBITRATION CASCADING (Variables ensure strict priority)
            -- Priorities: Buffer > ALU3 (Branch) > ALU2 (Mem) > ALU1
            -- ========================================================
            
            -- Check 1: Old Buffer
            if buf_valid = '1' then
                cdb1_valid      <= '1';
                cdb1_tag        <= buf_tag;
                cdb1_data       <= buf_data;
                cdb1_rob_tag    <= buf_rob_tag;
                cdb1_mispredict <= buf_mispredict;
                cdb1_target_pc  <= buf_target_pc;
                cdb_count := 1;
            end if;
            
            -- Check 2: ALU 3 (Branch ALU)
            if alu3_valid = '1' then
                if cdb_count = 0 then
                    cdb1_valid      <= '1';
                    cdb1_tag        <= alu3_tag;
                    cdb1_data       <= alu3_data;
                    cdb1_rob_tag    <= alu3_rob_tag;
                    cdb1_mispredict <= alu3_mispredict;
                    cdb1_target_pc  <= alu3_target_pc;
                    cdb_count := 1;
                elsif cdb_count = 1 then
                    cdb2_valid      <= '1';
                    cdb2_tag        <= alu3_tag;
                    cdb2_data       <= alu3_data;
                    cdb2_rob_tag    <= alu3_rob_tag;
                    cdb2_mispredict <= alu3_mispredict;
                    cdb2_target_pc  <= alu3_target_pc;
                    cdb_count := 2;
                else
                    next_buf_valid      := '1';
                    next_buf_tag        := alu3_tag;
                    next_buf_data       := alu3_data;
                    next_buf_rob_tag    := alu3_rob_tag;
                    next_buf_mispredict := alu3_mispredict;
                    next_buf_target_pc  := alu3_target_pc;
                end if;
            end if;
            
            -- Check 3: ALU 2 (Memory ALU)
            if alu2_valid = '1' then
                if cdb_count = 0 then
                    cdb1_valid      <= '1';
                    cdb1_tag        <= alu2_tag;
                    cdb1_data       <= alu2_data;
                    cdb1_rob_tag    <= alu2_rob_tag;
                    cdb_count := 1;
                elsif cdb_count = 1 then
                    cdb2_valid      <= '1';
                    cdb2_tag        <= alu2_tag;
                    cdb2_data       <= alu2_data;
                    cdb2_rob_tag    <= alu2_rob_tag;
                    cdb_count := 2;
                else
                    next_buf_valid      := '1';
                    next_buf_tag        := alu2_tag;
                    next_buf_data       := alu2_data;
                    next_buf_rob_tag    := alu2_rob_tag;
                    next_buf_mispredict := '0';
                    next_buf_target_pc  := (others => '0');
                end if;
            end if;
            
            -- Check 4: ALU 1 (Arithmetic ALU)
            if alu1_valid = '1' then
                if cdb_count = 0 then
                    cdb1_valid      <= '1';
                    cdb1_tag        <= alu1_tag;
                    cdb1_data       <= alu1_data;
                    cdb1_rob_tag    <= alu1_rob_tag;
                    cdb_count := 1;
                elsif cdb_count = 1 then
                    cdb2_valid      <= '1';
                    cdb2_tag        <= alu1_tag;
                    cdb2_data       <= alu1_data;
                    cdb2_rob_tag    <= alu1_rob_tag;
                    cdb_count := 2;
                else
                    next_buf_valid      := '1';
                    next_buf_tag        := alu1_tag;
                    next_buf_data       := alu1_data;
                    next_buf_rob_tag    := alu1_rob_tag;
                    next_buf_mispredict := '0';
                    next_buf_target_pc  := (others => '0');
                end if;
            end if;
            
            -- Latch variables back into signals for the next clock edge
            buf_valid      <= next_buf_valid;
            buf_tag        <= next_buf_tag;
            buf_data       <= next_buf_data;
            buf_rob_tag    <= next_buf_rob_tag;
            buf_mispredict <= next_buf_mispredict;
            buf_target_pc  <= next_buf_target_pc;
            
        end if;
    end process;          
end Behavioral;