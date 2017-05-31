#ifndef HC_05_H_
#define HC_05_H_

#include <stdint.h>
#include "baud_rates.h"

//REG DEFINES
#define BLT_CTRL_REG 0*4
#define BLT_STATUS_REG 1*4
#define BLT_UART_WAIT_CYCLES 2*4
#define BLT_FIFO_OUT_DATA 3*4
#define BLT_FIFO_OUT_FREE_SPACE 4*4
#define BLT_FIFO_IN_DATA 5*4
#define BLT_FIFO_IN_PENDING_DATA 6*4
#define BLT_RESET_FIFO 7*4

//CTRL DEFINES
#define BLT_UART_ON 0b1
#define BLT_UART_OFF 0
#define BLT_I_ENABLE_MASK 0b110
#define BLT_I_ENABLE_RCV 0b10
#define BLT_I_ENABLE_DROP 0b100
#define BLT_STOP_MASK 0b1000
#define BLT_STOP_0 0
#define BLT_STOP_1 0b1000
#define BLT_PARTITY_MASK 0b110000
#define BLT_NO_PARITY 0
#define BLT_EVEN_PARITY 0b100000
#define BLT_ODD_PARITY 0b110000

//STATUS DEFINES
#define BLT_I_PENDING_MASK 0b11
#define BLT_I_PENDING_RCV 0b1
#define BLT_I_PENDING_DROP 0b10

//RESET DEFINES
#define BLT_RESET_FIFO_IN 0b1
#define BLT_RESET_FIFO_OUT 0b10


/* hc05 device structure */
typedef struct {
    void *base; /* Base address of component */
} hc05_dev;

/*******************************************************************************
 *  Public API
 ******************************************************************************/
 
hc05_dev hc05_inst(void *base);

uint32_t BT_get_CTRL(hc05_dev *dev);

void BT_set_CTRL(hc05_dev *dev, uint32_t val);

baud_rate BT_get_baud_rate(hc05_dev *dev);

void BT_set_baud_rate(hc05_dev *dev, baud_rate rate);

uint32_t BT_get_i_pending(hc05_dev *dev);

void BT_clear_i_pending(hc05_dev *dev);

uint32_t BT_get_free_space(hc05_dev *dev);

void BT_send_word(hc05_dev *dev, char word);

int BT_send_word_safe(hc05_dev *dev, char word);

int BT_send_message(hc05_dev *dev, char* message, uint32_t length);

int BT_send_command(hc05_dev *dev, char* message, uint32_t length);

uint32_t BT_get_pending_data(hc05_dev *dev);

uint32_t BT_wait_for_data(hc05_dev *dev, uint32_t amount);

char BT_get_data(hc05_dev *dev);

int BT_get_data_safe(hc05_dev *dev, char* data);

void BT_get_amount_data(hc05_dev *dev, char *data, uint32_t amount);

int BT_get_all_data(hc05_dev *dev, char *data);

int BT_get_data_terminator(hc05_dev *dev, char *data);

void BT_reset_FIFO(hc05_dev *dev, uint32_t val);

#endif /* HC_05_H_ */
