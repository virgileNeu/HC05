-- #############################################################################
-- UART_BT.vhd
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

entity UART_BT is
    port(
        clk                 : in    std_logic;
        nReset              : in    std_logic;
    -- FIFO_in interface
        UART_write          : out   std_logic;
        UART_writedata      : out   std_logic_vector(7  downto 0);
        FIFO_in_full        : in    std_logic;
    -- Conduit interface towards GPIO
        BLT_Tx              : out   std_logic;
        BLT_Rx              : in    std_logic;
    -- FIFO_out interface
        UART_read           : out   std_logic;
        FIFO_out_readdata   : in    std_logic_vector(7  downto 0);
        FIFO_out_empty      : in    std_logic;
    -- registers interface
        UART_on             : in    std_logic;
        UART_parity         : in    std_logic_vector(1  downto 0);
        UART_stop_bit       : in    std_logic;
        UART_wait_cycles    : in    std_logic_vector(31 downto 0);
        UART_data_dropped   : out   std_logic;
        UART_data_received  : out   std_logic
    );
end entity UART_BT;

architecture rtl of UART_BT is
type UART_snd_state is (snd_WAITING, snd_START, snd_SENDING, snd_PARITY, snd_STOP);
type UART_rcv_state is (rcv_WAITING, rcv_START, rcv_RECEIVING, rcv_PARITY, rcv_STOP, rcv_RESTART);
-- SEND SIGNALS
signal snd_state            : UART_snd_state;
signal snd_counter          : unsigned(31 downto 0); -- 0 to UART_wait_cycles
signal snd_bit_counter      : unsigned(3 downto 0);  -- 0 to 8
signal snd_stop_counter     : unsigned(1 downto 0);  -- 0 to 2
signal snd_parity_bit       : std_logic; -- 0 for even, 1 for odd
signal snd_data             : unsigned(7 downto 0);
signal snd_out              : std_logic := '1'; -- for BLT_Tx

-- RECEIVE SIGNALS
signal rcv_state            : UART_rcv_state;
signal rcv_counter          : unsigned(31 downto 0); -- 0 to UART_wait_cycles
signal rcv_bit_counter      : unsigned(3 downto 0);  -- 0 to 8
signal rcv_data             : std_logic_vector(7 downto 0);
signal rcv_parity_bit       : std_logic; -- 0 for even, 1 for odd
signal rcv_wrong_parity        : std_logic;

signal UART_stop            : unsigned(0 downto 0);

begin

UART_stop(0)<= UART_stop_bit;
BLT_Tx      <= snd_out;

transmitting : process(nReset, clk)
begin
    if(nReset = '0') then
        snd_state           <= snd_WAITING;
        snd_counter         <= (others => '0');
        snd_bit_counter     <= (others => '0');
        snd_stop_counter    <= (others => '0');
        snd_parity_bit      <= '0';
        snd_data            <= (others => '0');
        snd_out             <= '1';
        UART_read           <= '0';
    elsif(rising_edge(clk)) then
        -- default value
        UART_read           <= '0';
        -- flip-flops default values
        snd_state           <= snd_state;
        snd_counter         <= snd_counter;
        snd_bit_counter     <= snd_bit_counter;
        snd_stop_counter    <= snd_stop_counter;
        snd_data            <= snd_data;
        snd_out             <= snd_out;
        --parity computation : 0 for even, 1 for odd, xor does the work
        snd_parity_bit      <=  snd_data(0) xor snd_data(1) xor snd_data(2) xor snd_data(3)
                            xor snd_data(4) xor snd_data(5) xor snd_data(6) xor snd_data(7);
        case snd_state is
        when snd_WAITING =>
            snd_out <= '1';
            if(UART_on = '1' and FIFO_out_empty = '0') then
					 snd_data <= unsigned(FIFO_out_readdata);
					 snd_state <= snd_START;
					 snd_counter <= (others => '0');
					 UART_read <= '1';					 
				else
                snd_state   <= snd_WAITING;
            end if;
        when snd_START =>
            snd_out         <= '0';
            if(snd_counter >= unsigned(UART_wait_cycles) -1) then
                snd_state       <= snd_SENDING;
                snd_bit_counter <= (others => '0');
                snd_counter     <= (others => '0');
            else
                snd_state   <= snd_START;
                snd_counter <= snd_counter +1;
            end if;
        when snd_SENDING =>
            if(snd_bit_counter >= 8 and UART_parity(1)  = '0') then --no parity
                snd_out             <= '1';
                snd_counter         <= (others => '0');
                snd_state           <= snd_STOP;
                snd_stop_counter    <= (others => '0');
            elsif(snd_bit_counter >= 8) then --parity set
                snd_out     <= snd_parity_bit xor UART_parity(0);
                snd_counter <= (others => '0');
                snd_state   <= snd_PARITY;
                --xor between settings and even parity to obtain odd.
            elsif(snd_counter >= unsigned(UART_wait_cycles)) then
                snd_out         <= snd_data(to_integer(snd_bit_counter));
                snd_state       <= snd_SENDING;
                snd_bit_counter <= snd_bit_counter +1;
                snd_counter     <= (others => '0');
            else
                snd_out     <= snd_data(to_integer(snd_bit_counter));
                snd_state   <= snd_SENDING;
                snd_counter <= snd_counter +1;
            end if;
        when snd_PARITY =>
            snd_out     <= snd_parity_bit xor UART_parity(0);
            if(snd_counter >= unsigned(UART_wait_cycles)) then
                snd_counter         <= (others => '0');
                snd_state           <= snd_STOP;
                snd_stop_counter    <= (others => '0');
            else
                snd_counter <= snd_counter +1;
                snd_state   <= snd_PARITY;
            end if;
        when snd_STOP =>
            snd_out <= '1';
            snd_state   <= snd_STOP;
            snd_counter <= snd_counter +1;
            if(snd_counter >= unsigned(UART_wait_cycles)) then
                snd_stop_counter    <= snd_stop_counter +1;
                snd_counter         <= (others => '0');
                if(snd_stop_counter >= UART_stop)then
                    snd_state       <= snd_WAITING;
                end if;
            end if;
        end case;
    end if;
end process transmitting;


rcv_parity_bit  <=  rcv_data(0) xor rcv_data(1) xor rcv_data(2) xor rcv_data(3)
                xor rcv_data(4) xor rcv_data(5) xor rcv_data(6) xor rcv_data(7)
                xor UART_parity(0);

receiving : process(nReset, clk)
begin
    if(nReset = '0') then
        rcv_state           <= rcv_WAITING;
        rcv_counter         <= (others => '0');
        rcv_bit_counter     <= (others => '0');
        rcv_data            <= (others => '0');
        UART_write          <= '0';
        UART_writedata      <= (others => '0');
        UART_data_dropped   <= '0';
        rcv_wrong_parity       <= '0';
    elsif(rising_edge(clk)) then
        rcv_wrong_parity       <= rcv_wrong_parity;
        rcv_state           <= rcv_state;
        rcv_counter         <= rcv_counter;
        rcv_bit_counter     <= rcv_bit_counter;
        rcv_data            <= rcv_data;
        UART_write          <= '0';
        UART_writedata      <= rcv_data;
        UART_data_dropped   <= '0';
        UART_data_received  <= '0';
        case rcv_state is
        when rcv_WAITING =>
            if(UART_on = '1' and BLT_Rx = '0') then
                rcv_state       <= rcv_START;
                rcv_counter     <= (others => '0');
                rcv_bit_counter <= (others => '0'); 
            else
                rcv_state   <= rcv_WAITING;
            end if;
        when rcv_START =>
            --shit by 1/2 period
            if(rcv_counter >= unsigned('0' & UART_wait_cycles(31 downto 1)) -1) then
                rcv_state       <= rcv_RECEIVING;
                rcv_counter     <= (others => '0');
                rcv_bit_counter <= (others => '0');
                rcv_data        <= (others => '0');
            else
                if(BLT_Rx = '1') then --if error
                    rcv_state   <= rcv_WAITING;
                end if;
                rcv_counter <= rcv_counter +1;
            end if;
        when rcv_RECEIVING =>
            if(rcv_counter >= unsigned(UART_wait_cycles)) then
                rcv_counter                             <= (others => '0');
                rcv_data(to_integer(rcv_bit_counter))   <= BLT_Rx;
                rcv_bit_counter                         <= rcv_bit_counter +1;
                if(rcv_bit_counter >= 7) then
                    if(UART_parity(1) = '1') then
                        rcv_state   <= rcv_PARITY;
                    else
                        rcv_state   <= rcv_STOP;
                    end if;
                else
                    rcv_state       <= rcv_RECEIVING;
                end if;
            else
                rcv_state   <= rcv_RECEIVING;
                rcv_counter <= rcv_counter +1;
            end if;
        when rcv_PARITY =>
            if(rcv_counter >= unsigned(UART_wait_cycles)) then
                rcv_state   <= rcv_STOP;
                rcv_counter <= (others => '0');
                if(BLT_Rx /= rcv_parity_bit) then
                    rcv_wrong_parity <= '1';
                end if;
            else
                rcv_state   <= rcv_PARITY;  
                rcv_counter <= rcv_counter +1;
            end if;
        when rcv_STOP =>
            if(rcv_counter >= unsigned(UART_wait_cycles)) then
                if(rcv_wrong_parity = '0' and BLT_Rx = '1') then --good data
                    if(FIFO_in_full = '0') then
                        UART_write          <= '1';
                        UART_data_received  <= '1';
                    else
                        UART_data_dropped   <= '1';
                    end if;
                end if;
                rcv_wrong_parity    <= '0';
                rcv_state       <= rcv_RESTART;
                rcv_counter     <= (others => '0');
                rcv_bit_counter <= (others => '0');
            else
                rcv_counter <= rcv_counter +1;
            end if;
        when rcv_RESTART =>
            if(rcv_counter >= unsigned('0' & UART_wait_cycles(31 downto 1)) -1) then
                rcv_state       <= rcv_WAITING;
                rcv_counter     <= (others => '0');
            else
                rcv_counter <= rcv_counter +1;
            end if;
        end case;
    end if;
end process receiving;
end;


