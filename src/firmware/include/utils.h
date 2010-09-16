/* utils.h
 *
 * Scott Livingston <slivingston@caltech.edu>,
 * October 2009, April 2010.
 *
 */


#ifndef _UTILS_H_
#define _UTILS_H_


#include <p33FJ128GP710.h>


/* Perform CRC7 or CRC16 (as defined in SD card specifications,
   ver 2.00 part 1 and likely elsewhere). */
unsigned int crc7( unsigned int *buf, unsigned int buf_len ); // Only lower 7 bits of result are valid.
unsigned int crc16( unsigned int *buf, unsigned int buf_len ); 

/* Returns 1 if number of 1 bits in given word is odd, 0 otherwise.
   Serves as a low cost error-checking routine. */
unsigned int parity( unsigned data_word );

void set_clk40MHz();
void delay_kinstr( unsigned int kstalls );
inline void printLEDnum( unsigned int k );
void printLEDword( unsigned int k ); /* step through each nibble of given
										word, using trigger button as
										step indicator. Thus, there are
										four button presses, each of
										which indicates "ready to move on
										(to next nibble or finish this
										function)." Order is least
										significant nibble first. */
inline void step_byte( unsigned int k ); // lower byte of given word
void fill_SRAM_seq();
void playback_SRAM();


#endif
