/* platform.h
 *
 * Defines various important macros, global variables and pinout.
 *
 *
 * Scott Livingston
 * Apr 2010.
 *
 */


#ifndef _PLATFORM_H_
#define _PLATFORM_H_


#include <p33FJ128GP710.h>


//////////////////////////////
// Misc macros and constants
//////////////////////////////

#define SECTOR_LEN 512              /* Number of bytes in an SD card sector. */
#define DMA_BLOCK_LEN 512           /* Number of words in a single DMA transfer block. */
#define NUM_SRAM_UNITS 4            /* Number of SRAM units available to MCU. */
#define NUM_DMABLOCKS_PER_SRAM 2048 /* Number of DMA transfer blocks per SRAM unit. */

#define NOP __asm__ volatile ("nop")


////////////////////
// Pin definitions
////////////////////
#define LED1 LATCbits.LATC3
#define LED2 LATCbits.LATC2
#define LED3 LATCbits.LATC13
#define LED4 LATCbits.LATC14

#define TRIGGER PORTCbits.RC1

// For host-Stack communication
#define CLK LATGbits.LATG2
#define DAT LATGbits.LATG3


// Direction bits for all of the above
#define PIN_OUT 0 // For convenience
#define PIN_IN  1

#define LED1_DIR TRISCbits.TRISC3
#define LED2_DIR TRISCbits.TRISC2
#define LED3_DIR TRISCbits.TRISC13
#define LED4_DIR TRISCbits.TRISC14

#define TRIGGER_DIR TRISCbits.TRISC1

#define CLK_DIR TRISGbits.TRISG2
#define DAT_DIR TRISGbits.TRISG3


#endif

