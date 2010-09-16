/*
 * Scott Livingston <slivingston@caltech.edu>
 * 20 Sep 2009
 *
 * Demonstrates basic use of MPLAB compiler collection, as released
 * by Microchip. Designed for a quick test on the dsPIC board used
 * in the Batlab microphone array (or Batstack) project. Displays 4-bit
 * counter out to port C bits 2, 3, 13 and 14 (from LSb to MSb) at
 * a rate of approximately 10k instruction cycles per counter increment.
 *
 * On interrupt, the MCU turns on all 4 output LEDs and stalls.
 *
 */


/* Refer to this include file for numerous useful notes on constant
   and macro usage, etc. */
#include <p33FJ128GP710.h>
#include "../../firmware/include/platform.h"


/*
 * Set configuration bits:
 *
 * In this case, watchdog timer off, JTAG disabled and
 * ICD comm channel "reserved" (i.e., not used).
 */
_FWDT( FWDTEN_OFF )
_FICD( JTAGEN_OFF & ICS_NONE )


/* nop for kstalls * 1000 instruction cycles (real elapsed time depends on CPU clock speed. */
void delay_kinstr( unsigned int kstalls )
{
	unsigned int j, k;
	for (k = 0; k < 1000; k++) {
		for (j = 0; j < kstalls; j++) {
			asm( "nop" );
		}
	}
}


int main()
{   
	unsigned int k;

	TRISC = 0;
	LATC = 0;
	
	k = 0;
	while (1) {
		LED1 = k&0x1;
		LED2 = (k>>1)&0x1;
		LED3 = (k>>2)&0x1;
		LED4 = (k>>3)&0x1;
		k++;
		delay_kinstr( 100 ); /* Stall for 10k instruction cycles */
	}

	return 0;
}


void _ISR __attribute__((auto_psv)) _DefaultInterrupt( void )
{
	LED1 = LED2 = LED3 = LED4 = 1;
	while (1) ;
}
