/* sdspi.h
 *
 * Scott Livingston <slivingston@caltech.edu>,
 * October 2009.
 *
 */


#include "utils.h"
#include "sdspi.h"


/* SD card commands (all 6 bytes long; CRC ignored by default for all but CMD0 in SPI mode). */
unsigned char CMD0[] = { 64, 0x00, 0x00, 0x00, 0x00, 0x95 }; // GO_IDLE_STATE
unsigned char CMD8[] = { 72, 0x00, 0x00, 0x01, 0xAA, 0xFF }; // SELF_IF_COND (only for SD card spec v2.x)
unsigned char CMD55[] = { 119, 0x00, 0x00, 0x00, 0x00, 0xFF }; // APP_CMD
unsigned char ACMD41[] = { 105, 0x00, 0x00, 0x00, 0x00, 0xFF }; // SD_SEND_OP_COND
unsigned char CMD1[] = { 65, 0x00, 0x00, 0x00, 0x00, 0xFF }; // SD_SEND_OP_COND
unsigned char CMD17[] = { 81, 0x00, 0x00, 0x00, 0x00, 0xFF }; // READ_SINGLE_BLOCK; address to be filled later
unsigned char CMD24[] = { 88, 0x00, 0x00, 0x00, 0x00, 0xFF }; // WRITE_BLOCK; address to be filled later


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
	IFS2bits.SPI2IF = 0;
	IEC2bits.SPI2IE = 0; // Disable SPI2 interrupts

	SPI2STATbits.SPIEN = 0;  // Disable SPI module 2 while we configure it.

	SPI2CON1bits.DISSCK = 0; // Module controls SCK pin
	SPI2CON1bits.DISSDO = 0; // Module controls SDO pin
	SPI2CON1bits.MODE16 = 0; // 8-bit (byte) mode
	SPI2CON1bits.CKE = 1;    // Change output on falling edge.
	SPI2CON1bits.CKP = 0;    // Clock idle is at low level.
	SPI2CON1bits.SSEN = 0;   // CS pin (or slave select) is manually controlled.
	SPI2CON1bits.MSTEN = 1;  // Master mode!
	SPI2CON1bits.SMP = 1;    // Sample input bit at middle of data output time.
	slowSCK(); // Slow clock while card is in identification mode.

	SPI2CON2 = 0x0000; // Do not use framed SPI.

	SPI2STATbits.SPIROV = 0; // Reset read overflow flag.
	SPI2STATbits.SPIEN = 1;  // It's go time!
	
	//TRISGbits.TRISG9 = 0; // Set CS (or slave select) I/O port to output mode.
	CS_pin = 1; // Drive CS high, i.e., deselect SD card when not in use
}


unsigned char rwspi( unsigned char outdat )
{
	unsigned char indat;
	
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
			return -1; // Give up; card failure probably occurred earlier.
		}
		rwspi( 0xFF );
	} while (indat);

	CS_pin = 1; // Deselect SD card

	// Finally, step up SPI clock speed to maximum, 10 MHz
	SPI2STATbits.SPIEN = 0;
	__asm__ volatile ( "nop" ); // Possibly necessary time delays for re-config?
	__asm__ volatile ( "nop" );
	fastSCK();
	__asm__ volatile ( "nop" );
	SPI2STATbits.SPIEN = 1;
	
	return *ver;
}


/* Assumes buf array has 512 elements. */
int readsd_block( unsigned long sector_addr, unsigned char *buf )
{
	int k;
	unsigned char indat;

	CS_pin = 0;

	rwspi( 0xFF ); /* Pump the clock to ensure card knows it's selected. */

	filladdr( sector_addr*512, CMD17+1 );

	if ((indat = cmdsd( CMD17, 10 )) == 0xFF) {
		CS_pin = 1;
		return -1; // Fail to receive R1 response.
	} else if (indat) {
		CS_pin = 1;
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
				return -1; // Fail to receive block start indicator; abort.
			}
		}
	}
	if (k < 0) {
		CS_pin = 1;
		return -1; // Fail to receive block start indicator; abort.
	}

	/* Read the data block */
	for (k = 0; k < 512; k++)
		*(buf+k) = rwspi( 0xFF ); //trap

	// Eat the CRC word
	rwspi( 0xFF );
	rwspi( 0xFF );

	// ...and pump the clock a few times
	rwspi( 0xFF );
	
	CS_pin = 1;
	return 0;
}


/* Assumes buf array has 512 elements. */
int writesd_block( unsigned long sector_addr, unsigned char *buf )
{
	int k;
	unsigned char indat;

	CS_pin = 0;

	rwspi( 0xFF ); /* Pump the clock to ensure card knows it's selected. */

	filladdr( sector_addr*512, CMD24+1 );

	if ((indat = cmdsd( CMD24, 10 )) == 0xFF) {
		CS_pin = 1;
		return -1; // Fail to receive R1 response.
	} else if (indat) {
		CS_pin = 1;
		return -1; // Address error, misaligned.
	}

	rwspi( 0xFF );  // Give SD card 8 clock cycles (per spec v1.9)
	
	rwspi( START_BLOCK ); // Start the single block write operation

	/* Write the data block */
	for (k = 0; k < 512; k++) {
		indat = rwspi( *(buf+k) );
		if (indat != 0xFF) {
			CS_pin = 1;
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
		return -1; /* Data write failed (for some reason that can be determined by other means) */
	}
	while (rwspi( 0xFF ) != 0xFF) ; // Wait for busy signal to cease.

	// ...and pump the clock a few times
	rwspi( 0xFF );
	
	CS_pin = 1;
	return 0;
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
