library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity micro_op_cracker is
  Port (
    clk : in std_logic;
    rst : in std_logic;
    
    valid_in : in std_logic;
    instr_in : in std_logic_vector(15 downto 0);
    pc_in : in std_logic_vector(15 downto 0);
    
    stall_fetch : out std_logic;
    cracker_done : out std_logic;
    
    uop1_valid : out std_logic;
    uop1_opcode : out std_logic_vector(3 downto 0);
    uop1_base_reg : out std_logic_vector(2 downto 0);
    uop1_target_reg : out std_logic_vector(2 downto 0);
    uop1_offset : out std_logic_vector(15 downto 0);
    uop1_pc : out std_logic_vector(15 downto 0);
    uop1_cz : out std_logic_vector(1 downto 0);
    
    uop2_valid : out std_logic;
    uop2_opcode : out std_logic_vector(3 downto 0);
    uop2_base_reg : out std_logic_vector(2 downto 0);
    uop2_target_reg : out std_logic_vector(2 downto 0);
    uop2_offset : out std_logic_vector(15 downto 0);
    uop2_pc : out std_logic_vector(15 downto 0);
    uop2_cz : out std_logic_vector(1 downto 0)
);
end micro_op_cracker;

architecture Behavioral of micro_op_cracker is

    constant OP_LW: std_logic_vector(3 downto 0) := "0100";
    constant OP_SW: std_logic_vector(3 downto 0) := "0101";
    constant OP_LM: std_logic_vector(3 downto 0) := "0110";
    constant OP_SM: std_logic_vector(3 downto 0) := "0111";
    
    signal is_cracking : std_logic := '0';
    signal stored_base : std_logic_vector(2 downto 0);
    signal stored_mask : std_logic_vector(7 downto 0);
    signal stored_opcode : std_logic_vector(3 downto 0);
    signal stored_pc : std_logic_vector(15 downto 0);
    signal current_offset : unsigned(15 downto 0);
    
    -- State control
    signal handle_flags : std_logic := '0';
    signal cracker_done_s : std_logic := '0';
    
begin

    stall_fetch <= is_cracking;
    cracker_done <= cracker_done_s;
    
    process(clk, rst)
        variable found_count : integer range 0 to 2;
        variable temp_mask : std_logic_vector(7 downto 0);
        variable temp_flags : std_logic;
        variable reg_idx : integer range 0 to 7;
        variable incoming_op : std_logic_vector(3 downto 0);

    begin
        if rst = '1' then
            is_cracking <= '0';
            handle_flags <= '0';
            current_offset <= (others => '0');
            cracker_done_s <= '0';
            uop1_valid <= '0';
            uop2_valid <= '0';
            uop1_opcode <= (others => '0');
            uop1_base_reg <= (others => '0');
            uop1_target_reg <= (others => '0');
            uop1_offset <= (others => '0');
            uop1_pc <= (others => '0');
            uop1_cz <= "00";
            uop2_opcode <= (others => '0');
            uop2_base_reg <= (others => '0');
            uop2_target_reg <= (others => '0');
            uop2_offset <= (others => '0');
            uop2_pc <= (others => '0');
            uop2_cz <= "00";
            
        elsif rising_edge(clk) then
        
            uop1_valid <= '0';
            uop2_valid <= '0';
            uop1_cz <= "00";
            uop2_cz <= "00";
            cracker_done_s <= '0';
            
            if is_cracking = '1' then
                
                found_count := 0;
                temp_mask := stored_mask;
                temp_flags := handle_flags;
                
                -- Scan the mask for registers
                for i in 0 to 7 loop
                    if temp_mask(i) = '1' then
                        temp_mask(i) := '0';
                        if found_count = 0 then
                            reg_idx := 7-i;
                            uop1_valid <= '1';
                            uop1_opcode <= stored_opcode;
                            uop1_base_reg <= stored_base;
                            uop1_target_reg <= std_logic_vector(to_unsigned(reg_idx, 3));
                            uop1_offset <= std_logic_vector(current_offset);
                            uop1_pc <= stored_pc;
                            uop1_cz <= "00";
                            if temp_mask = "00000000" and temp_flags = '1' then
                                uop1_cz <= "11";
                                temp_flags := '0';
                            else 
                                uop1_cz <= "00";
                            end if;
                                
                            
                            found_count := 1;
                        
                        elsif found_count = 1 then
                            reg_idx := 7-i;
                            uop2_valid <= '1';
                            uop2_opcode <= stored_opcode;
                            uop2_base_reg <= stored_base;
                            uop2_target_reg <= std_logic_vector(to_unsigned(reg_idx, 3));
                            uop2_offset <= std_logic_vector(current_offset + 1);
                            uop2_pc <= stored_pc;
                            uop2_cz <= "00";
                            if temp_mask = "00000000" and temp_flags = '1' then
                                uop2_cz <= "11";
                                temp_flags := '0';
                            else 
                                uop2_cz <= "00";
                            end if;
                            found_count := 2;
                            exit;
                        end if;
                    end if;
                end loop;
                
                if temp_mask = "00000000" and temp_flags = '1' and found_count = 0 then
                    uop1_valid <= '1';
                    uop1_opcode <= stored_opcode;
                    uop1_base_reg <= stored_base;
                    uop1_target_reg <= "000"; 
                    uop1_offset <= std_logic_vector(current_offset);
                    uop1_pc <= stored_pc;
                    uop1_cz <= "11";
                    
                    temp_flags := '0';
                    found_count := 1;
                end if;
                
                stored_mask <= temp_mask;
                handle_flags <= temp_flags;
                current_offset <= current_offset + found_count;
                
                -- Shut off cracker and generate the DONE pulse
                if temp_mask = "00000000" and temp_flags = '0' then
                    is_cracking <= '0';
                    cracker_done_s <= '1';
                end if;
            
            else
                if valid_in = '1' then
                    incoming_op := instr_in(15 downto 12);
                    
                    if (incoming_op = OP_LM or incoming_op = OP_SM) then
                        is_cracking <= '1';
                        stored_base <= instr_in(11 downto 9);
                        stored_mask <= instr_in(7 downto 0);
                        stored_pc <= pc_in;
                        current_offset <= (others => '0');
                        
                        if incoming_op = OP_LM then
                            stored_opcode <= OP_LW;
                        else
                            stored_opcode <= OP_SW;
                        end if;
                        
                        handle_flags <= instr_in(8);
                    end if;
                end if;
            end if;
        end if;
    end process;      
end Behavioral;