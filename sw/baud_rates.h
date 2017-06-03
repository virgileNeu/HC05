#ifndef BAUD_RATES_H_
#define BAUD_RATES_H_


/**
 * These baud rates are computed for a 50MHz clock.
 * The value is the amount of clock cycles for each bit.
 *
 * They are computed with the following formula :
 * wait_cycles 	= time_per_bit / time_per_cycles
 * 				= (1/target_baud_rate)/clk_period
 * 				= clk_freq/target_baud_rate.
 * For example, for a target_baud_rate of 38400 b/s,
 * we have : wait_cycles = 50M/38400 = 1302.08 clk_cycles
 */
typedef enum {
	b4800=10415, b9600=5208, b19200=2604,
	b38400=1302, b57600=867, b115200=433,
	b230400=216, b460800=109, b921600=53,
	b1382400=35} baud_rate;


#endif /* BAUD_RATES_H_ */
