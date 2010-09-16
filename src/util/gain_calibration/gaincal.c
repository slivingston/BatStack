/*gaincal.c
 *
 * Calibration of gain (or transfer function) of microphones in array.
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


#define PWM_PERIOD_START 0x001F // ~116.5 kHz
#define PWM_PERIOD_STOP  0x0180 // ~9.8 kHz
#define PWM_PERIOD_SHIFT 1 // Number of bits to left shift by for each period change
#define PWM_PERIOD_STEP 1 // Amount to increment by for each period change

#define IPI_COUNT 0x100 // Number of Timer 1 interrupts to sleep through between emissions
#define PULSE_COUNT 5


volatile unsigned int pwm_period = 0;
volatile unsigned int num_sleep = 0;
volatile unsigned int num_pulses = 0;


int main(void)
{
	unsigned int k; // generic counter

	// Init stuff
	AD1PCFGL = 0xffff; // Set all pins to "digital" mode.
	TRISB = 0x0000;    // Port B configured for output.
	LATAbits.LATA4 = 0; // Ensure output at RA4 is low before switching to output mode.
	TRISAbits.TRISA4 = 0; // Trigger is sent out over RA4.


	/* Timing calibration; uncomment to get toggling of RA4 (pin 9)
	   such that pulse width corresponds to three instruction clock
	   cycles. */
/*
	TRISA = 0x0000;
	LATA = 0x0000;
	while (1)
		__asm__ volatile( "btg 0x2c4, #4" );
*/

	
	// Map OC1 to RP7 pin
	__asm__ volatile ( "disi #0x3fff" ); // Disable (priority level < 7) interrupts during clock switch
	__asm__ volatile ( "mov 0x742, w0\n\t"
					   "mov.b #0x46, w0\n\t"
					   "mov 0x742, w1\n\t"
					   "mov.b #0x57, w1\n\t"
					   "mov #0x1200, w2\n\t"
					   "mov w0, 0x742\n\t"
					   "mov w1, 0x742\n\t"
					   "bclr 0x742, #6\n\t" // clear IOLOCK bit
					   "mov w2, 0x6C6\n\t"  // map OC1 to RP7; tie RP6 to default.
					   "mov w0, 0x742\n\t"
					   "mov w1, 0x742\n\t"
					   "bset 0x742, #6\n\t" // set IOLOCK bit
					   :
					   :
					   : "w0", "w1", "w2" );
	__asm__ volatile ( "disi #0x0" ); // Re-enable interrupts

	num_pulses = 0;
	pwm_period = PWM_PERIOD_START-PWM_PERIOD_STEP;
	num_sleep = 0;

	IFS0bits.T1IF = 0;
	IEC0bits.T1IE = 1;
	TMR1 = 0;
	PR1 = 0x0302;
	T1CON = 0x8000;

	while (1) {
		if (num_pulses >= PULSE_COUNT) {
			T1CON = T2CON = OC1CON = 0;
			break;
		}
	}
	k = 0;
	while (k < 0x0e60) {
		__asm__ volatile( "nop" );
		k++;
	}
	LATAbits.LATA4 = 1; // Trigger!
	k = 0;
	while (k < 0x0e60) {
		__asm__ volatile( "nop" );
		k++;
	}
	LATAbits.LATA4 = 0; // back low

	while (1)
		__asm__ volatile( "nop" ); // stall until reset

	return 0;
}


void _ISR __attribute__((auto_psv)) _T1Interrupt( void )
{
	IFS0bits.T1IF = 0;

	// Stop Timer 2 and output compare modules
	T2CON = 0;
	OC1CON = 0;

	// Change period (if necessary)
	if (pwm_period < PWM_PERIOD_STOP) {
		//pwm_period <<= PWM_PERIOD_SHIFT;
		pwm_period += PWM_PERIOD_STEP;
	} else {
		if (num_sleep == 0) {
			num_pulses++;
			num_sleep++;
			return;
		} else {
			if (num_sleep > IPI_COUNT) {
				num_sleep = 0;
				pwm_period = PWM_PERIOD_START;
			} else {
				num_sleep++;
				return;
			}
		}
	}

	// Update compare module
	OC1RS = OC1R = pwm_period>>1;
	OC1CON = 0x0006;

	// Setup and start Timer 2
	TMR2 = 0x0000;
	PR2 = pwm_period;
	T2CON = 0x8000;
}
