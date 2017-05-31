#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <unistd.h>
#include <stdbool.h>
#include <assert.h>

#include "io.h"
#include "system.h"
#include "ressources/hc05.h"
#include "ressources/i2c_pio.h"
#include "ressources/mcp3204.h"
#include "ressources/ws2812.h"

/**
 * Host, sending joystick information
 */
int main() {
	ws2812_dev ws2812 = ws2812_inst(WS2812_0_BASE);
	ws2812_setConfig(&ws2812, WS2812_DEFAULT_LOW_PULSE,
		WS2812_DEFAULT_HIGH_PULSE, WS2812_DEFAULT_BREAK_PULSE,
		WS2812_DEFAULT_CLOCK_DIVIDER);
	ws2812_setPower(&ws2812, 0);
	ws2812_writePixel(&ws2812, 0, 0, 0, 0);
	ws2812_setIntensity(&ws2812, 0);

	hc05_dev hc05 = hc05_inst(HC05_0_BASE);
	i2c_pio_dev pio = i2c_pio_inst(I2C_PIO_0_BASE);
	mcp3204_dev mcp = mcp3204_inst(MCP3204_0_BASE);

	i2c_pio_write(&pio, 0);
	i2c_pio_writebit(&pio, BIT_BLT_PWR, 1);
	i2c_pio_writebit(&pio, BIT_BLT_ATSel, 1);

	usleep(1000000); //1s to let ATSel propagate, really needed?

	i2c_pio_writebit(&pio, BIT_BLT_EN, 1);

	usleep(1000000); //1s to let the device boot, needed
	BT_reset_FIFO(&hc05, BLT_RESET_FIFO_IN | BLT_RESET_FIFO_OUT);
	BT_set_CTRL(&hc05, BLT_UART_ON | BLT_STOP_0);
	BT_set_baud_rate(&hc05, b38400);

	char response[100];

	BT_send_command(&hc05, "AT+UART=115200,0,0", 18);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n");
		return -1;
	}

	BT_send_command(&hc05, "AT+CMODE=0", 10);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n");
		return -1;
	}
	BT_send_command(&hc05, "AT+ROLE=1", 9);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n");
		return -1;
	}

	//currently +ADDR:98d3:32:707966
	BT_send_command(&hc05, "AT+BIND=98d3,32,707966", 22);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n");
		return -1;
	}
	i2c_pio_writebit(&pio, BIT_BLT_ATSel, 0);
	BT_send_command(&hc05, "AT+RESET", 8);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n");
		return -1;
	}
	//i2c_pio_writebit(&pio, BIT_BLT_EN, 0);
	//i2c_pio_writebit(&pio, BIT_BLT_EN, 1);


	BT_reset_FIFO(&hc05, BLT_RESET_FIFO_IN | BLT_RESET_FIFO_OUT);
	BT_set_baud_rate(&hc05, b115200);

	printf("PRESS RIGHT JOY TO START, LEFT TO PAUSE, BOTH TO STOP\n");
	printf("LEFT-JOY Y AXIS for BLUE\nRIGHT-JOY Y AXIS for RED\nRIGHT-JOY X AXIS for GREEN\n");
	printf("y=0 is up, y=255 is down, x=0 is left, x=255 is right\n");
	fflush(stdout);

	char message[100];
	int loop = 1;
	int stop = 1;
	while(loop) {
		usleep(50000);
		if(stop) {
			i2c_pio_writebit(&pio, BIT_J0SWRn, 1);
			i2c_pio_writebit(&pio, BIT_J1SWRn, 1);
			if(!i2c_pio_readbit(&pio, BIT_J1SWRn) && !i2c_pio_readbit(&pio, BIT_J0SWRn)) {
				BT_send_message(&hc05, "OFF\r\n", 5);
				loop = 0;
			} else if(!i2c_pio_readbit(&pio, BIT_J1SWRn)){
				BT_send_message(&hc05, "START\r\n", 7);
				stop = 0;
			}
		} else {
			i2c_pio_writebit(&pio, BIT_J0SWRn, 1);
			if(!i2c_pio_readbit(&pio, BIT_J0SWRn)) { //joy 0 pressed
				BT_send_message(&hc05, "STOP\r\n", 6);
				stop = 1;
			}
			//we shift by 4 on the left to get values
			//from 4096 range to 256 range (2^12 -> 2^8)
			uint32_t r = mcp3204_read(&mcp, 0) >> 4;
			uint32_t g = mcp3204_read(&mcp, 1) >> 4;
			uint32_t b = mcp3204_read(&mcp, 2) >> 4;
			//send red
			sprintf(message, "R%" PRIu32 "\r\n", r);
			BT_send_message(&hc05, message, strnlen(message, 100));
			//send green
			sprintf(message, "G%" PRIu32 "\r\n", g);
			BT_send_message(&hc05, message, strnlen(message, 100));
			//send blue
			sprintf(message, "B%" PRIu32 "\r\n", b);
			BT_send_message(&hc05, message, strnlen(message, 100));
		}
	}
	printf("DONE");
	return 0;
}

