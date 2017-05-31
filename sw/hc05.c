#include <string.h>
#include <inttypes.h>

#include "hc05.h"
#include "io.h"

hc05_dev hc05_inst(void *base) {
	hc05_dev dev = {base};
	return dev;
}
/*
 * Returns the value in the CTRL register of the HC05 component.
 * name: BT_get_CTRL
 * @param dev  : The HC05 device struct.
 * @return The CTRL register value
 * 
 * example: uint32_t ctrl = BT_get_CTRL(&dev);
 * if(ctrl & BLT_I_ENABLE_MASK == BLT_I_ENABLE_RCV) //BLT_I_ENABLE_RCV is on
 */
uint32_t BT_get_CTRL(hc05_dev *dev) {
	return IORD_32DIRECT(dev->base, BLT_CTRL_REG);
}

/*
 * Set the value of the CTRl register of the HC05 component.
 * name: BT_set_CTRL
 * @param dev  : The HC05 device struct.
 *        val  : the value to write to the CTRL register.
 * @return void
 * 
 * example: BT_set_CTRL(&dev, BLT_UART_ON | BLT_I_ENABLE_RCV | BLT_STOP_0 | BLT_ODD_PARITY);
 */
void BT_set_CTRL(hc05_dev *dev, uint32_t val) {
	IOWR_32DIRECT(dev->base, BLT_CTRL_REG, val);
}

/*
 * Returns the value of the UART_wait_cycles register of the HC05 component.
 * name: BT_get_baud_rate
 * @param dev  : The HC05 device struct.
 * @return The UART_wait_cycles register value
 *
 * example: baud_rate r = BT_get_baud_rate(&dev);
 * switch(r) {
 *   case b4800: break;//the baud rate is 4800 bits/s
 *   case b9600: break;//the baud rate is 9600 bits/s
 *   ...
 *   case b1382400: break;//the baud rate is 1382400 bits/s
 * }
 */
baud_rate BT_get_baud_rate(hc05_dev *dev) {
	return IORD_32DIRECT(dev->base, BLT_UART_WAIT_CYCLES);
}

/*
 * Set the value of the UART_wait_cycles register of the HC05 component.
 * name: BT_set_baud_rate
 * @param dev  : The HC05 device struct,
 *        val  : the value to write to the UART_wait_cycles register.
 * @return void
 *
 * example: BT_set_baud_rate(&dev, b38400);
 */
void BT_set_baud_rate(hc05_dev *dev, baud_rate rate) {
	IOWR_32DIRECT(dev->base, BLT_UART_WAIT_CYCLES, rate);
}

/*
 * Returns the value of the STATUS register of the HC05 component
 * i.e. the i_pending bits.
 * name: BT_get_i_pending
 * @param dev  : The HC05 device struct.
 * @return the value of the status register.     
 * 
 * example: uint32_t i_pending = BT_get_i_pending(&dev);
 * if(i_pending & BLT_I_PENDING_MASK == BLT_I_PENDING_RCV | BLT_I_PENDING_DROP)
 *     //There is an interrupt pending.
 */
uint32_t BT_get_i_pending(hc05_dev *dev) {
	return IORD_32DIRECT(dev->base, BLT_STATUS_REG);
}

/*
 * Clear the i_pending bits in the STATUS register of the HC05 component.
 * name: BT_clear_i_pending
 * @param dev  : The HC05 device struct.
 * @return void
 * 
 * example: BT_clear_i_pending(&dev);
 */
void BT_clear_i_pending(hc05_dev *dev) {
	IOWR_32DIRECT(dev->base, BLT_STATUS_REG, 0);
}

/*
 * Return the Amount of free space in the output FIFO
 * i.e. the number of bytes that can be send.
 * name: BT_get_free_space
 * @param dev  : The HC05 device struct.
 * @return the amount of free space in the FIFO_out.
 * 
 * example: uint32_t free_space = BT_get_free_space(&dev);
 * free_space = 1023 => 1023 words can be send to the FIFO_out.
 */
uint32_t BT_get_free_space(hc05_dev *dev) {
	return IORD_32DIRECT(dev->base, BLT_FIFO_OUT_FREE_SPACE);
}

/*
 * Send a single byte to output FIFO without any verification.
 * name: BT_send_word
 * @param dev  : The HC05 device struct,
 *        word : the word to send
 * @return void
 * 
 * example: BT_send_word(&dev, 'A');
 * Sends the char 'A' to the HC05.
 * 
 * /!\
 * The data will be dropped if the FIFO is full.
 * ONLY USE WHEN YOU KNOW HOW MUCH SPACE IS AVAILABLE.
 */
void BT_send_word(hc05_dev *dev, char word) {
	IOWR_8DIRECT(dev->base, BLT_FIFO_OUT_DATA, word);
}

/*
 * Send a single byte to the output FIFO, checking before if it is possible
 * and returning the free space after the send.
 * name: BT_send_word_safe
 * @param dev  : The HC05 device struct,
 *        word : the word to send.
 * @return the amount of free space after the send
 *          or -1 if the send couldn't be done.
 * 
 * example: uint32_t free_space = BT_send_word_safe(&dev, 'A');
 * Sends the char 'A' to HC05. free_space = 1022 chars.
 */
int BT_send_word_safe(hc05_dev *dev, char word) {
	uint32_t space = BT_get_free_space(dev);
	if(space == 0) {
		return -1;
	} else {
		BT_send_word(dev, word);
		return space -1;
	}
}

/*
 * Use this function when not in the AT mode.
 * Send a string to the output FIFO, performing a check on the free space before
 * and returning the free space after the send.
 * name: BT_send_message
 * @param dev     : The HC05 device struct,
 *        message : the message to send,
 *        length  : the length of the message to send
 * @return the amount free space after the send
 *          or -1 if the send couldn't be done.
 * 
 * example: uint32_t free_space = BT_send_message(&dev, "Hello you!!", 11);
 * Sends the message to the Bluetooth paired device. free_space = 1012 chars.
 */
int BT_send_message(hc05_dev *dev, char* message, uint32_t length) {
	uint32_t space = BT_get_free_space(dev);
	if(length > space) {
		return -1;
	} else {
		for(uint32_t i = 0; i < length; ++i) {
			BT_send_word(dev, message[i]);
		}
		return space - (length);
	}
}

/*
 * Use this function when in the AT mode.
 * Same as send_message but add the "\r\n" string at the end of the message.
 * name: BT_send_command
 * @param dev     : The HC05 device struct,
 *        message : the message to send,
 *        length  : the length of the message to send
 * @return the amount free space after the send
 *          or -1 if the send couldn't be done.
 * 
 * example: uint32_t free_space = BT_send_command(&dev, "AT+VERSION?", 11);
 * asks the module was is the version number. free_space = 1010 chars.
 */
int BT_send_command(hc05_dev *dev, char* message, uint32_t length) {
	uint32_t space = BT_get_free_space(dev);
	if(length+2 > space) {
		return -1;
	} else {
		for(uint32_t i = 0; i < length; ++i) {
			BT_send_word(dev, message[i]);
		}
		BT_send_word(dev, '\r');
		BT_send_word(dev, '\n');
		return space - (length+2);
	}
}

/*
 * Get the value of the pending data register
 * i.e. the number of byte waiting to be read.
 * name: BT_get_pending_data
 * @param dev  : The HC05 device struct.
 * @return the amount of word that can be read from the HC05 extension.
 * 
 * example: uint32_t pending = get_pending_data(&dev);
 * pending = 4 => 4 words waiting in the FIFO.
 */
uint32_t BT_get_pending_data(hc05_dev *dev) {
	return IORD_32DIRECT(dev->base, BLT_FIFO_IN_PENDING_DATA);
}

/*
 * Wait until at least amount words are waiting in the FIFO_IN.
 * name: BT_wait_for_data
 * @param dev  : The HC05 device struct.
 * 		  amount : The minimum amount of words expected.
 * @return the amount of word that can be read from the HC05 extension.
 *
 * example: uint32_t pending = wait_for_data(&dev, 2);
 * pending will never be less than 3.
 * pending = 4 => 4 words waiting in the FIFO.
 */
uint32_t BT_wait_for_data(hc05_dev *dev, uint32_t amount) {
	volatile uint32_t pending = 0;
	while((pending = BT_get_pending_data(dev)) < amount);
	return pending;
}
/*
 * Get a single byte from the input FIFO without performing a check.
 * name: BT_get_data
 * @param dev  : The HC05 device struct.
 * @return the char read from the component.
 * 
 * example: char c = BT_get_data(&dev);
 * c = char read.
 * 
 * /!\
 * There is no guarantee on the data in c if the FIFO was empty.
 * ONLY USE WHEN YOU KNOW HOW MUCH DATA IS WAITING.
 */
char BT_get_data(hc05_dev *dev) {
    return IORD_32DIRECT(dev->base, BLT_FIFO_IN_DATA);
}

/*
 * Get a single byte from the input FIFO, performing a check before
 * and returning the amount of pending data after the read.
 * name: BT_get_data_safe
 * @param dev  : The HC05 device struct,
 *        data : a pointer to the data container.
 * @return the amount of waiting data after the read
 *          or -1 if there was nothing to read.
 * 
 * example: char c; int pending = BT_get_data_safe(&dev, &c);
 * pending = amount of char still waiting, c = char read.
 */
int BT_get_data_safe(hc05_dev *dev, char* data) {
	uint32_t pend = BT_get_pending_data(dev);
	if(pend == 0) {
		return -1;
	} else {
		*data = BT_get_data(dev);
		return pend -1;
	}
}

/*
 * Get a specified amount of data waiting in the input FIFO.
 * name: get_amount_data
 * @param dev  : The HC05 device struct,
 *        data : a pointer to a char array that will contain the data.
 * 		  amount : the amount of data to read in the FIFO.
 * @return the amount of char read or -1 if there was no data pending.
 *
 * example: char data[100];
 * BT_get_amount_data(&dev, data, 5);
 * reads 5 chars from the FIFO_IN.
 *
 * /!\
 * There is no guarantee on the data in data if the FIFO was empty
 * or had less than amount elements.
 * ONLY USE WHEN YOU KNOW HOW MUCH DATA IS WAITING.
 */
void BT_get_amount_data(hc05_dev *dev, char *data, uint32_t amount) {
	volatile char c;
    for(uint32_t i = 0; i < amount; ++i) {
    	c = BT_get_data(dev);
        data[i] = c;
    }
    data[amount] = '\0';
}

/*
 * Get all the pending data waiting in the input FIFO.
 * name: BT_get_all_data
 * @param dev  : The HC05 device struct,
 *        data : a pointer to a char array that will contain the data.
 * @return the amount of char read or -1 if there was no data pending.
 * 
 * example: char data[100]; int read = BT_get_all_data(&dev, data);
 * read = amout of char read, data[0..read-1] = data received
 */
int BT_get_all_data(hc05_dev *dev, char *data) {
    volatile uint32_t pend = BT_get_pending_data(dev);
    if(pend == 0) {
    	data[0] = '\0';
        return -1;
    } else {
    	BT_get_amount_data(dev, data, pend);
        return pend;
    }
}

/*
 * Keep reading the FIFO_IN until "\r\n" is read, this is the response terminator for commands.
 * name: BT_get_data_terminator
 * @param dev  : The HC05 device struct,
 *        data : a pointer to a char array that will contain the data.
 * @return the amount of char read.
 *
 * example: char data[100]; int read = BT_get_data_terminator(&dev, data);
 * read = amout of char read, data[0..read-1] = data received
 */
int BT_get_data_terminator(hc05_dev *dev, char *data) {
	int r = 0;
	int i = -1;
	char c = '0', last = '0', tmp;
	while(last != '\r' || c != '\n') {
		do {
			i = BT_get_data_safe(dev, &tmp);
		} while(i == -1);
		last = c;
		c = tmp;
		data[r] = tmp;
		++r;
	}
	data[r] = '\0';
	return r;
}

/*
 * Clear the specified FIFO.
 * name: BT_reset_FIFO
 * @param dev  : The HC05 device struct.
 *        val  : the value corresponding to the FIFO(s) to reset.
 * @return void
 *
 * example: BT_reset_FIFO(&dev, BLT_RESET_FIFO_IN | BLT_RESET_FIFO_OUT);
 * resets both FIFOs
 */
void BT_reset_FIFO(hc05_dev *dev, uint32_t val) {
	IOWR_32DIRECT(dev->base, BLT_RESET_FIFO, val);
}
