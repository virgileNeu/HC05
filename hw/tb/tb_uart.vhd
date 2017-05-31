library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity tb_uart is
end tb_uart;

architecture test of tb_uart is
    constant CLK_PERIOD     : time := 20 ns; -- 50MHz
    signal sim_finished     : boolean := false;
    signal lw_value : std_logic_vector(7 downto 0);
    
    signal test_data        : std_logic_vector(7  downto 0);
    
    signal clk              : std_logic;
    signal nReset           : std_logic;
            
-- FIFO_in interface
    signal UART_write          : std_logic;
    signal UART_writedata      : std_logic_vector(7  downto 0);
    signal FIFO_in_full        : std_logic;
-- Conduit interface towards GPIO
    signal BLT_Tx              : std_logic;
    signal BLT_Rx              : std_logic;
-- FIFO_out interface
    signal UART_read           : std_logic;
    signal FIFO_out_readdata       : std_logic_vector(7  downto 0);
    signal FIFO_out_empty          : std_logic;
-- registers interface
    signal UART_on              : std_logic;
    signal UART_parity          : std_logic_vector(1  downto 0);
    signal UART_stop_bit        : std_logic;
    signal UART_wait_cycles     : std_logic_vector(31 downto 0);
    signal UART_data_dropped    : std_logic;
    signal UART_data_received   : std_logic;

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
        BLT_Rx              => BLT_Rx,
        BLT_Tx              => BLT_Tx,
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
    
    last_written_value : process(UART_write)
    begin
    if(UART_write = '1') then
        lw_value <= UART_writedata;
    end if;
    end process last_written_value;
    
    simulation : process
    procedure async_reset is
        begin
            wait until rising_edge(CLK);
            wait for CLK_PERIOD / 4;
            nReset <= '0';
            
            wait for CLK_PERIOD / 2;
            nReset <= '1';
        end procedure async_reset;
        
    procedure send_data(constant data : in std_logic_vector(7 downto 0);
                        constant wait_cycles : in integer;
                        constant parity_on : in std_logic;
                        constant parity_type : in std_logic;
                        constant parity_bit : in std_logic;
                        constant stop_bits : in integer) is
    begin
        wait until rising_edge(clk);
        wait for CLK_PERIOD /4;
        UART_parity         <= parity_on & parity_type;
        if(stop_bits = 1) then
            UART_stop_bit   <= '1';
        else
            UART_stop_bit   <= '0';
        end if;
        UART_wait_cycles    <= std_logic_vector(to_unsigned(wait_cycles, UART_wait_cycles'length));
        FIFO_out_empty  <= '0';
        wait until rising_edge(clk);
        wait for CLK_PERIOD /4;
        assert (UART_read = '1') report "Expecting read after FIFO_out is not empty" severity failure;
        wait until rising_edge(clk);
        FIFO_out_readdata   <= data;
        wait until rising_edge(clk);
        FIFO_out_empty      <= '1';
        FIFO_out_readdata   <= (others => '0');
        
        for i in 0 to wait_cycles-2 loop -- first wait_cycle is spend reading the FIFO
            wait for CLK_PERIOD /4;
            assert (BLT_Tx = '0') report "start bit : Expecting BLT_Tx to be 0 = start if transmition" severity failure;
            wait until rising_edge(clk);
        end loop;
        
        for i in data'length -1 downto 0 loop
            for j in 0 to wait_cycles-1 loop
                wait for CLK_PERIOD /4;
                assert (BLT_Tx = data(i)) 
                    report "data bits : BLT_Tx wrong value " &
                            " is " & std_logic'image(BLT_Tx) &
                            " should be " & std_logic'image(data(i))
                    severity failure;
            wait until rising_edge(clk);
            end loop;
        end loop;
        
        if(parity_on = '1') then -- parity set
            for i in 0 to wait_cycles-1 loop
                wait for CLK_PERIOD /4;
                assert (BLT_Tx = parity_bit)
                    report "parity bit : BLT_Tx wrong value " &
                            " is " & std_logic'image(BLT_Tx) &
                            " should be " & std_logic'image(parity_bit)
                    severity failure;
            wait until rising_edge(clk);
            end loop;
        end if;
        
        --stop bit
        for i in 0 to stop_bits loop
            for j in 0 to wait_cycles-1 loop
                wait for CLK_PERIOD /4;
                assert (BLT_Tx = '1')
                    report "stop bits: " & integer'image(i) & "," & integer'image(j) & " BLT_Tx wrong value " &
                            " is " & std_logic'image(BLT_Tx) &
                            " should be 1"
                    severity failure;
            wait until rising_edge(clk);
            end loop;
        end loop;
        
        wait until rising_edge(clk);
    end procedure send_data;    
        
    
    procedure send_test_all(constant data : in std_logic_vector(7 downto 0);
                            constant wait_cycles : in integer) is
    begin
        report "sending test, data = " & to_string(data);
        report "no parity, 1 stop bit";
        send_data(data, wait_cycles, '0', '0', '0', 0); --no parity, 1 stop bit
        wait until rising_edge(clk);
        report "no parity, 2 stop bit";
        send_data(data, wait_cycles, '0', '0', '0', 1); --no parity, 2 stop bit
        wait until rising_edge(clk);
        report "even parity, 1 stop bit";
        send_data(data, wait_cycles, '1', '0', parity(data, '0'), 0); --parity even, 1 stop bit
        wait until rising_edge(clk);
        report "even parity, 2 stop bit";
        send_data(data, wait_cycles, '1', '0', parity(data, '0'), 1); --parity even, 2 stop bit
        wait until rising_edge(clk);
        report "odd parity, 1 stop bit";
        send_data(data, wait_cycles, '1', '1', parity(data, '1'), 0); --parity odd, 1 stop bit
        wait until rising_edge(clk);
        report "odd parity, 2 stop bit";
        send_data(data, wait_cycles, '1', '1', parity(data, '1'), 1); --parity odd, 2 stop bit
    end procedure send_test_all;
    
    
    procedure receive_data(constant data : in std_logic_vector(7 downto 0);
                        constant wait_cycles : in integer;
                        constant parity_on : in std_logic;
                        constant parity_type : in std_logic;
                        constant parity_bit : in std_logic;
                        constant stop_bits : in integer) is
    begin
        wait until rising_edge(clk);
        wait for CLK_PERIOD /4;
        UART_parity         <= parity_on & parity_type;
        if(stop_bits = 1) then
            UART_stop_bit   <= '1';
        else
            UART_stop_bit   <= '0';
        end if;        UART_wait_cycles    <= std_logic_vector(to_unsigned(wait_cycles, UART_wait_cycles'length));
        FIFO_in_full        <= '0';

        --start bit
        for i in 0 to wait_cycles-1 loop
            wait until rising_edge(clk);
            BLT_Rx <= '0';
        end loop;
        
        --data bits
        for i in data'length -1 downto 0 loop
            for j in 0 to wait_cycles-1 loop
                wait until rising_edge(clk);
                BLT_Rx <= data(i);
            end loop;
        end loop;
        
        --parity bit
        if(parity_on = '1') then
            for i in 0 to wait_cycles-1 loop
                wait until rising_edge(clk);
                BLT_Rx <= parity_bit;
            end loop;
        end if;
        
        --stop bits
        for i in 0 to stop_bits loop
            wait until rising_edge(clk);
            BLT_Rx <= '1';
        end loop;
        
        assert data = lw_value report "bad data send to fifo" severity failure;
        
    end procedure receive_data;
    
    procedure receive_test_all(constant data : std_logic_vector(7 downto 0);
                                constant wait_cycles : integer) is
    begin
        report "receiving test, data = " & to_string(data);
        report "no parity, 1 stop bit";
        receive_data(data, wait_cycles, '0', '0', '0', 0); --no parity, 1 stop bit
        wait until rising_edge(clk);
        report "no parity, 2 stop bit";
        receive_data(data, wait_cycles, '0', '0', '0', 1); --no parity, 2 stop bit
        wait until rising_edge(clk);
        report "even parity, 1 stop bit";
        receive_data(data, wait_cycles, '1', '0', parity(data, '0'), 0); --parity even, 1 stop bit
        wait until rising_edge(clk);
        report "even parity, 2 stop bit";
        receive_data(data, wait_cycles, '1', '0', parity(data, '0'), 1); --parity even, 2 stop bit
        wait until rising_edge(clk);
        report "odd parity, 1 stop bit";
        receive_data(data, wait_cycles, '1', '1', parity(data, '1'), 0); --parity odd, 1 stop bit
        wait until rising_edge(clk);
        report "odd parity, 2 stop bit";
        receive_data(data, wait_cycles, '1', '1', parity(data, '1'), 1); --parity odd, 2 stop bit
    end procedure receive_test_all;
    
    begin
        -- set inputs to 0
        FIFO_in_full    <= '0';
        FIFO_out_readdata   <= (others => '0');
        FIFO_out_empty      <= '1';
        UART_on         <= '1';
        UART_parity     <= (others => '0');
        UART_stop_bit   <= '0';
        UART_wait_cycles    <= (others => '0');
        UART_wait_cycles(1 downto 0) <= "11"; --3 wait cycles
        BLT_Rx          <= '1';
        
        async_reset;
        
        test_data <= "01010101";
        send_test_all("01010101",5);
        
        --sending test
        for i in 0 to 255 loop
            for j in 5 to 17 loop
                test_data <= std_logic_vector(to_unsigned(i, FIFO_out_readdata'length));
                send_test_all(std_logic_vector(to_unsigned(i, FIFO_out_readdata'length)),j);
            end loop;
        end loop;
        
        --receive test
        
        for i in 0 to 255 loop
            for j in 5 to 17 loop
                test_data <= std_logic_vector(to_unsigned(i, FIFO_out_readdata'length));
                receive_test_all(std_logic_vector(to_unsigned(i, FIFO_out_readdata'length)),j);
            end loop;
        end loop;        
        
        sim_finished <= true;
        wait;
    end process simulation;
end;

