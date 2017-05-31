library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity tb_uart_FIFO is
end tb_uart_FIFO;

architecture test of tb_uart_FIFO is
    constant CLK_PERIOD         : time := 20 ns; -- 50MHz
    signal sim_finished         : boolean := false;
    
    signal test_data            : std_logic_vector(7  downto 0);
    signal reset                : std_logic;
    
    signal clk                  : std_logic;
    signal nReset               : std_logic;
            
-- FIFO_in interface
    signal UART_write          : std_logic;
    signal UART_writedata      : std_logic_vector(7  downto 0);
    signal FIFO_in_full        : std_logic;
-- Conduit interface towards GPIO
    signal BLT_inout           : std_logic;
-- FIFO_out interface
    signal UART_read           : std_logic;
    signal FIFO_out_readdata   : std_logic_vector(7  downto 0);
    signal FIFO_out_empty      : std_logic;
-- registers interface
    signal UART_on              : std_logic;
    signal UART_parity          : std_logic_vector(1  downto 0);
    signal UART_stop_bit        : std_logic;
    signal UART_wait_cycles     : std_logic_vector(31 downto 0);
    signal UART_data_dropped    : std_logic;
    signal UART_data_received   : std_logic;

--more fifo signals
    signal FIFO_in_read        :   std_logic;
    signal FIFO_in_readdata    :   std_logic_vector(7  downto 0);
    signal FIFO_in_use_dw      :   std_logic_vector(9  downto 0);
    signal FIFO_out_use_dw     :   std_logic_vector(9  downto 0);
    signal FIFO_out_write      :   std_logic;
    signal FIFO_out_writedata  :   std_logic_vector(7  downto 0);

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
    
    UART_inst : entity work.UART_BT PORT MAP (
        clk                 => clk,
        nReset              => nReset,
        UART_write          => UART_write,
        UART_writedata      => UART_writedata,
        BLT_Rx              => BLT_inout,
        BLT_Tx              => BLT_inout,
        UART_read           => UART_read,
        FIFO_out_readdata   => FIFO_out_readdata,
        FIFO_out_empty      => FIFO_out_empty,
        UART_on             => UART_on,
        UART_parity         => UART_parity,
        UART_stop_bit       => UART_stop_bit,    
        UART_wait_cycles    => UART_wait_cycles,
        UART_data_dropped   => UART_data_dropped,
        UART_data_received  => UART_data_received,
        FIFO_in_full        => FIFO_in_full
        );
        
    FIFO_in : entity work.FIFO_in_BT
    PORT MAP (
		aclr	 => reset,
		clock	 => clk,
		data	 => UART_writedata,
		rdreq	 => FIFO_in_read,
		wrreq	 => UART_write,
		full	 => FIFO_in_full,
		q	     => FIFO_in_readdata,
		usedw	 => FIFO_in_use_dw
	);
    
    FIFO_out : entity work.FIFO_out_BT
    PORT MAP (
		aclr	 => reset,
		clock	 => clk,
		data	 => FIFO_out_writedata,
		rdreq	 => UART_read,
		wrreq	 => FIFO_out_write,
		empty	 => FIFO_out_empty,
		q	     => FIFO_out_readdata,
		usedw	 => FIFO_out_use_dw
	);
    
    reset <= not nReset;

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
    
    simulation : process
    procedure async_reset is
        begin
            wait until rising_edge(CLK);
            wait for CLK_PERIOD / 4;
            nReset <= '0';
            
            wait for CLK_PERIOD / 2;
            nReset <= '1';
        end procedure async_reset;
    
    procedure write_FIFO(constant data : std_logic_vector(7 downto 0)) is
    begin
        wait until rising_edge(clk);
        wait for CLK_PERIOD/4;
        test_data   <= data;
        FIFO_out_write      <= '1';
        FIFO_out_writedata  <= data;
        wait until rising_edge(clk);
        wait for CLK_PERIOD/4;
        test_data   <= (others => '0');
    end procedure write_FIFO;
    
    procedure read_FIFO(constant data : std_logic_vector(7 downto 0)) is
    begin
        wait until rising_edge(clk);
        wait for CLK_PERIOD/4;
        test_data       <= data;
        FIFO_in_read    <= '1';
        wait until rising_edge(clk);
        wait for CLK_PERIOD/4;
        assert FIFO_in_readdata = data report "wrong readdata" severity failure;
        test_data   <= (others => '0');
    end procedure read_FIFO;
    
    begin
        -- set inputs to 0
        UART_on         <= '1';
        UART_parity     <= (others => '0');
        UART_stop_bit   <= '0';
        UART_wait_cycles    <= (others => '0');
        UART_wait_cycles(1 downto 0) <= "11"; --3 wait cycles
        
        async_reset;
        
        write_FIFO("10101010");
        write_FIFO("11110000");
        write_FIFO("11001100");
        
        wait until FIFO_in_use_dw = (9 downto 3 => '0') & "111";
        
        read_FIFO("10101010");
        read_FIFO("11110000");
        read_FIFO("11001100");
        
        sim_finished <= true;
        wait;
    end process simulation;
end;

