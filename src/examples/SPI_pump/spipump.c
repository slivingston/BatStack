/*
 * Pump message 0xDEAD 0xBEEF to SPI.
 *
 *
 * Scott Livingston <slivingston@caltech.edu>
 * 16 April 2009
 *
 */


#include "../../firmware/platform.h"


#define SS LATGbits.LATG9


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
_FOSCSEL( FNOSC_PRIPLL & IESO_ON )
_FOSC( FCKSM_CSECMD & POSCMD_XT )


void initspi_master()
{
	IFS2bits.SPI2IF = 0;
	IEC2bits.SPI2IE = 0; // Disable SPI2 interrupts

	SPI2STATbits.SPIEN = 0;  // Disable SPI module 2 while we configure it.
	
	SPI2CON1bits.DISSCK = 0; // Use internal SPI clock (we are in Master mode, after all).
	SPI2CON1bits.DISSDO = 0; // Module controls SDO pin
	SPI2CON1bits.MODE16 = 0; // 8-bit (byte) mode
	SPI2CON1bits.CKE = 1;    // Change output on falling edge.
	SPI2CON1bits.CKP = 0;    // Clock idle is at low level.
	SPI2CON1bits.SSEN = 0;   // CS pin (or slave select) is manually controlled.
	SPI2CON1bits.MSTEN = 1;  // Master mode!
	SPI2CON1bits.SMP = 1;    // Sample input bit at middle of data output time.
	slowSCK();

	SPI2CON2 = 0x0000; // Do not use framed SPI.

	SPI2STATbits.SPIROV = 0; // Reset read overflow flag.
	SPI2STATbits.SPIEN = 1;  // It's go time!

	TRISGbits.TRISG9 = 0; // Set CS (or slave select) I/O port to output mode.
	SS = 1; // Drive SS high, i.e., deselect slave
}


void initspi_slave()
{
	IFS2bits.SPI2IF = 0;
	IEC2bits.SPI2IE = 0; // Disable SPI2 interrupts

	SPI2STATbits.SPIEN = 0;  // Disable SPI module 2 while we configure it.
	
	SPI2CON1bits.DISSCK = 0; // Use internal SPI clock.
	SPI2CON1bits.DISSDO = 0; // Module controls SDO pin
	SPI2CON1bits.MODE16 = 0; // 8-bit (byte) mode
	SPI2CON1bits.CKE = 1;    // Change output on falling edge.
	SPI2CON1bits.CKP = 0;    // Clock idle is at low level.
	SPI2CON1bits.SSEN = 0;   // CS pin (or slave select) is manually controlled.
	SPI2CON1bits.MSTEN = 0;  // Slave mode!
	SPI2CON1bits.SMP = 0;
	slowSCK();

	SPI2CON2 = 0x0000; // Do not use framed SPI.

	SPI2STATbits.SPIROV = 0; // Reset read overflow flag.
	SPI2STATbits.SPIEN = 1;  // It's go time!
}


// 10 MHz SCK rate
inline void fastSCK()
{
	SPI2CON1bits.PPRE = 3; // primary prescale is 1:1
	SPI2CON1bits.SPRE = 4; // secondary prescale is 1:4
}

// ~150 kHz SCK rate
inline void slowSCK()
{
	SPI2CON1bits.PPRE = 0; // primary prescale is 1:64
	SPI2CON1bits.SPRE = 4; // secondary prescale is 1:4
}


unsigned char rwspi( unsigned char outdat )
{
	unsigned int indat;
	
	SPI2STATbits.SPIROV = 0;

	// Eat whatever is in the SPI read buffer
	if (SPI2STATbits.SPIRBF)
		indat = SPI2BUF;

	/* Wait for prior SPI writes to finish transfering. */
	if (SPI2STATbits.SPITBF) {
		while (SPI2STATbits.SPITBF) ;  // Wait for transfer to begin.
		while (!SPI2STATbits.SPIRBF) ; // Wait for transfer to finish.
		indat = SPI2BUF;               // ...and eat the result.
	}

	/* Finally, perform the desired transfer. */
	SPI2BUF = outdat;

	/* Wait for prior SPI writes to finish transfering. */
	while (SPI2STATbits.SPITBF) ;  // Wait for transfer to begin.
	while (!SPI2STATbits.SPIRBF) ; // Wait for transfer to finish.

	indat = SPI2BUF;
	return indat;
}


int main()
{   
	unsigned int k;
	unsigned int i,j; // For trigger LED blinking.
	unsigned int num_it;
	unsigned char msg[] = { 0xAD, 0xDE, 0xEF, 0xBE }; // DEAD BEEF (little endian)

	INTCON1bits.NSTDIS = 1; /* Disable nested interrupts */

    while (OSCCONbits.COSC != 3) ; /* Wait until we are using the XT (crystal, 10 MHz) oscillator. */
    CLKDIVbits.PLLPRE = 0;
    PLLFBDbits.PLLDIV = 0x1E;
    CLKDIVbits.PLLPOST = 0;
    while (!OSCCONbits.LOCK) ; /* Wait for PLL to lock. */

	AD1PCFGH = AD1PCFGL = 0xFFFF; // Disable all ADC inputs.
	

	TRISC = 0;
	LATC = 0;
	TRIGGER_DIR = 1; // Use trigger to drive SPI pumping (in master mode)
	
	initspi_master();

	k = 0;
	while (1) {
		while (!TRIGGER) { /* Wait for trigger (Port C1 pin driven up to Vdd). */
			i++;
			if (i > 1000) {
				j++;
				i = 0;
				if (j > 1000) {
					LED2 ^= 1; /* Waiting for trigger indicator */
					j = 0;
				}
			}
        }
		for (num_it = 0; num_it < 4096; num_it++) {
			SS = 0;
			rwspi(*(msg+k));
			asm("nop");
			SS = 1;
			k++;
			if (k > 3)
				k = 0;
		}
	}
	
	return 0;
}
