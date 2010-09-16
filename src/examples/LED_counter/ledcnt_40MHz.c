/*
 * Scott Livingston <slivingston@caltech.edu>
 * 28 Apr 2009
 *
 * Demonstrates basic use of MPLAB compiler collection, as released
 * by Microchip. Designed for a quick test on the dsPIC board used
 * in the Batlab microphone array (or Batstack) project. Displays 4-bit
 * counter out to port C bits 2, 3, 13 and 14 (from LSb to MSb) at
 * a rate of approximately 10k instruction cycles per counter increment.
 *
 * Includes pulling clock up to maximum rate, Tcy = 25 ns (i.e. 80 MHz
 * base frequency).
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


/* Use 10.000 MHz crystal (XT) with PLL;
   switch is automatic, achieved using two-clock startup. */
_FOSCSEL( FNOSC_FRC & IESO_OFF )
_FOSC( FCKSM_CSECMD & POSCMD_XT & OSCIOFNC_ON )


/* nop for kstalls * 1000 instruction cycles (real elapsed time
   depends on CPU clock speed). Note this is approximate and would be
   much better if built-in timer was used. */
void delay_kinstr( unsigned int kstalls )
{
	unsigned int j, k;
	for (k = 0; k < 100; k++) { //100 instead of 1000 here almost accounts for other instructions aside from nop.
		for (j = 0; j < kstalls; j++) {
			asm( "nop" );
		}
	}
}


int main()
{   
	unsigned int k;

	INTCON1bits.NSTDIS = 1; /* Disable nested interrupts */

	__asm__ volatile ( "disi #0x3fff" ); // Disable (priority level < 7) interrupts during clock switch

	CLKDIVbits.PLLPRE = 0;
    PLLFBDbits.PLLDIV = 0x1E;
    CLKDIVbits.PLLPOST = 0;
	CLKDIVbits.DOZE = 0;
	CLKDIVbits.DOZEN = 0;

	__asm__ volatile ( "mov #0x78, w0\n\t"
					   "mov #0x9A, w1\n\t"
					   "mov #0x46, w2\n\t"
					   "mov #0x57, w3\n\t"
					   "mov #0x3, w4\n\t"
					   "mov #0x1, w5\n\t"
					   "mov #0x743, w7\n\t"
					   "mov #0x742, w6\n\t"
					   "mov.b w0, [w7]\n\t"
					   "mov.b w1, [w7]\n\t"
					   "mov.b w4, [w7]\n\t"
					   "mov.b w2, [w6]\n\t"
					   "mov.b w3, [w6]\n\t"
					   "mov.b w5, [w6]\n\t" );
	while (OSCCONbits.OSWEN) ;

	__asm__ volatile ( "disi #0x0" ); // Re-enable interrupts


	TRISC = 0;
	LATC = 0;

	k = 0;
	while (1) {
		LED1 = k&0x1;
		LED2 = (k>>1)&0x1;
		LED3 = (k>>2)&0x1;
		LED4 = (k>>3)&0x1;
		k++;
		delay_kinstr( 40000 ); /* Stall for 10k instruction cycles */
	}

	return 0;
}


void _ISR __attribute__((auto_psv)) _DefaultInterrupt( void )
{
	LED1 = LED2 = LED3 = LED4 = 1;
	while (1) ;
}
