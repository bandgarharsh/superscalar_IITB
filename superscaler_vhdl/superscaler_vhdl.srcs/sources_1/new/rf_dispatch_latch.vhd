library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rf_dispatch_latch is
    Port (
        clk : in std_logic;
        rst : in std_logic;
        
        -- ==========================================
        -- Pipeline Control (NEW)
        -- ==========================================
        stall : in std_logic; -- From dispatch_stage
        flush : in std_logic; -- From ROB (Branch Mispredict)

        -- ==========================================
        -- Instruction Information
        -- ==========================================
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

        -- ==========================================
        -- Destinations
        -- ==========================================
        dest_tag1_in : in std_logic_vector(4 downto 0);
        dest_tag2_in : in std_logic_vector(4 downto 0);
        
        dest_flag1_in : in std_logic_vector(4 downto 0); -- NEW
        dest_flag2_in : in std_logic_vector(4 downto 0); -- NEW

        we_dest1_in : in std_logic;
        we_dest2_in : in std_logic;

        -- ==========================================
        -- Source Tags
        -- ==========================================
        tag_rs1_in : in std_logic_vector(4 downto 0);
        tag_rt1_in : in std_logic_vector(4 downto 0);
        tag_flag1_in : in std_logic_vector(4 downto 0); -- NEW
        
        tag_rs2_in : in std_logic_vector(4 downto 0);
        tag_rt2_in : in std_logic_vector(4 downto 0);
        tag_flag2_in : in std_logic_vector(4 downto 0); -- NEW

        -- ==========================================
        -- Source Data (From PRF)
        -- ==========================================
        data_rs1_in : in std_logic_vector(15 downto 0);
        data_rt1_in : in std_logic_vector(15 downto 0);
        data_flag1_in : in std_logic_vector(1 downto 0); -- NEW
        
        data_rs2_in : in std_logic_vector(15 downto 0);
        data_rt2_in : in std_logic_vector(15 downto 0);
        data_flag2_in : in std_logic_vector(1 downto 0); -- NEW

        -- ==========================================
        -- Valid bits (From Global Valid Table)
        -- ==========================================
        valid_rs1_in : in std_logic;
        valid_rt1_in : in std_logic;
        valid_flag1_in : in std_logic; -- NEW
        
        valid_rs2_in : in std_logic;
        valid_rt2_in : in std_logic;
        valid_flag2_in : in std_logic; -- NEW

        -- ==========================================
        -- LATCHED OUTPUTS (To Reservation Stations)
        -- ==========================================
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
        dest_flag1_out : out std_logic_vector(4 downto 0); -- NEW
        dest_flag2_out : out std_logic_vector(4 downto 0); -- NEW
        we_dest1_out : out std_logic;
        we_dest2_out : out std_logic;

        -- Formatted Payloads (Data OR Tag)
        payload_rs1 : out std_logic_vector(15 downto 0);
        payload_rt1 : out std_logic_vector(15 downto 0);
        payload_flag1 : out std_logic_vector(4 downto 0); -- Extended to 5 to hold either 2-bit data or 5-bit tag
        
        payload_rs2 : out std_logic_vector(15 downto 0);
        payload_rt2 : out std_logic_vector(15 downto 0);
        payload_flag2 : out std_logic_vector(4 downto 0); -- NEW

        is_tag_rs1 : out std_logic;
        is_tag_rt1 : out std_logic;
        is_tag_flag1 : out std_logic; -- NEW
        
        is_tag_rs2 : out std_logic;
        is_tag_rt2 : out std_logic;
        is_tag_flag2 : out std_logic  -- NEW
    );
end rf_dispatch_latch;

architecture Behavioral of rf_dispatch_latch is

    -- (Internal registers omitted for brevity, mapping directly to ports in process)

begin

    process(clk, rst)
    begin
        if rst = '1' then
            -- Reset all outputs to 0
            pc1_out <= (others=>'0'); pc2_out <= (others=>'0');
            op1_out <= (others=>'0'); op2_out <= (others=>'0');
            imm1_out <= (others=>'0'); imm2_out <= (others=>'0');
            comp_bit1_out <= '0'; comp_bit2_out <= '0';
            cz_bits1_out <= (others=>'0'); cz_bits2_out <= (others=>'0');
            dest_tag1_out <= (others=>'0'); dest_tag2_out <= (others=>'0');
            dest_flag1_out <= (others=>'0'); dest_flag2_out <= (others=>'0');
            we_dest1_out <= '0'; we_dest2_out <= '0';
            payload_rs1 <= (others=>'0'); payload_rt1 <= (others=>'0'); payload_flag1 <= (others=>'0');
            payload_rs2 <= (others=>'0'); payload_rt2 <= (others=>'0'); payload_flag2 <= (others=>'0');
            is_tag_rs1 <= '0'; is_tag_rt1 <= '0'; is_tag_flag1 <= '0';
            is_tag_rs2 <= '0'; is_tag_rt2 <= '0'; is_tag_flag2 <= '0';

        elsif rising_edge(clk) then
        
            if flush = '1' then
                -- Clear latch immediately on branch mispredict
                we_dest1_out <= '0'; 
                we_dest2_out <= '0';
                
            elsif stall = '0' then
                
                -- Only accept new data if the RS queues are NOT stalled
                pc1_out <= pc1_in; pc2_out <= pc2_in;
                op1_out <= op1_in; op2_out <= op2_in;
                imm1_out <= imm1_in; imm2_out <= imm2_in;
                comp_bit1_out <= comp_bit1_in; comp_bit2_out <= comp_bit2_in;
                cz_bits1_out <= cz_bits1_in; cz_bits2_out <= cz_bits2_in;
                dest_tag1_out <= dest_tag1_in; dest_tag2_out <= dest_tag2_in;
                dest_flag1_out <= dest_flag1_in; dest_flag2_out <= dest_flag2_in;
                we_dest1_out <= we_dest1_in; we_dest2_out <= we_dest2_in;

                -- SLOT 1 PAYLOADS
                if valid_rs1_in = '1' then
                    payload_rs1 <= data_rs1_in; is_tag_rs1 <= '0';
                else
                    payload_rs1 <= "00000000000" & tag_rs1_in; is_tag_rs1 <= '1';
                end if;

                if valid_rt1_in = '1' then
                    payload_rt1 <= data_rt1_in; is_tag_rt1 <= '0';
                else
                    payload_rt1 <= "00000000000" & tag_rt1_in; is_tag_rt1 <= '1';
                end if;
                
                if valid_flag1_in = '1' then
                    payload_flag1 <= "000" & data_flag1_in; is_tag_flag1 <= '0';
                else
                    payload_flag1 <= tag_flag1_in; is_tag_flag1 <= '1';
                end if;

                -- SLOT 2 PAYLOADS
                if valid_rs2_in = '1' then
                    payload_rs2 <= data_rs2_in; is_tag_rs2 <= '0';
                else
                    payload_rs2 <= "00000000000" & tag_rs2_in; is_tag_rs2 <= '1';
                end if;

                if valid_rt2_in = '1' then
                    payload_rt2 <= data_rt2_in; is_tag_rt2 <= '0';
                else
                    payload_rt2 <= "00000000000" & tag_rt2_in; is_tag_rt2 <= '1';
                end if;
                
                if valid_flag2_in = '1' then
                    payload_flag2 <= "000" & data_flag2_in; is_tag_flag2 <= '0';
                else
                    payload_flag2 <= tag_flag2_in; is_tag_flag2 <= '1';
                end if;

            end if;
        end if;
    end process;

end Behavioral;