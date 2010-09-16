/* sdspi.h
 *
 * Scott Livingston <slivingston@caltech.edu>,
 * October 2009.
 *
 * NOTES: - Based on tests with a 2 GB ("Ultra") and 256 MB cards, and
 *          as corroborated by the SD card specs (v1.9?), memory is
 *          byte-addressed but reads and writes must be
 *          block-aligned. Because alignment is not checked explicitly
 *          in this code, the user MUST do so herself (e.g., by
 *          working with sector numbers only and multiplying the
 *          desired sector number by 512 when specifying addresses to
 *          my functions herein).
 *
 */


#ifndef _SDSPI_H_
#define _SDSPI_H_


#include <p33FJ128GP710.h>


void initspi();
unsigned char rwspi( unsigned char outdat ); /* ...because SPI is full duplex. */

/* Manipulate SCK prescale values, assuming Fcy = 40 MHz.
   These should be changed to macros at some point. */
inline void fastSCK(); /* primary 1:1, secondary 1:4 => SCK is 10 MHz */
inline void slowSCK(); /* primary 1:64, secondary 1:4 => SCK is 156.25 kHz */


/* Send command to SD card.

   Assumes the command has length 6 bytes (per SD card specs). Wait
   for up to max_tries bytes following transmission of command for R1
   response, or any non-0xFF byte from the card.

   Failure is indicated by return value of 0xFF;
   otherwise, the received (non-0xFF) byte is returned. */
unsigned char cmdsd( unsigned char *cmd, int max_tries );


int initsd(); /* Assumes SCK is between 100 kHz and 400 kHz, per SD card specs for initialization.
			     Returns major version number, in particular 1 or 2;
				 or -1 on failure. */
int readsd_block( unsigned long sector_addr, unsigned char *buf ); /* Assumes buf array has 512 elements. */
int writesd_block( unsigned long sector_addr, unsigned char *buf ); /* Assumes buf array has 512 elements. */
/* Note that these addresses are assumed to be sector number. Hence,
   the final address used with the SD card is sector_addr*512 (i.e. byte aligned). */

/* Write an address (big endian) specified by addr into addr_array;
   this routine is used by readsd_block and writesd_block.*/
void filladdr( unsigned long addr, unsigned char *addr_array );


#define CS_pin LATGbits.LATG9
#define COMMAND_LEN 6


/* R1 response flag bits */
#define ILLEGAL_CMD 0x04
#define IDLE_STATE  0x01
#define ADDR_ERROR 0x20

/* Data tokens */
#define START_BLOCK 0xFE

/* Data response values, received in reply to each block written to SD card.
   Note that the status is 3 bits wide, but response token is one byte
   and thus has extra formatting accounted for here. */
#define DATA_ACCEPTED   0x05
#define WRITE_ERROR     0x0D
#define WRITE_CRC_ERROR 0x0B


#endif
