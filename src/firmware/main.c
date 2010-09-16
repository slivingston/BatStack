/*
 * The Batlab Microphone Array Project (or the "BatStack")
 *
 *
 * File: main.c
 *
 * Authors: Scott Livingston and Murat Aytekin,
 *         Auditory Neuroethology Lab (BatLab)
 *         University of Maryland, College Park.
 *
 * September-November 2009; January, April-July 2010.
 *
 *
 * Partial hardware notes:
 *   - MCU/DSC:    dsPIC33FJ128GP710
 *   - Oscillator: XT 10.000MHz
 *   - Compiler:   MPLAB C30; Microchip v3.23
 *
 * NOTES: - Design notes:
 *           - long (int) variables are stored in little endian on the
 *             SD card. In particular, this occurs for values stored
 *             in the SD header (e.g., numberp of trials recorded).
 *           - Even if recording/trial parameters are loaded from the
 *             attached SD card, the firmware build date remains unchanged.
 *
 *        - Design notes above and scattered throughout source code
 *          within block comments should be placed in some sort of
 *          design/tech report/documentation.
 *
 *        - As of 22 November 2009, a new SD card storage system is in
 *          place. No traditional filesystem is supported and, in
 *          particular, data is written to the MBR, i.e., this program
 *          WILL CORRUPT YOUR FORMATTED SD CARDS. Be wary of where you
 *          insert your stick! Use the sdprep (under util/sdprep) to
 *          initialize an SD card for use here.
 *          
 *        - Once an SD card is associated with a BatStack (i.e., the
 *          stack ID is written to it), the program build date --once
 *          written-- is never altered. Consider changing this
 *          behavior.
 *
 *        - As noted other places, header fields are in little endian
 *          (when multi-byte).
 *
 *        - Though a new or updated SD card header is constructed in
 *          RAM prior to the first trial capture --in particular, a
 *          foster card may become tagged with the ID of this
 *          program--, it is not written to the card until the trial
 *          data transfer process begins (i.e., at beginning of
 *          transfer of just recorded trial data from SRAM to SD
 *          card).
 *
 *        - Many calculations can be simplified by noting that a DMA
 *          transfer block has 512 words and an SD card sector has 512
 *          bytes (by definition). In particular, we can use
 *          NUM_DMABLOCKS_PER_SRAM to immediately get the number of
 *          sectors in a single SRAM unit by 2*NUM_DMABLOCKS_PER_SRAM.
 *
 *        - Addressing of the SRAM units is achieved by combining
 *          [PORTB<15:4>][PORTE<7:0>],
 *          yielding a 20 bit address (because of word addressing, this implies
 *          a size of 1 Mword per unit).
 *
 *        - Since DSADR only specifies the offset of the last DMA DPSRAM write,
 *          we use the MSb as a flag to indicate whether we are currently copying
 *          data from SRAM to the SD card. i.e.,
 *
 *              DMAptr_at_trigger<15> = 1 implies we are reading from the SRAM units
 *                                      (thus prevent DMA5 ISR writes to it);
 *              otherwise, record A/D data to the SRAM units as usual.
 *
 */


#include "env.h"
#include "utils.h"
#include "sdcard.h"
#include "comm.h"


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


/* ADC Initialization */
/* The current configuration (as of 18 Jan 2010) yields a (empirically measured)
   total A/D sampling period of 3.75 us; this is also observed by a DMA block transfer
   period of approx. 480 us. */
void init_adc1( void )
{
    AD1PCFGH = 0xFFFF;
    AD1PCFGL = 0xFFF0;

    AD1CON1 = 0x0000; /* Tabla rasa */
    AD1CON2 = 0x0000;
    /* We leave AD12B (i.e. AD1CON1<10>) cleared to
       indicate 10-bit, 4-channel operation;
       For FORM (i.e. AD1CON1<9:8>),
       00 implies unsigned integer data output. */
    
    AD1CON1bits.ADDMABM = 1; /* DMA buffer write in order of conversion. */
    AD1CON1bits.SSRC = 7; /* Auto-convert (using internal counter). */
    AD1CON1bits.SIMSAM = 1; /* Simultaneous sampling. */
    AD1CON1bits.ASAM = 1; /* Auto-set SAMP bit. At this point, the ADC1 module
                             will cycle through sample/hold and conversion
                             steps ad infinitum. */
                             
    AD1CON2bits.CHPS = 2; /* Convert CH0, CH1, CH2 and CH3. */
    /* Note that we leave SMPI (i.e. AD1CON2<5:2>) cleared so that the
       DMA buffer records every conversion result. */
       
    AD1CON3bits.ADRC = 0; /* ADC conversion clock is controlled below to achieve 250 ksps.
                             Note that the configuration here assumes Tcy = 25 ns (i.e. 80 MHz Fosc). */
    AD1CON3bits.ADCS = 0x2; /* Tad = 3*Tcy = 75 ns. */
    AD1CON3bits.SAMC = 0x2; /* Tsmp = 2*Tad = 150 ns */
    
    /* Set the pin mapping to ADC channels as follows:
           AN0 --> CH1,
           AN1 --> CH2,
           AN2 --> CH3, and
           AN3 --> CH0.
    */
    AD1CHS123 = 0x0000;
    AD1CHS0 = 0x0003;
    
    IFS0bits.AD1IF = 0; /* Initially clear ADC interrupt flag */
    IEC0bits.AD1IE = 0; /* ...and disable such interrupts. */
        
}


/* DMA Initialization */
void init_dma5( void )
{
    /* Word size, peripheral-to-DPSRAM, complete block interrupt,
       register indirect with post-increment addressing, and
       continuous, ping-pong modes. */
    DMA5CON = 0x0002;

    /* Base addresses on 16kB device are 0x4000 and 0x4400;
       thus, each block transfer should be 512 words long. */
    DMA5STA = __builtin_dmaoffset(DMAbufA);
    DMA5STB = __builtin_dmaoffset(DMAbufB);
    
    DMA5PAD = 0x0300; /* ADC1BUF0 */
    DMA5CNT = (DMA_BLOCK_LEN-1);

    DMA5REQ = 13; /* ADC1 IRQ number */

    /* Clear the DMA5 interrupt flag,
       and enable DMA5 interrupts. */
    IFS3bits.DMA5IF = 0;
    IEC3bits.DMA5IE = 1;

    dmablock_flag = 0; /* Always begin with transfer block A. */
    DMA5CONbits.CHEN = 1; /* Light it up! (i.e., enable this DMA channel.)*/
}


/* Preparation for writing to SRAM units */
void init_SRAM_write()
{
    /* Address */
    TRISB = 0x000F; /* Lower 4 bits are set because they are pins AN0 thru AN3. */
    TRISE = 0x0000;
    
    /* Controls */
    TRISA = 0x0000;   // Read/write, chip select, 1 Mword select output
    
    /* Data */
    TRISD = 0x0000;               // PORTD is output for Data
    LATB = 0;                     // Address 7= 0
    LATE = 0;                     // Address = 0
    LATD = 0;
    LATA = 0x8002;
    /*LATAbits.LATA14 = 0;          // CE1
    LATAbits.LATA4 = 0;           // CE2.1
    LATAbits.LATA3 = 0;           // CE2.2
    LATAbits.LATA2 = 0;           // CE2.3
    LATAbits.LATA1 = 1;           // CE2.4
    LATAbits.LATA15 = 1;          // WE    1:Write disable
    LATAbits.LATA9 = 0;           // OE
    LATAbits.LATA13 = 0;          // BHE
    LATAbits.LATA12 = 0;          // BLE
    */
    
    sram_unit = 0;
}


/* Preparation for reading from SRAM units */
void init_SRAM_read()
{
    LATD = 0;

    /* Address */
    TRISB = 0x000F; /* Lower 4 bits are set because they are pins AN0 thru AN3. */
    TRISE = 0x0000;

    /* Controls */
    TRISA = 0x0000;   // Read/write, chip select, 1MxWord select

    /* Data */
    TRISD = 0xFFFF;               // PORTD is input for Data

    LATB = 0;
    LATE = 0;
    LATA = 0x8202;
    /*LATAbits.LATA14 = 0;          // CE1
    LATAbits.LATA4 = 0;           // CE2.1
    LATAbits.LATA3 = 0;           // CE2.2
    LATAbits.LATA2 = 0;           // CE2.3
    LATAbits.LATA1 = 1;           // CE2.4

    LATAbits.LATA15 = 1;          // WE    1:Write disable
    LATAbits.LATA9 = 1;           // OE    0: Output enable, 1: Output disable
    LATAbits.LATA13 = 0;          // BHE
    LATAbits.LATA12 = 0;          // BLE
    */

    sram_unit = 0;
}


int main()
{

    unsigned int k, j;

	unsigned long start_sectorptr; /* Facilitates abortion of last recording trigger. */


	////////////////////
	// Default values
	////////////////////
	posttrigger_len = 0;
	trigger_hit = 0;
	first_int_since_trigger = 1;
	for (k = 0; k < 4; k++) {
		*(SRAMchipW+k) = 0x8000 + (0x2<<k);
		*(SRAMchipR+k) = 0x8200 + (0x2<<k);
	}
	DMAptr_at_trigger=0;
	sram_unit=0;
	batstack_id = 0x05;
	build_date = 0x50E5; // 2010 July 5
	swidth_mactive = 0xAF;
	sample_period = 375;
	sectorptr = 2;
	dmablock_flag = 0;

	TRISG &= 0xfc3f;

    
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


    // Trigger button setting (and LEDs)
    TRISC = 0x0002;
    PORTC = 0;

	/* Disable all A/D pins except AN0:3
	   This is done in init_adc1 but seems cleaner here. */
	AD1PCFGH = 0xFFFF;
    AD1PCFGL = 0xFFF0;

    init_SRAM_write();
    num_dmablocks = NUM_DMABLOCKS_PER_SRAM;
    init_adc1();
    init_dma5(); /* Initialize DMA channel to buffer ADC data in conversion order. */
    AD1CON1bits.ADON = 1; /* Start the ADC1 module! */
    /* Initialize the A/D converter module; note that we must not initialize
       the ADC module before the DMA channel 5 is ready; otherwise we may
       fall out of sync (and thus invalidate the assumption that DMA transfer
       block addresses are such that
       0 mod 4 is CH0,
       1 mod 4 is CH1,
       2 mod 4 is CH2, and
       3 mod 4 is CH3, i.e. interleaved).
    */
    initspi();
    if (initsd() < 0) {
		// Failed to initialize SD card; give up
		printLEDnum( 0x4 );
		while (1) ;
	}
	sdcard_read_hdr();
    DMAptr_at_trigger = 0;

    while (1) {
    
		/* Verify space availability on SD card. This is a poor method
           to track or restrict space usage and only used temporarily
           for quick testing. */
        if (total_trials > 64) {
            toggle_LEDs_forever();
        }

        /* Wait for trigger. */
		printLEDnum( 0x00 );
		k = 0;
		j = 0;
		while (!TRIGGER) { /* Wait for trigger (Port C1 pin driven up to Vdd). */
			k++;
			if (k > 1000) {
				j++;
				k = 0;
				if (j > 1000) {
					LED2 ^= 1; /* Waiting for trigger indicator */
					j = 0;
				}
			}
        }
		__asm__ volatile ( "DISI #0x3FFF" );
		/* Temporarily block interrupts with priority level < 7;
           in particular, DMA5 channel block transfer handler. */
        DMAptr_at_trigger = DSADR; /* Trigger point. */
        DMAptr_at_trigger &= 0x07F8; /* Clear lower 3 bits to ensure
                                        alignment with 4-sample group
                                        (because there are 4 mic
                                        channels). */
        
        trigger_hit = 1; /* Flag that we just received trigger signal */
        LED1 = 1; /* Echo this on pin RC3. */
		__asm__ volatile ( "DISI #0" ); /* Unblock all interrupts. */
        while (trigger_hit) ;
            
        LED1 = 0; /* Indicate recording complete. */
        first_int_since_trigger = 1; /* In preparation for the next trial capture. */

        /* Add this trial to the SD card.
		   */
		start_sectorptr = sectorptr;
        sdcard_transfer_data();
		sdcard_hdr_addtrial( start_sectorptr, 0xDEAD,
							 0xBEEF,
							 posttrigger_len );
		/* Note that we do not update the SD card header with this new
		   trial until after copying has completed. This is to improve
		   confidence in results and more easily allow trial recording
		   abortions. */

        __asm__ volatile ( "DISI #0x3FFF" );
        init_SRAM_write(); /* Reset DMA/SRAM unit writing related stuff. */
        num_dmablocks = NUM_DMABLOCKS_PER_SRAM;
        DMAptr_at_trigger = 0; /* Unlock SRAM units, begin capturing A/D data stream again. */
        __asm__ volatile ( "DISI #0" );

    }
    
    AD1CON1bits.ADON = 0;
    DMA5CONbits.CHEN = 0;
    printLEDword( DMAptr_at_trigger );

	return 0;
}
