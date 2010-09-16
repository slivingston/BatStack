/*micloc.c
 *
 * Localization of microphones in array.
 *
 *
 * Scott Livingston  <slivingston@caltech.edu>
 * May 2010.
 *
 */


#include <p24HJ12GP201.h>


_FWDT( FWDTEN_OFF )
_FICD( JTAGEN_OFF & ICS_NONE )

// Use FRC, no clock switching, fail-safe nor primary (external) oscillator.
// Thus, Fosc = 7.37 MHz (nominal), whence Tcy is approx. 271.37 ns.
_FOSCSEL( FNOSC_FRC & IESO_OFF )
_FOSC( FCKSM_CSDCMD & OSCIOFNC_ON & POSCMD_NONE )


#define NUM_SOURCES 4
#define NUM_CYCLES  400

volatile unsigned int num_pulses = 0;


int main(void)
{
	// Init stuff
	AD1PCFGL = 0xffff; // Set all pins to "digital" mode.
	LATBbits.LATB7 = 0;
	LATAbits.LATA4 = 0;
	LATBbits.LATB8 = 0;
	LATBbits.LATB4 = 0;
	LATAbits.LATA2 = 0;
	TRISBbits.TRISB7 = 0; // Configure Source 1 pin to output mode.
	TRISAbits.TRISA4 = 0; // Configure Source 2 pin
	TRISBbits.TRISB8 = 0; // Configure Source 3 pin
	TRISBbits.TRISB4 = 0; // Configure Source 4 pin
	TRISAbits.TRISA2 = 0; // Trigger pin
	IFS0bits.T1IF = 0;
	IEC0bits.T1IE = 0; // Timer 1 interrupt is disabled.

	// Setup and start 32-bit timer
	IFS0bits.T3IF = 0;
	IEC0bits.T3IE = 1;
	TMR2 = TMR3 = 0;
	PR2 = 0x7028;
	PR3 = 0x0008; /* Total 32-bit, assuming Tcy of ~271 ns yields timer
				     interrupt every ~150 ms. */
	
	T2CON = 0;
	T2CONbits.T32 = 1;
	T2CONbits.TON = 1;

	while (num_pulses < NUM_SOURCES+1) // +1 allows trigger signal iteration of T3 interrupt.
		__asm__ volatile( "nop" );

	T2CON = 0; // Turn off 32-bit timer
	while (1)
		__asm__ volatile( "nop" ); // Done. Stall till reset.

	return 0;
}


/* Note that Timer 3 interrupt is triggered when using the 32-bit
   (combined Timers 2/3) timer. */
void _ISR __attribute__((auto_psv)) _T3Interrupt( void )
{
	unsigned int wave_count = 0;
	
	IFS0bits.T3IF = 0;

	if (num_pulses >= NUM_SOURCES) { // Time for trigger, now!
		LATAbits.LATA2 = 1; // Trigger!
		wave_count = 0; // Note that we co-opt wave_count here to act as a timing counter.
		while (wave_count < 0x0e60) {
			__asm__ volatile( "nop" );
			wave_count++;
		}
		LATAbits.LATA2 = 0; // back low
		num_pulses++;
	}

	TMR1 = 0;
	PR1 = 0x0060;
	T1CON = 0x8000; // Start Timer 1;

	while (wave_count < NUM_CYCLES) {
		while (TMR1 < PR1-3) ;
		switch (num_pulses) {
		case 0:
			LATBbits.LATB7 = 1;
			break;
		case 1:
			LATAbits.LATA4 = 1;
			break;
		case 2:
			LATBbits.LATB8 = 1;
			break;
		case 3:
			LATBbits.LATB4 = 1;
			break;
		}
		TMR1 = 0; // just to be safe
		while (TMR1 < PR1-3) ;
		switch (num_pulses) {
		case 0:
			LATBbits.LATB7 = 0;
			break;
		case 1:
			LATAbits.LATA4 = 0;
			break;
		case 2:
			LATBbits.LATB8 = 0;
			break;
		case 3:
			LATBbits.LATB4 = 0;
			break;
		}
		TMR1 = 0;

		wave_count++;
	}

	T1CON = 0; // Stop Timer 1
	num_pulses++;
}
