/* utils.c
 *
 * Scott Livingston <slivingston@caltech.edu>,
 * October 2009, April 2010.
 *
 */


#include "utils.h"
#include "env.h"


unsigned int parity( unsigned data_word )
{
	unsigned int result = 0;
	unsigned int bit_counter;
	for (bit_counter = 0; bit_counter < 8; bit_counter++)
		result += (data_word >> bit_counter) & 0x1;
	return result&0x1;
}


unsigned int crc7( unsigned int *buf, unsigned int buf_len ) // Only lower 7 bits of result are valid.
{
	unsigned int result[] = {0x0, 0x0};
	unsigned int k, byte_ind, bit_ind; // indices
	unsigned int byte;
	

	if (buf_len == 0)
		return 0;

	for (k = 0; k < buf_len; k++) {                     // Each element (words) in buffer
		for (byte_ind = 0; byte_ind < 2; byte_ind++) {  // Each byte (in little endian)
			if (byte_ind)
				byte = (*(buf+k)) & 0xff;
			else
				byte = (*(buf+k)) >> 8;
			for (bit_ind = 0; bit_ind < 8; bit_ind++) { // Each bit

				*result = *result << 1;
				*(result+1) = (*(result+1)) << 1;
				*result |= 0x1 & (byte ^ ((*(result+1))>>4));
				*(result+1) |= 0x1 & ((*result) ^ ((*result)>>3));
				*result &= 0x7;
				*(result+1) &= 0xf;
				byte = byte >> 1;

			}
		}
	}

	return (*result) | ((*(result+1))<<3);
}


unsigned int crc16( unsigned int *buf, unsigned int buf_len )
{
	unsigned int result[] = {0x0, 0x0, 0x0};
	unsigned int k, byte_ind, bit_ind; // indices
	unsigned int byte;
	

	if (buf_len == 0)
		return 0;

	for (k = 0; k < buf_len; k++) {                     // Each element (words) in buffer
		for (byte_ind = 0; byte_ind < 2; byte_ind++) {  // Each byte (in little endian)
			if (byte_ind)
				byte = (*(buf+k)) & 0xff;
			else
				byte = (*(buf+k)) >> 8;
			for (bit_ind = 0; bit_ind < 8; bit_ind++) { // Each bit

				*(result) = (*(result)) << 1;
				*(result+1) = (*(result+1)) << 1;
				*(result+2) = (*(result+2)) << 1;
				*(result) |= 0x1 & (byte ^ ((*(result+2))>>4));
				*(result+1) |= 0x1 & ((*(result)) ^ ((*(result))>>5));
				*(result+2) |= 0x1 & ((*(result)) ^ ((*(result+1))>>7));
				*(result) &= 0x1f;
				*(result+1) &= 0x7f;
				*(result+2) &= 0xf;
				byte = byte >> 1;

			}
		}
	}

	return (*result) | ((*(result+1))<<5) | ((*(result+2))<<12);
}


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


/* Assumes dsPIC board layout for BatStack. */
inline void printLEDnum( unsigned int k )
{
	LED1 = k & 0x1;
	LED2 = (k>>1) & 0x1;
	LED3 = (k>>2) & 0x1;
	LED4 = (k>>3) & 0x1;
}


inline void step_byte( unsigned int k )
{
	printLEDnum( k & 0xf );
	delay_kinstr( 40 ); // ~1 ms at Tcy = 25 ns 
	while (!TRIGGER) ;
	
	printLEDnum( (k>>4) & 0xf );
	delay_kinstr( 40 );
	while (!TRIGGER) ;
}


/* A simple panic and toggle LEDs until death routine for quick-n-dirty error detection. */
void toggle_LEDs_forever()
{
	unsigned int k = 0;
	while (1) { // Toggle all 4 green LEDs on dsPIC board.
		delay_kinstr( 1000 );
		if (k) {
			printLEDnum( 0xFF );
			k = 0;
		} else {
			printLEDnum( 0x00 );
			k = 1;
		}
	}
}


/* Prints a (16-bit) word, 4 bits at a time, from least-significant nibble upward.
   To progress through the number, pin C1 must be driven to Vdd */
void printLEDword( unsigned int k )
{
    unsigned int portc_dir_state = TRISC;
    TRISC = 0x0002;
    LATC = 0x0000;
    delay_kinstr( 40000 ); /* Delay for ~1 s to mitigate debouncing effects. */
	printLEDnum( 1 ); // nibble 1 (i.e. first) next
	delay_kinstr( 50000 );
	delay_kinstr( 50000 );

    /* Bits 3:0 */
    printLEDnum( k & 0x000F );
    while (!TRIGGER) ;
	printLEDnum( 2 ); // nibble 2
	delay_kinstr( 50000 );
	delay_kinstr( 50000 );
    
    /* Bits 7:4 */
    printLEDnum( (k & 0x00F0) >> 4 );
	delay_kinstr( 40000 );
    while (!TRIGGER) ;
	printLEDnum( 3 ); // nibble 3
	delay_kinstr( 50000 );
	delay_kinstr( 50000 );
    
    /* Bits 11:8 */
    printLEDnum( (k & 0x0F00) >> 8 );
	delay_kinstr( 40000 );
    while (!TRIGGER) ;
	printLEDnum( 4 ); // nibble 4
	delay_kinstr( 50000 );
	delay_kinstr( 50000 );
    
    /* Bits 15:12 */
    printLEDnum( (k & 0xF000) >> 12 );
	delay_kinstr( 40000 );
    while (!TRIGGER) ;
    
    TRISC = portc_dir_state;
    return;
}


/*
 * DESC: Step through and write to each word in each of the 4 SRAM units, sequentially
 *       incrementing a word counter (unsigned, i.e., 0 through 2^16-1).
 */
void fill_SRAM_seq()
{
    unsigned long addr; // Addressing in SRAM units is per word

    LED1 = 0; // Initially C3 LED is off.

    for (sram_unit = 0; sram_unit < 4; sram_unit++) {
    //sram_unit = 0; // Test individual SRAM units.
    
        // Toggle C3 LED per SRAM unit
        LED1 ^= 1;
        //delay_100ms();
		delay_kinstr( 200 );
    
        // Set necessary control bits.
        LATA = SRAMchipW[sram_unit];
    
        // Fill entire SRAM unit: 1 Mword (words are 16 bits wide).
        for (addr = 0; addr < 0x00100000; addr++) {
        
            // Twiddle C2 LED per word written
            LED2 = ~LED2;
            
            PORTD = (unsigned int)(addr & 0x03FF); // Write counting sequence (derived from lower 10 bits of addr)
            
            LATAbits.LATA15 = 0; // Write Enable
            // Stall for 4 instructions to ensure SRAM unit is ready for writing.
			NOP;
			NOP;

            LATAbits.LATA15 = 1; // Write Disable
            
            // Increment Address
            if (LATE == 0xFF) {
                LATB += 0x10;   // Address Higher 12 bits (PORTB<4-15>)       
            } else {
                LATE++;
            }
            
        }
    
    }
    
    sram_unit = 0;
}

/*
 * DESC: sister function to fill_SRAM_seq. This function steps through
 * words in all four modules of SRAM and prints the lowest nibble.
 * 
 */
void playback_SRAM()
{
    unsigned long addr; // Addressing in SRAM units is per word
	unsigned int data;

	// Initially clear all LEDs
    LED1 = 0; // MSb
	LED2 = 0;
	LED3 = 0;
	LED4 = 0; // LSb

    for (sram_unit = 0; sram_unit < 4; sram_unit++) {
    
        // Set necessary control bits.
		LATAbits.LATA5 = 0;     // This enables 74LVT125 buffers
        LATA = SRAMchipR[sram_unit];
		LATE = 0;
		LATB = 0;
    
        // Read from entire SRAM unit: 1 Mword (words are 16 bits wide).
        for (addr = 0; addr < 0x00100000; addr++) {

			LATAbits.LATA9 = 0; // SRAM output enable
            NOP;
			NOP;
			NOP;
			NOP;
			
            data = PORTD & 0x03ff;     // Data is read from the port and upper 6 bits are ignored (via mask).

            LATAbits.LATA9 = 1;        // SRAM output disable
			
			// Pause and show result on LED output
			LED4 = data & 0x0001;
			LED3 = (data & 0x0002) >> 1;
			LED2 = (data & 0x0004) >> 2;
			LED1 = (data & 0x0008) >> 3;
			delay_kinstr( 1000 );
            
            // stall for 4 instructions (75 ns, assuming 25 ns instruction cycle period)
            NOP;
			NOP;
			NOP;
			NOP;

            // Increment Address
            if (LATE == 0xFF) {
                LATB = LATB + 0x10;   // Address Higher 12 bits (PORTB<4-15>)
                LATE = 0;                   // First byte (PORTE<0-7>)
            } else {
                LATE++;
            }
            
        }
    
    }
    
    sram_unit = 0;
}
