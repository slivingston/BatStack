/*memcheck.c
 * 
 * Verify all addresses in external SRAM units on a BatStack.  Result
 * is printed using the on-board LEDs, using the usual bit ordering, with
 * bit set means PASS,
 * bit cleared means FAIL.
 *
 *
 * Scott Livingston  <slivingston@caltech.edu>
 * May 2010.
 *
 */


#include "platform.h"


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


#define NUM_1kB_PER_SRAM 2048
// ...equivalently, number of 512-word blocks per SRAM unit.

unsigned int SRAMchipW[4] = {0x8010, 0x8008, 0x8004, 0x8002};
unsigned int SRAMchipR[4] = {0x8210, 0x8208, 0x8204, 0x8202};

#define NUM_TEST_CASES 7


int main()
{
	unsigned int result = 0xF; /* lowest 4 bits; lsb is first SRAM unit, etc. */
	unsigned int sram_unit, // index at SRAM unit level
		num_blocks, // number of 1 kB blocks accessed thus far
		ind_in_block, // index within current 1 kB block
		k; // index into test_list
	unsigned int test_list[] =  {0x025A, 0x5A5A, 0x0000, 0xBEEF, 0xDEAD, 0x8118, 0xFFFF };
	/* Note that a mask is applied to external SRAM reads/writes so that only
	   the lower 10 bits are considered. */
	
	unsigned int word = 0; // For storing result read from external SRAM.

	/* Initialize clock, disable ADC input pins. */
	INTCON1bits.NSTDIS = 1; /* Disable nested interrupts */


	/*
	 * Switch to our desired clock, achieving Tcy = 25 ns.
	 *
	 */
	__asm__ volatile ( "disi #0x3fff" ); // Disable (priority level < 7) interrupts during clock switch

    PLLFBD = 0x1E;
	CLKDIV = 0x0; /* In particular, PLLPRE := 0, PLLPOST := 0, DOZEN := 0. */

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

	AD1PCFGH = 0xFFFF; // Disable all A/D pins
    AD1PCFGL = 0xFFFF;

	// Trigger button setting (and LEDs)
    TRISC = 0x0002;
    PORTC = 0;

	// Apply bit mask to test cases
	for (k = 0; k < NUM_TEST_CASES; k++)
		test_list[k] &= 0x03FF;

	// External SRAM related ports:
    TRISB = 0x000F; // Address [PORTB<15:4>][PORTE<7:0>]
    TRISE = 0x0000;
	TRISD = 0x0000; // Data bus (init to output mode)
    TRISA = 0x0000; // Control lines

	/* Step through each unit, write and try each entry in test_list.
	   On a failure, mark SRAM unit as bad, abort testing of it, and
	   continue on to next unit. */
	for (sram_unit = 0; sram_unit < 4; sram_unit++) {
		
		LATB = LATE = 0; // Clear address
		LATD = 0; // Drive data bus to 0x0000

		num_blocks = ind_in_block = k = 0;
		while (num_blocks < NUM_1kB_PER_SRAM) {

			// Apply all test cases to memory word at each address
			for (k = 0; k < NUM_TEST_CASES; k++) {
				TRISD = 0x0000;
				LATA = SRAMchipW[sram_unit]; // Configure for writing.

				LATD = test_list[k];
				LATAbits.LATA15 = 0; // A15 = 0 implies Write Enable
				NOP;
				NOP;
				NOP;
				NOP;
                
				LATAbits.LATA15 = 1;       // Write Disable
				NOP;
				NOP;
				NOP;
				NOP;

				// Prepare to read from SRAM unit
				LATD = 0;
				TRISD = 0xFFFF;
				LATA = SRAMchipR[sram_unit];

				LATAbits.LATA9 = 0; // SRAM output enable
				NOP;
				NOP;
				NOP;
				NOP;
			
				word = PORTD & 0x03ff; // Read in word
				NOP;
				NOP;
				NOP;
				NOP;

				LATAbits.LATA9 = 1; // SRAM output disable
				NOP;
				NOP;
				NOP;
				NOP;

				if (test_list[k] != word) { // Compare; abort if failure.
					result ^= 1<<sram_unit;
					break;
				}
			}

			if (LATE == 0x00FF) {
				LATB += 0x0010;
				LATE = 0x0000;
			} else {
				LATE++;
			}
			
			ind_in_block += 2;
			if (ind_in_block >= 1024) {
				ind_in_block = 0;
				num_blocks++;
			}

		}

	}

	// Display result
	if (result == 0) { // toggle all LEDs if all external SRAM units failed.
		ind_in_block = 0;
		while (1) {
			k = 1;
			while (k > 0) {
				num_blocks = 1;
				while (num_blocks < 50) {
					__asm__ volatile( "nop" );
					num_blocks++;
				}
				k++;
			}
			LED1 = LED2 = LED3 = LED4 = ind_in_block;
			ind_in_block ^= 1;
		}
	}
	LED1 = result&0x1;
	LED2 = (result>>1)&0x1;
	LED3 = (result>>2)&0x1;
	LED4 = (result>>3)&0x1;
	while (1) ;

	return 0;
}
