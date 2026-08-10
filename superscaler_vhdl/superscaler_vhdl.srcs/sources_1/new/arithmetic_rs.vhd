library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity arithmetic_rs is
    Port (
        clk         : in std_logic;
        rst         : in std_logic;
        flush       : in std_logic;

        -- --- DISPATCH INTERFACE ---
        we1             : in std_logic;
        rs_packet1      : in std_logic_vector(63 downto 0);
        rob_tag1        : in std_logic_vector(4 downto 0);
        d1_vj_valid     : in std_logic; d1_vj_data : in std_logic_vector(15 downto 0);
        d1_vk_valid     : in std_logic; d1_vk_data : in std_logic_vector(15 downto 0);

        we2             : in std_logic;
        rs_packet2      : in std_logic_vector(63 downto 0);
        rob_tag2        : in std_logic_vector(4 downto 0);
        d2_vj_valid     : in std_logic; d2_vj_data : in std_logic_vector(15 downto 0);
        d2_vk_valid     : in std_logic; d2_vk_data : in std_logic_vector(15 downto 0);

        -- --- COMMON DATA BUS INTERFACE ---
        cdb1_valid      : in std_logic; cdb1_tag : in std_logic_vector(4 downto 0); cdb1_data : in std_logic_vector(15 downto 0);
        cdb2_valid      : in std_logic; cdb2_tag : in std_logic_vector(4 downto 0); cdb2_data : in std_logic_vector(15 downto 0);

        -- --- ISSUE INTERFACE ---
        issue_ready        : in std_logic; -- NEW: Handshake from ALU
        issue_valid        : out std_logic;
        issue_opcode       : out std_logic_vector(3 downto 0);
        issue_comp         : out std_logic;
        issue_cz           : out std_logic_vector(1 downto 0);
        issue_imm          : out std_logic_vector(15 downto 0);
        issue_vj           : out std_logic_vector(15 downto 0);
        issue_vk           : out std_logic_vector(15 downto 0);
        issue_dest_pr      : out std_logic_vector(4 downto 0);
        issue_dest_flag_pr : out std_logic_vector(4 downto 0);
        issue_rob_tag      : out std_logic_vector(4 downto 0);

        free_slots         : out unsigned(2 downto 0) -- CHANGED: Precise capacity out
    );
end arithmetic_rs;

architecture Behavioral of arithmetic_rs is
    type bit_array    is array (0 to 3) of std_logic;
    type opcode_array is array (0 to 3) of std_logic_vector(3 downto 0);
    type cz_array     is array (0 to 3) of std_logic_vector(1 downto 0);
    type tag_array    is array (0 to 3) of std_logic_vector(4 downto 0);
    type data_array   is array (0 to 3) of std_logic_vector(15 downto 0);
    type age_array    is array (0 to 3) of unsigned(3 downto 0);
    
    signal busy      : bit_array := (others => '0');
    signal opcode    : opcode_array := (others => (others => '0'));
    signal comp      : bit_array := (others => '0');
    signal cz        : cz_array := (others => (others => '0'));
    signal imm       : data_array := (others => (others => '0'));
    signal dest_pr   : tag_array := (others => (others => '0'));
    signal dest_flag : tag_array := (others => (others => '0'));
    signal rob_tag   : tag_array := (others => (others => '0'));
    signal age       : age_array := (others => (others => '0'));
    
    signal vj_valid  : bit_array := (others => '0'); signal vj : data_array := (others => (others => '0')); signal qj : tag_array := (others => (others => '0'));
    signal vk_valid  : bit_array := (others => '0'); signal vk : data_array := (others => (others => '0')); signal qk : tag_array := (others => (others => '0'));

    signal ready       : bit_array;
    signal int_issue_v : std_logic;
    signal int_issue_i : integer range 0 to 3;
    
    signal count       : integer range 0 to 4 := 0; -- NEW: Active entry counter
    
begin

    free_slots <= to_unsigned(4 - count, 3);
    
    -- Instruction Readiness: Requires Vj and Vk to be valid. (No flags needed for basic arithmetic)
    ready(0) <= busy(0) and vj_valid(0) and vk_valid(0);
    ready(1) <= busy(1) and vj_valid(1) and vk_valid(1);
    ready(2) <= busy(2) and vj_valid(2) and vk_valid(2);
    ready(3) <= busy(3) and vj_valid(3) and vk_valid(3);
    
    -- Priority Encoder (Strict Age-Based Issue)
    process(ready, age, opcode, comp, cz, imm, vj, vk, dest_pr, dest_flag, rob_tag)
        variable max_age : unsigned(3 downto 0);
        variable best_i  : integer range 0 to 3;
        variable found   : boolean;
    begin
        int_issue_v <= '0'; int_issue_i <= 0; issue_valid <= '0';
        issue_opcode <= (others => '0'); issue_comp <= '0'; issue_cz <= (others => '0');
        issue_imm <= (others => '0'); issue_vj <= (others => '0'); issue_vk <= (others => '0');
        issue_dest_pr <= (others => '0'); issue_dest_flag_pr <= (others => '0'); issue_rob_tag <= (others => '0');
        
        max_age := "0000"; best_i := 0; found := false;
        for i in 0 to 3 loop
            if ready(i) = '1' then
                if not found or (age(i) > max_age) then
                    max_age := age(i); best_i := i; found := true;
                end if;
            end if;
        end loop;

        if found then
            int_issue_v <= '1'; int_issue_i <= best_i; issue_valid <= '1';
            issue_opcode <= opcode(best_i); issue_comp <= comp(best_i); issue_cz <= cz(best_i); issue_imm <= imm(best_i);
            issue_vj <= vj(best_i); issue_vk <= vk(best_i); 
            issue_dest_pr <= dest_pr(best_i); issue_dest_flag_pr <= dest_flag(best_i); issue_rob_tag <= rob_tag(best_i);
        end if;
     end process;
     
     process(clk, rst, flush)
        variable alloc1, alloc2 : integer range 0 to 4;
        variable actually_issued: std_logic;
        variable slot_free      : boolean;
        variable pushes, pops   : integer range 0 to 2;
     begin
        if (rst = '1' or flush = '1') then
            busy <= (others => '0');
            age  <= (others => (others => '0'));
            count <= 0;
        elsif rising_edge(clk) then 
            
            pops := 0; pushes := 0;
            
            -- Confirm the ALU actually accepted the issued instruction
            actually_issued := int_issue_v and issue_ready;
            
            -- Increment Age for all busy slots
            for i in 0 to 3 loop
                if busy(i) = '1' and age(i) /= "1111" then age(i) <= age(i) + 1; end if;
            end loop;

            if actually_issued = '1' then 
                busy(int_issue_i) <= '0'; 
                pops := 1;
            end if;
            
            -- SELF-ALLOCATION: Exclude alloc1 from alloc2, account for same-cycle pop
            alloc1 := 4; alloc2 := 4;
            for i in 0 to 3 loop
                -- A slot is free if it's currently 0, OR if it's officially vacating this cycle
                slot_free := (busy(i) = '0') or (busy(i) = '1' and actually_issued = '1' and int_issue_i = i);
                
                if slot_free then
                    if we1 = '1' and alloc1 = 4 then 
                        alloc1 := i;
                    elsif we2 = '1' and alloc2 = 4 and i /= alloc1 then 
                        alloc2 := i;
                    end if;
                end if;
            end loop;
            
            -- DISPATCH & SAME-CYCLE SNOOPING (Slot 1)
            if alloc1 /= 4 then
                pushes := pushes + 1;
                busy(alloc1)      <= '1';
                age(alloc1)       <= "0000";
                opcode(alloc1)    <= rs_packet1(63 downto 60);
                dest_pr(alloc1)   <= rs_packet1(59 downto 55); dest_flag(alloc1) <= rs_packet1(54 downto 50);
                qj(alloc1)        <= rs_packet1(49 downto 45); qk(alloc1)        <= rs_packet1(44 downto 40);
                imm(alloc1)       <= rs_packet1(34 downto 19); cz(alloc1)        <= rs_packet1(18 downto 17);
                comp(alloc1)      <= rs_packet1(16); rob_tag(alloc1)   <= rob_tag1;
                
                -- Same-cycle CDB Wakeup for Vj
                if d1_vj_valid = '0' and cdb1_valid = '1' and rs_packet1(49 downto 45) = cdb1_tag then vj(alloc1) <= cdb1_data; vj_valid(alloc1) <= '1';
                elsif d1_vj_valid = '0' and cdb2_valid = '1' and rs_packet1(49 downto 45) = cdb2_tag then vj(alloc1) <= cdb2_data; vj_valid(alloc1) <= '1';
                else vj_valid(alloc1) <= d1_vj_valid; vj(alloc1) <= d1_vj_data; end if;

                -- Same-cycle CDB Wakeup for Vk
                if d1_vk_valid = '0' and cdb1_valid = '1' and rs_packet1(44 downto 40) = cdb1_tag then vk(alloc1) <= cdb1_data; vk_valid(alloc1) <= '1';
                elsif d1_vk_valid = '0' and cdb2_valid = '1' and rs_packet1(44 downto 40) = cdb2_tag then vk(alloc1) <= cdb2_data; vk_valid(alloc1) <= '1';
                else vk_valid(alloc1) <= d1_vk_valid; vk(alloc1) <= d1_vk_data; end if;
            end if;
            
            -- DISPATCH & SAME-CYCLE SNOOPING (Slot 2)
            if alloc2 /= 4 then
                pushes := pushes + 1;
                busy(alloc2)      <= '1';
                age(alloc2)       <= "0000";
                opcode(alloc2)    <= rs_packet2(63 downto 60);
                dest_pr(alloc2)   <= rs_packet2(59 downto 55); dest_flag(alloc2) <= rs_packet2(54 downto 50);
                qj(alloc2)        <= rs_packet2(49 downto 45); qk(alloc2)        <= rs_packet2(44 downto 40);
                imm(alloc2)       <= rs_packet2(34 downto 19); cz(alloc2)        <= rs_packet2(18 downto 17);
                comp(alloc2)      <= rs_packet2(16); rob_tag(alloc2)   <= rob_tag2;
                
                if d2_vj_valid = '0' and cdb1_valid = '1' and rs_packet2(49 downto 45) = cdb1_tag then vj(alloc2) <= cdb1_data; vj_valid(alloc2) <= '1';
                elsif d2_vj_valid = '0' and cdb2_valid = '1' and rs_packet2(49 downto 45) = cdb2_tag then vj(alloc2) <= cdb2_data; vj_valid(alloc2) <= '1';
                else vj_valid(alloc2) <= d2_vj_valid; vj(alloc2) <= d2_vj_data; end if;

                if d2_vk_valid = '0' and cdb1_valid = '1' and rs_packet2(44 downto 40) = cdb1_tag then vk(alloc2) <= cdb1_data; vk_valid(alloc2) <= '1';
                elsif d2_vk_valid = '0' and cdb2_valid = '1' and rs_packet2(44 downto 40) = cdb2_tag then vk(alloc2) <= cdb2_data; vk_valid(alloc2) <= '1';
                else vk_valid(alloc2) <= d2_vk_valid; vk(alloc2) <= d2_vk_data; end if;
            end if;
            
            count <= count + pushes - pops;
            
            -- STANDARD CDB SNOOPING (For instructions already waiting in the queue)
            for i in 0 to 3 loop
                if (busy(i) = '1' and (alloc1 /= i) and (alloc2 /= i)) then
                    if (vj_valid(i) = '0') then
                        if (cdb1_valid = '1' and qj(i) = cdb1_tag) then vj(i) <= cdb1_data; vj_valid(i) <= '1';
                        elsif (cdb2_valid = '1' and qj(i) = cdb2_tag) then vj(i) <= cdb2_data; vj_valid(i) <= '1'; end if;
                    end if;
                    if (vk_valid(i) = '0') then
                        if (cdb1_valid = '1' and qk(i) = cdb1_tag) then vk(i) <= cdb1_data; vk_valid(i) <= '1';
                        elsif (cdb2_valid = '1' and qk(i) = cdb2_tag) then vk(i) <= cdb2_data; vk_valid(i) <= '1'; end if;
                    end if;
                end if;
            end loop;
        end if; 
    end process;
end Behavioral;