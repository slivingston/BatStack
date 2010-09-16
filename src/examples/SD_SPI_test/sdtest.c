/* sdtest.c - SD card via SPI test on dsPIC board.
 *
 * Scott Livingston <slivingston@caltech.edu>, Oct 2009.
 * 
 * Inspired by but not based on k9spud's work... I decided to do a
 * fresh rewrite for the dsPIC33FJ128GP710 as available on the dsPIC
 * board within the BatStack.
 *
 * Test a complete initialization, write and read cycle on an SD card
 * over the dsPIC SPI module 2. The test sequence of nibbles displayed
 * on the BatStack's dsPIC board LEDs is 0000, 1111, 0011, 1100, 1001.
 * If they are played back correctly, then the init, write and read
 * completed successfully.
 *
 * NOTES: - In general and unless obviously not applicable, functions
 *          return zero on success and non-zero on failure.
 *
 *        - SD card interface routines based on SD card spec manual v1.9 and v2.00.
 *
 *        - I currently assume the card is either compliant to SD card
 *          specification version 1.9 or 2.00.
 *
 *        - All SPI transmissions lock the dsPIC until the outgoing
 *          byte has been fully sent, hence until a fresh byte has
 *          been fully read into the SPI2RXB buffer. Confer the rwspi
 *          function.
 *
 *        - Currently CRCs are not used! This might not be a fair
 *          assumption regarding line reliability.
 *
 */


#include <p33FJ128GP710.h>


void set_clk40MHz();
void delay_kinstr( unsigned int kstalls );


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
int readsd_block( unsigned long addr, unsigned char *buf ); /* Assumes buf array has 512 elements. */
int writesd_block( unsigned long addr, unsigned char *buf ); /* Assumes buf array has 512 elements. */

/* Write an address (big endian) specified by addr into addr_array;
   this routine is used by readsd_block and writesd_block.*/
void filladdr( unsigned long addr, unsigned char *addr_array );


#define CS_pin LATGbits.LATG9
#define COMMAND_LEN 6

/* SD card commands (all 6 bytes long; CRC ignored by default for all but CMD0 in SPI mode). */
unsigned char CMD0[] = { 64, 0x00, 0x00, 0x00, 0x00, 0x95 }; // GO_IDLE_STATE
unsigned char CMD8[] = { 72, 0x00, 0x00, 0x01, 0xAA, 0xFF }; // SELF_IF_COND (only for SD card spec v2.x)
unsigned char CMD55[] = { 119, 0x00, 0x00, 0x00, 0x00, 0xFF }; // APP_CMD
unsigned char ACMD41[] = { 105, 0x00, 0x00, 0x00, 0x00, 0xFF }; // SD_SEND_OP_COND
unsigned char CMD1[] = { 65, 0x00, 0x00, 0x00, 0x00, 0xFF }; // SD_SEND_OP_COND
unsigned char CMD17[] = { 81, 0x00, 0x00, 0x00, 0x00, 0xFF }; // READ_SINGLE_BLOCK; address to be filled later
unsigned char CMD24[] = { 88, 0x00, 0x00, 0x00, 0x00, 0xFF }; // WRITE_BLOCK; address to be filled later

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


/*
 * Set configuration bits:
 *
 * In this case, watchdog timer off, JTAG disabled and
 * ICD comm channel "reserved" (i.e., not used).
 *
 * Look near function set_clk40MHz definition for clock-related
 * configuration bits.
 */
_FWDT( FWDTEN_OFF )
_FICD( JTAGEN_OFF & ICS_NONE )


/* Set Fcy (instruction clock) to 40 MHz.

   Note that, since most instructions only require a single clock
   cycle, this corresponds to approximately 40 MIPS. */
_FOSCSEL( FNOSC_FRC & IESO_OFF )
_FOSC( FCKSM_CSECMD & POSCMD_XT )
void set_clk40MHz( void )
{
    // Initial Osc. Source: FRC
    // Internal-External Switchover: Start-up device with user-selected osc.
    // Primary osc. mode: XT crystal osc.
    // OSC2 Pin: Functions as CLKO
    // Clock Switch Mode: Clock switching enabled, Fail-safe clock monitor is disabled
    // FRC = default 7.37MHz, 7.37/2*43/2 = 80MHZ = 40MIPS
    PLLFBD = 41;	       // M=43
    CLKDIVbits.PLLPOST0 = 0;  // N1=2
    CLKDIVbits.PLLPOST1 = 0;
    CLKDIVbits.PLLPRE0 = 0;   // N2=2 --> PLLPRE=0;
    CLKDIVbits.PLLPRE1 = 0;
    CLKDIVbits.PLLPRE2 = 0;
    CLKDIVbits.PLLPRE3 = 0;
    CLKDIVbits.PLLPRE3 = 0;
    OSCTUN = 0;			// Tune FRC oscillator, if FRC is used
	// Clock Switching
	// Place the New Oscillator Selection (NOSC=0b001) in W0
    __asm__ volatile ( "MOV #0x01,w0" );
	//OSCCONH (high byte) Unlock Sequence
	__asm__ volatile ( "MOV #0x0743, w1" );
	__asm__ volatile ( "MOV #0x78, w2" );
	__asm__ volatile ( "MOV #0x9A, w3" );
	__asm__ volatile ( "MOV.B w2, [w1]" ); // Write 78h
	__asm__ volatile ( "MOV.B w3, [w1]" ); // Write 9Ah
	//Set New Oscillator Selection
	__asm__ volatile ( "MOV.B w0, [w1]" );
	//Place 0x01 in W0 for setting clock switch enabled bit
	__asm__ volatile ( "MOV #0x01, w0" );
	//OSCCONL (low byte) Unlock Sequence
	__asm__ volatile ( "MOV #0x0742, w1" );
	__asm__ volatile ( "MOV #0x46, w2" );
	__asm__ volatile ( "MOV #0x57, w3" );
	__asm__ volatile ( "MOV.B w2, [w1]" ); // Write 46h
	__asm__ volatile ( "MOV.B w3, [w1]" ); // Write 9Ah
	// Enable Clock Switch
	__asm__ volatile ( "MOV.B w0, [w1]" ); // Request Clock Switching by Setting OSWEN bit
    while (OSCCONbits.OSWEN == 1) ;
    while (OSCCONbits.COSC != 0b001) ;
    while (OSCCONbits.LOCK != 1) ;
}


/* nop for kstalls * 1000 instruction cycles (real elapsed time depends on CPU clock speed). */
void delay_kinstr( unsigned int kstalls )
{
	unsigned int j, k;
	for (k = 0; k < 1000; k++) {
		for (j = 0; j < kstalls; j++) {
			asm( "nop" );
		}
	}
}


/* Assumes dsPIC board layout for BatStack. */
inline void printLEDnum( unsigned int k )
{
	LATC = (k & 0x0001) << 3;
	LATC |= (k & 0x0002) << 1;
	LATC |= (k & 0x000C) << 11;
}


inline void fastSCK()
{
	SPI2CON1bits.PPRE = 3; // primary prescale is 1:1
	SPI2CON1bits.SPRE = 4; // secondary prescale is 1:4
}

inline void slowSCK()
{
	SPI2CON1bits.PPRE = 0; // primary prescale is 1:64
	SPI2CON1bits.SPRE = 4; // secondary prescale is 1:4
}


void initspi()
{
	SPI2STATbits.SPIEN = 0;  // Disable SPI module 2 while we configure it.
	
	SPI2CON1bits.DISSCK = 0; // Use internal SPI clock (we are in Master mode, after all).
	SPI2CON1bits.DISSDO = 0; // Module controls SDO pin
	SPI2CON1bits.MODE16 = 0; // 8-bit (byte) mode
	SPI2CON1bits.CKE = 1;    // Change output on rising edge (idle to active clock state).
	SPI2CON1bits.CKP = 0;    // Clock idle is at high level.
	SPI2CON1bits.SSEN = 0;   // CS pin (or slave select) is manually controlled.
	SPI2CON1bits.MSTEN = 1;  // Master mode!
	SPI2CON1bits.SMP = 1;    // Sample input bit at middle of data output time.
	slowSCK(); // Slow clock while card is in identification mode.

	SPI2CON2 = 0x0000; // Do not use framed SPI.

	SPI2STATbits.SPIROV = 0; // Reset read overflow flag.
	SPI2STATbits.SPIEN = 1;  // It's go time!

	TRISGbits.TRISG9 = 0; // Set CS (or slave select) I/O port to output mode.
	CS_pin = 1; // Drive CS high, i.e., deselect SD card when not in use
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


void filladdr( unsigned long addr, unsigned char *addr_array )
{
	int k;
	for (k = 0; k < 4; k++)
		*(addr_array+k) = (unsigned char)(addr >> (3-k)*8);
		
}


/* Initialize SD card (return major version number),
   or fail (indicated by return value of -1). */
int initsd()
{
	int k;
	unsigned char indat;
	unsigned char ver[2]; /* ver[0] => version major number;
							 ver[1] => minor number. */

	slowSCK(); /* Slow down SPI clock for SD card init/identification mode. */

	/* Provide ample time to wait for power up and supply ramp up on SD card. */
	delay_kinstr( 4000 ); // 4000 => 100 ms

	CS_pin = 0; // assert CS (i.e., drive pin low)
	for (k = 0; k < 10000; k++)
		rwspi( 0xFF );
		
	CS_pin = 1;
	rwspi( 0xFF );
	CS_pin = 0;
	rwspi( 0xFF );
	
	/* Soft reset into SPI mode. */
	if (cmdsd( CMD0, 100 ) == 0xFF) {
		return -1;
	}
		
	for (k = 0; k < 10000; k++)
		rwspi( 0xFF );

	/* Determine whether card is post or pre specification v2.00 compliant. */
	if ((cmdsd( CMD8, 10 ) & 0x80) ^ 0x80) { // R1 response?
		/* R7 response is 5 bytes long, with first byte being R1
		   type. The last byte should match the sent CMD8 check
		   pattern, in this case 0xAA. */
		for (k = 0; k < 4; k++)
			rwspi( 0xFF ); // Eat the next three bytes
		indat = rwspi( 0xFF );
		if (indat == 0xAA) {
			ver[0] = 2;
			ver[1] = 0;
		} else {
			ver[0] = 1;
			ver[1] = 9;
		}
	} else { // No R7 response found
		ver[0] = 1;
		ver[1] = 9;
	}

	/* Send APP_CMD (prep card for ACMD41) */
	do {
		cmdsd( CMD55, 10 );
		rwspi( 0xFF );
		indat = cmdsd( ACMD41, 10 );
		//indat = cmdsd( CMD1, 10 );
		if (indat == 0xFF) {
			CS_pin = 1;
			printLEDnum( 0x0A );
			while (1) ;
			return -1; // Give up; card failure probably occurred earlier.
		}
		rwspi( 0xFF );
	} while (indat);

	CS_pin = 1; // Deselect SD card

	// Finally, step up SPI clock speed to maximum, 10 MHz
	SPI2STATbits.SPIEN = 0;
	fastSCK();
	SPI2STATbits.SPIEN = 1;
	
	return *ver;
}


/* Assumes buf array has 512 elements. */
int readsd_block( unsigned long addr, unsigned char *buf )
{
	int k;
	unsigned char indat;

	CS_pin = 0;

	rwspi( 0xFF ); /* Pump the clock to ensure card knows it's selected. */

	filladdr( addr, CMD17+1 );

	if ((indat = cmdsd( CMD17, 10 )) == 0xFF) {
		CS_pin = 1;
		printLEDnum( 0x02 );
		while (1) ;
		return -1; // Fail to receive R1 response.
	} else if (indat) {
		CS_pin = 1;
		printLEDnum( 0x03 );
		while (1) ;
		return -1; // Address error, misaligned.
	}

	//for (k = 0; k < 100; k++) {
	for (k = 1; k > 0; k++) {
		indat = rwspi( 0xFF );
		if (indat != 0xFF) {
			if (indat == START_BLOCK) {
				break;
			} else {
				CS_pin = 1;
				printLEDnum( 0x04 );
				while (1) ;
				return -1; // Fail to receive block start indicator; abort.
			}
		}
	}
	if (k < 0) {
		CS_pin = 1;
		printLEDnum( 0x08 );
		while (1) ;
		return -1; // Fail to receive block start indicator; abort.
	}

	/* Read the data block */
	for (k = 0; k < 512; k++)
		*(buf+k) = rwspi( 0xFF );

	// Eat the CRC word
	rwspi( 0xFF );
	rwspi( 0xFF );

	// ...and pump the clock a few times
	rwspi( 0xFF );
	
	CS_pin = 1;
}


/* Assumes buf array has 512 elements. */
int writesd_block( unsigned long addr, unsigned char *buf )
{
	int k;
	unsigned char indat;

	CS_pin = 0;

	rwspi( 0xFF ); /* Pump the clock to ensure card knows it's selected. */

	filladdr( addr, CMD24+1 );

	if ((indat = cmdsd( CMD24, 10 )) == 0xFF) {
		CS_pin = 1;
		printLEDnum( 0x02 );
		while (1) ;
		return -1; // Fail to receive R1 response.
	} else if (indat) {
		CS_pin = 1;
		printLEDnum( 0x03 );
		while (1) ;
		return -1; // Address error, misaligned.
	}

	rwspi( 0xFF );  // Give SD card 8 clock cycles (per spec v1.9)
	
	rwspi( START_BLOCK ); // Start the single block write operation

	/* Write the data block */
	for (k = 0; k < 512; k++) {
		indat = rwspi( *(buf+k) );
		if (indat != 0xFF) {
			CS_pin = 1;
			printLEDnum( 0x04 );
			while (1) ;
			return -1; /* Something failed; SD card should not have interrupted the write operation. */
		}
	}

	// Generate bogus CRC16 for this block
	rwspi( 0xAA );
	rwspi( 0xAA );
	
	/* Process data response and wait for SD card to finish writing. */
	indat = rwspi( 0xFF );
	if ((indat & 0x1F) != DATA_ACCEPTED) {
		CS_pin = 1;
		printLEDnum( 0x08 );
		while (1) ;
		return -1; /* Data write failed (for some reason that can be determined by other means) */
	}
	while (rwspi( 0xFF ) != 0xFF) ; // Wait for busy signal to cease.

	// ...and pump the clock a few times
	rwspi( 0xFF );
	
	CS_pin = 1;
}


unsigned char cmdsd( unsigned char *cmd, int max_tries )
{
	/* We assume, per the SD card specifications, that the MISO line
	   is held high by the SD card until a response is
	   generated. Hence, it suffices to check whether the read byte is
	   0xFF. */

	int k;
	unsigned char indat;
	for (k = 0; k < COMMAND_LEN; k++)
		rwspi( *(cmd+k) );
	for (k = 0; k < max_tries; k++) {
		indat = rwspi( 0xFF ); // pump clock... where is my card response?
		if (indat != 0xFF)
			return indat; // Found response; return it.
	}
	return 0xFF; // Fail
}


int main( void )
{
	unsigned int i;
	unsigned int status;
	unsigned char buf_in[512], buf_out[512];

	set_clk40MHz(); /* Set Fcy to 40 MHz; note that timing of SPI SD
					   card interface assumes this clock setting
					   succeeded. */

	TRISC = 0x0000; // Entire Port C functions as output
	printLEDnum( 0x0 ); // Clear LEDs

	initspi();
	if (initsd() < 0) {
		// Failed to initialize SD card; give up
		printLEDnum( 0x01 );
		while (1) ;
	}

	for (i = 0; i < 512; i++) { // Clear buffer blocks
		buf_in[i] = 0x00;
		buf_out[i] = (unsigned char)i;
	}
	
	//printLEDnum( 0xFF );
	//for (i = 0; i < 4*4096; i++) {
	
	//if (writesd_block( (unsigned long)i * 512, buf_out ) < 0) {
	/*if (writesd_block( 0x00000000, buf_out ) < 0) {
		// Failed to read desired block.
		printLEDnum( 0x02 );
		while (1) ;
	}
	*/
	
	//}
	//printLEDnum( 0x00 );
	
	if (readsd_block( 360448, buf_in ) < 0) {
		// Failed to read desired block.
		printLEDnum( 0x02 );
		while (1) ;
	}
	
	for (i = 0; i < 6; i++) {
		printLEDnum( *(CMD17+i) );
		delay_kinstr( 2000 );
	}
	printLEDnum( 0x00 );
	
	for (i = 0; i < 512; i++) {
		printLEDnum( buf_in[i] );
		delay_kinstr( 2000 ); // 2000 => .5 s
	}

	return 0;
}
