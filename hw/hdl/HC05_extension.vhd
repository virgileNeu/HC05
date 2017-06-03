-- #############################################################################
-- HC05_extension.vhd
--
-- BOARD         : DE0-Nano-SoC from Terasic
-- Author        : Virgile Neu
-- Revision      : 1.0
-- Creation date : 21/03/2017
--
-- Syntax Rule : nGROUP_NAME[bit]
--
-- n     : to specify an active-low signal
-- GROUP : specify the source of the signal (ex: UART, FIFO_in, ...)
-- NAME  : signal name (ex: write, read, ...)
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity HC05_extension is
    port(
        clk             : in    std_logic;
        nReset          : in    std_logic;

        -- Slave interface
        as_address      : in    std_logic_vector(2  downto 0);
        
        as_read         : in    std_logic;
        as_readdata     : out   std_logic_vector(31 downto 0);

        as_write        : in    std_logic;
        as_writedata    : in    std_logic_vector(31 downto 0);
        as_byteenable   : in    std_logic_vector(3  downto 0);
        
        -- Conduit interface towards GPIO
        BLT_Rx          : in    std_logic;
        BLT_Tx          : out   std_logic;
        
        -- Interrupts
        irq             : out   std_logic
    );
end entity HC05_extension;

architecture rtl of HC05_extension is
    -- positive reset for FIFOs
    signal reset_out        : std_logic;
    signal reset_in         : std_logic;
    
    -- Internal signals
        -- registers <---> FIFO_out
            signal FIFO_out_write       : std_logic;
            signal FIFO_out_writedata   : std_logic_vector(7  downto 0);
            signal FIFO_out_use_dw      : std_logic_vector(9  downto 0);
            signal FIFO_out_full        : std_logic;
        -- registers <---> FIFO_in
            signal FIFO_in_use_dw       : std_logic_vector(9  downto 0);
        -- registers  ---> UART
            signal UART_on              : std_logic;
            signal UART_parity          : std_logic_vector(1  downto 0);
            signal UART_stop_bit        : std_logic;
            signal UART_wait_cycles     : std_logic_vector(31 downto 0);
            signal UART_data_dropped    : std_logic;
            signal UART_data_received   : std_logic;
        -- UART <---> FIFO_out
            signal UART_read            : std_logic;
            signal FIFO_out_readdata    : std_logic_vector(7  downto 0);
            signal FIFO_out_empty       : std_logic;
        -- UART <---> FIFO_in
            signal UART_write           : std_logic;
            signal UART_writedata       : std_logic_vector(7  downto 0);
            signal FIFO_in_full         : std_logic;
        -- Arbitrator between FIFO_in and registers
            signal FIFO_in_read         : std_logic;
            signal registers_read       : std_logic;
            signal registers_readdata   : std_logic_vector(31 downto 0);
            signal FIFO_in_readdata     : std_logic_vector(7  downto 0);
            signal read_pending         : std_logic;
begin
-- FIFO reset
reset_in    <= '1' when as_address = "111" and as_write = '1' and as_writedata(0) = '1' else not nReset;
reset_out   <= '1' when as_address = "111" and as_write = '1' and as_writedata(1) = '1' else not nReset;

-- arbitrator between FIFO_in and registers
FIFO_in_read    <= '1' when as_read = '1' and as_address = "101" and read_pending = '0' else '0';
registers_read  <= '1' when as_read = '1' and as_address /= "101" and read_pending = '0' else '0';
as_readdata     <= (31 downto 8 => '0') & FIFO_in_readdata when read_pending = '1' and as_address = "101"
                    else registers_readdata when read_pending = '1'
                    else (others => '0');
                    
FIFO_out_write      <= '1' when as_write = '1' and as_address = "011" else '0';
FIFO_out_writedata  <=  as_writedata(7 downto 0);

process(clk)
begin
    if(rising_edge(clk)) then
        read_pending <= as_read;
    end if;
end process;

-- component instantiation
-- registers
    registers_BT_inst : entity work.registers_BT PORT MAP (
        clk                 => clk,
        nReset              => nReset,
        as_address          => as_address,
        as_read             => registers_read,
        as_readdata         => registers_readdata,
        as_write            => as_write,
        as_writedata        => as_writedata,
        as_byteenable       => as_byteenable,
        FIFO_out_use_dw     => FIFO_out_use_dw,
        FIFO_out_full       => FIFO_out_full,
        FIFO_in_use_dw      => FIFO_in_use_dw,
        FIFO_in_full        => FIFO_in_full,
        UART_on             => UART_on,
        UART_parity         => UART_parity,
        UART_stop_bit       => UART_stop_bit,    
        UART_wait_cycles    => UART_wait_cycles,
        UART_data_dropped   => UART_data_dropped,
        UART_data_received  => UART_data_received,
        irq                 => irq
        );
-- UART
    UART_BT_inst : entity work.UART_BT PORT MAP (
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
-- FIFO_out
    FIFO_out_BT_inst : entity work.FIFO_out_BT PORT MAP (
            aclr    => reset_out,
            clock   => clk,
            data    => FIFO_out_writedata,
            rdreq   => UART_read,
            wrreq   => FIFO_out_write,
            full    => FIFO_out_full,
            empty   => FIFO_out_empty,
            q       => FIFO_out_readdata,
            usedw   => FIFO_out_use_dw
        );
-- FIFO_in
    FIFO_in_BT_inst : entity work.FIFO_in_BT PORT MAP (
            aclr    => reset_in,
            clock   => clk,
            data    => UART_writedata,
            rdreq   => FIFO_in_read,
            wrreq   => UART_write,
            full    => FIFO_in_full,
            q       => FIFO_in_readdata,
            usedw   => FIFO_in_use_dw
        );
end;
