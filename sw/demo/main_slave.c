#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <unistd.h>
#include <stdbool.h>
#include <assert.h>
#include <string.h>

#include "system.h"
#include "ressources/hc05.h"
#include "ressources/i2c_pio.h"
#include "ressources/lepton.h"
#include "ressources/ws2812.h"

/**
 * Slave, receiving information and changing the led
 */
int main() {
	hc05_dev hc05 = hc05_inst(HC05_0_BASE);
	i2c_pio_dev pio = i2c_pio_inst(I2C_PIO_0_BASE);
	ws2812_dev ws2812 = ws2812_inst(WS2812_0_BASE);
	ws2812_setPower(&ws2812, 0);
	ws2812_setConfig(&ws2812, WS2812_DEFAULT_LOW_PULSE,
		WS2812_DEFAULT_HIGH_PULSE, WS2812_DEFAULT_BREAK_PULSE,
		WS2812_DEFAULT_CLOCK_DIVIDER);
	uint8_t red, green, blue;
	uint8_t intensity = ws2812_readIntensity(&ws2812);
	ws2812_writePixel(&ws2812, 0, 0, 0, 0);
	ws2812_setIntensity(&ws2812, 0);

	i2c_pio_write(&pio, 0);
	i2c_pio_writebit(&pio, BIT_BLT_PWR, 1);
	i2c_pio_writebit(&pio, BIT_BLT_ATSel, 1);

	usleep(1000000); //1s to let ATSel propagate, really needed?

	i2c_pio_writebit(&pio, BIT_BLT_EN, 1);

	usleep(1000000); //1s to let the device boot, needed
	BT_reset_FIFO(&hc05, BLT_RESET_FIFO_IN | BLT_RESET_FIFO_OUT);
	BT_set_CTRL(&hc05, BLT_UART_ON | BLT_STOP_0 | BLT_NO_PARITY);
	BT_set_baud_rate(&hc05, b38400);
	char response[100];
    //set UART parameters : 115200bps, 0 parity, 1 stop bit
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
	BT_send_command(&hc05, "AT+ROLE=0", 9);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n");
		return -1;
	}

	//to know BT ADDR
	//currently +ADDR:98d3:32:707966
/*
	BT_send_command(&hc05, "AT+ADDR?", 8);
	BT_get_data_terminator(&hc05, response);
	printf("%s", response);
	BT_get_all_data(&hc05, response);
	*/
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
	char message[100];
	int loop = 1;
	int stop = 1;

	while(loop) {
		BT_get_data_terminator(&hc05, message);
		if(stop) {
			if(!strncmp(message, "OFF\r\n", 5)) {
				loop = 0;
			} else if(!strncmp(message, "START\r\n", 7)) {
				ws2812_writePixel(&ws2812, 0, red, green, blue);
				ws2812_setIntensity(&ws2812, intensity);
				stop = 0;
			}
		} else {
			if(!strncmp(message, "STOP\r\n", 7)) {
				ws2812_writePixel(&ws2812, 0, 0, 0, 0);
				ws2812_setIntensity(&ws2812, 0);
				stop = 1;
			} else {
				int tmp;
				char c;
				sscanf(message, "%c%d", &c, &tmp);
				switch(c) {
				case 'R': red = tmp; break;
				case 'G': green = tmp; break;
				case 'B': blue = tmp; break;
				}
				ws2812_writePixel(&ws2812, 0, red, green, blue);
			}
		}
	}
	printf("DONE");
	return 0;
}

