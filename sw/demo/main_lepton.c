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
#include "ressources/lepton.h"
#include "ressources/lepton_regs.h"

void lepton_send_capture(lepton_dev *dev, hc05_dev *hc05, bool adjusted) {
    const uint8_t num_rows = 60;
    const uint8_t num_cols = 80;

    uint16_t offset = LEPTON_REGS_BUFFER_OFST;
    uint16_t max_value = IORD_16DIRECT(dev->base, LEPTON_REGS_MAX_OFST);
    if (adjusted) {
        offset = LEPTON_REGS_ADJUSTED_BUFFER_OFST;
        max_value = 0x3fff;
    }

    char str[1000];
    int check;

    /* Write header */
    sprintf(str, "P2\n%" PRIu8 " %" PRIu8 "\n%" PRIu16, num_cols, num_rows, max_value);
    do {
    	check = BT_send_message(hc05, str, strnlen(str, 1000));
    } while(check == -1);
    /* Write body */
    uint8_t row = 0;
    for (row = 0; row < num_rows; ++row) {
    	do {
    		check = BT_send_word_safe(hc05, '\n');
    	} while(check == -1);
        uint8_t col = 0;
        for (col = 0; col < num_cols; ++col) {
            if (col > 0) {
            	do {
					check = BT_send_word_safe(hc05, ' ');
				} while(check == -1);
            }

            uint16_t current_ofst = offset + (row * num_cols + col) * sizeof(uint16_t);
            uint16_t pix_value = IORD_16DIRECT(dev->base, current_ofst);
            sprintf(str, "%" PRIu16, pix_value);
            do {
				check = BT_send_message(hc05, str, strnlen(str, 1000));
			} while(check == -1);
        }
    }
}


int main() {
	hc05_dev hc05 = hc05_inst(HC05_0_BASE);
	i2c_pio_dev pio = i2c_pio_inst(I2C_PIO_0_BASE);
	lepton_dev lepton = lepton_inst(LEPTON_0_BASE);
	lepton_init(&lepton);

	i2c_pio_write(&pio, 0);
	i2c_pio_writebit(&pio, BIT_BLT_PWR, 1);
	i2c_pio_writebit(&pio, BIT_BLT_ATSel, 1);

	usleep(1000000); //1s to let the device boot

	i2c_pio_writebit(&pio, BIT_BLT_EN, 1);
	usleep(1000000); //1s to let the device boot

	BT_set_CTRL(&hc05, BLT_UART_ON | BLT_STOP_0);
	BT_set_baud_rate(&hc05, b38400);

	char response[100];

	BT_send_command(&hc05, "AT+UART=115200,0,0", 18);
		BT_get_data_terminator(&hc05, response);
		if(strncmp(response, "OK", 2)) {
			printf("UART command not ok\n End program");
			return -1;
		}

	BT_send_command(&hc05, "AT+CMODE=0", 10);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n End program");
		return -1;
	}
	BT_send_command(&hc05, "AT+ROLE=0", 9);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n");
		return -1;
	}

	i2c_pio_writebit(&pio, BIT_BLT_ATSel, 0);
	BT_send_command(&hc05, "AT+RESET", 8);
	BT_get_data_terminator(&hc05, response);
	if(strncmp(response, "OK", 2)) {
		printf("UART command not ok\n End program");
		return -1;
	}
	BT_set_baud_rate(&hc05, b115200);
	BT_reset_FIFO(&hc05, BLT_RESET_FIFO_IN | BLT_RESET_FIFO_OUT);

	do {
		printf("Connection detected.\nReady to take picture ?(y/n)");
		scanf("%s", response);
		if(response[0] == 'y') {
			do{
				lepton_start_capture(&lepton);
				lepton_wait_until_eof(&lepton);
			}while(lepton_error_check(&lepton));
			lepton_send_capture(&lepton, &hc05, true);
			printf("\nDone.\n");
		}
	} while(response[0]=='y');

	printf("End of program\n");
	return 0;
}

