-- #############################################################################
-- registers_BT.vhd
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
use ieee.numeric_std.all;

entity registers_BT is
    port(
        clk                 : in    std_logic;
        nReset              : in    std_logic;
    -- Slave interface
        as_address          : in    std_logic_vector(2  downto 0);
        as_read             : in    std_logic;
        as_readdata         : out   std_logic_vector(31 downto 0);
        as_write            : in    std_logic;
        as_writedata        : in    std_logic_vector(31 downto 0);
        as_byteenable       : in    std_logic_vector(3  downto 0);
    -- FIFO_out interface
        FIFO_out_use_dw     : in    std_logic_vector(9  downto 0);
        FIFO_out_full       : in    std_logic;
    -- FIFO_in interface
        FIFO_in_use_dw      : in    std_logic_vector(9  downto 0);
        FIFO_in_full        : in    std_logic;
    -- UART interface
        UART_on             : out   std_logic;
        UART_parity         : out   std_logic_vector(1  downto 0);
        UART_stop_bit       : out   std_logic;
        UART_wait_cycles    : out   std_logic_vector(31 downto 0);
        UART_data_dropped   : in    std_logic;
        UART_data_received  : in    std_logic;
    -- interrupts
        irq                 : out   std_logic
    );
end entity registers_BT;

architecture rtl of registers_BT is
signal UART_on_reg          : std_logic;
signal i_enable             : std_logic_vector(1  downto 0);
signal parity_reg           : std_logic_vector(1  downto 0);
signal stop_bit_reg         : std_logic;
signal i_pending            : std_logic_vector(1  downto 0);
signal UART_wait_cycles_reg : std_logic_vector(31 downto 0);
 
begin

UART_on             <= UART_on_reg;
UART_parity         <= parity_reg;
UART_stop_bit       <= stop_bit_reg;    
UART_wait_cycles    <= UART_wait_cycles_reg;
irq                 <= (i_enable(0) and i_pending(0)) or (i_enable(1) and i_pending(1));

update_write : process(clk, nReset)
begin
    if(nReset = '0') then
        UART_on_reg             <= '0';
        i_enable                <= (others => '0');
        parity_reg              <= (others => '0');
        stop_bit_reg            <= '0';
        i_pending               <= (others => '0');
        UART_wait_cycles_reg    <= (others => '0');
    elsif(rising_edge(clk)) then
        UART_on_reg             <= UART_on_reg;
        i_enable                <= i_enable;
        parity_reg              <= parity_reg;
        stop_bit_reg            <= stop_bit_reg;
        i_pending               <= i_pending;
        UART_wait_cycles_reg    <= UART_wait_cycles_reg;
        if(UART_data_dropped = '1') then
            i_pending(1)        <= '1';
        end if;
        if(UART_data_received = '1') then
            i_pending(0)        <= '1';
        end if;
        if(as_write = '1') then
            case as_address is
            when "000" =>
                parity_reg      <= as_writedata(5 downto 4);
                stop_bit_reg    <= as_writedata(3);
                i_enable        <= as_writedata(2 downto 1);
                UART_ON_reg     <= as_writedata(0);
            when "001" =>
                if(as_writedata(1) = '0') then
                    i_pending(1) <= '0';
                end if;
                if(as_writedata(0) = '0') then
                    i_pending(0) <= '0';
                end if;
            when "010" =>
                UART_wait_cycles_reg    <= as_writedata;
            when "111" =>
                if(as_writedata(0) = '1') then --clear i_pending if reset FIFO_in
                     i_pending <= "00";
                 end if;
            when others => null;
            end case;
        end if;
    end if;
end process update_write;

read_p : process(clk)
begin
    if(rising_edge(clk)) then
        as_readdata <= (others => '0');
        if(as_read = '1') then
            case as_address is
            when "000" =>
                  as_readdata(5 downto 4) <= parity_reg;
                  as_readdata(3)          <= stop_bit_reg;
                  as_readdata(2 downto 1) <= i_enable;
                  as_readdata(0)          <= UART_on_reg;
            when "001" =>
                  as_readdata(1 downto 0) <= i_pending;
            when "010" =>
                  as_readdata             <= UART_wait_cycles_reg;
            when "100" =>
                  as_readdata(9 downto 0) <= (9 downto 0 => not FIFO_out_full) and std_logic_vector((9 downto 0 => '1') - unsigned(FIFO_out_use_dw));
            when "110" =>
						as_readdata(10)			<= FIFO_in_full;
                  as_readdata(9 downto 0) <= FIFO_in_use_dw;
            when others =>
            end case;
        end if;
    end if;
end process read_p;
end;

