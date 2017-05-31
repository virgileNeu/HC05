library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity tb_FIFO is
end tb_FIFO;

architecture test of tb_FIFO is
    constant CLK_PERIOD         : time := 20 ns; -- 50MHz
    signal sim_finished         : boolean := false;
    
    signal test_data            : std_logic_vector(7  downto 0);
    signal reset                : std_logic;
    
    signal clk                  : std_logic;
    signal nReset               : std_logic;
    
    signal write_FIFO           : std_logic;
    signal writedata_FIFO       : std_logic_vector(7 downto 0);
    
    signal read_FIFO            : std_logic;
    signal readdata_FIFO        : std_logic_vector(7 downto 0);
    
    signal use_dw               : std_logic_vector(9 downto 0);
    signal full                 : std_logic;

    -- std_logic_vector to string for printing error messages
    function to_string ( a: std_logic_vector) return string is
        variable b : string (1 to a'length) := (others => NUL);
        variable stri : integer := 1; 
        begin
            for i in a'range loop
                b(stri) := std_logic'image(a((i)))(2);
            stri := stri+1;
            end loop;
        return b;
    end function;
    
    function parity( a: std_logic_vector; b : std_logic) return std_logic is
        variable c : std_logic := b;
        begin
            for i in a'range loop
                c := c xor a(i);
            end loop;
        return c;
    end function;
    
begin
    
reset <= not nReset;

FIFO_in : entity work.FIFO_in_BT
    PORT MAP (
		aclr	 => reset,
		clock	 => clk,
		data	 => writedata_FIFO,
		rdreq	 => read_FIFO,
		wrreq	 => write_FIFO,
		full	 => full,
		q	     => readdata_FIFO,
		usedw	 => use_dw
	);
    
    -- Generate CLK signal
    clk_generation : process
    begin
        if not sim_finished then
            clk <= '1';
            wait for CLK_PERIOD / 2;
            clk <= '0';
            wait for CLK_PERIOD / 2;
        else
            wait;
        end if;
    end process clk_generation;
    
    process(clk)
    begin
    if(rising_edge(clk)) then
            test_data <= readdata_FIFO;
    end if;
    end process;
    
    simulation : process
    procedure async_reset is
        begin
            wait until rising_edge(CLK);
            wait for CLK_PERIOD / 4;
            nReset <= '0';
            
            wait for CLK_PERIOD / 2;
            nReset <= '1';
        end procedure async_reset;
    begin
        
        write_FIFO <= '0';
        read_FIFO <= '0';
        writedata_FIFO <= "00000000";
        
        async_reset;
        
        wait until rising_edge(clk);
        wait for CLK_PERIOD/4;
        
        write_FIFO <= '1';
        writedata_FIFO <= "10101010";
        
        wait until rising_edge(clk);
        wait for CLK_PERIOD/4;
        
        write_FIFO <= '0';
        writedata_FIFO <= "00000000";
        
        
        wait until rising_edge(clk);
        wait for CLK_PERIOD/4;
        
        read_FIFO <= '1';
        
                
        wait until rising_edge(clk);
        wait for CLK_PERIOD/4;
        
        read_FIFO <= '0';
        
        wait for CLK_PERIOD*4;
        sim_finished <= true;
        wait;
    end process simulation;
end;

