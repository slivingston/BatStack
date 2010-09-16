/* sdcard.c
 *
 *
 * Scott Livingston
 * Apr 2010.
 *
 */


#include "env.h"
#include "sdcard.h"


/* Read SD card header */
void sdcard_read_hdr()
{
    unsigned int trialstartsect[2]; /* little endian; this simplifies
									   inline assembly block below. */
	unsigned char load_params_flag = 0; /* 0 => set to default values;
										   1 => read parameters from SD card header.
										*/

	/* Only read sector 0 here, pull in sector 1 if necessary (i.e. if
	   total_trials*12+8 >= 512). */
    /*if (readsd_block( 0, sdheader ) < 0) {
        printLEDnum( 4 );
		while (1) ;
		}*/
	/* We must write out the function call to readsd_block explicitly
	   here because the C30 compiler (Microchip's port of GCC to its
	   line of 16-bit PIC microcontrollers) fucks up if we let it
	   convert the C call to assembly. */
	__asm__ volatile ( "clr w0\n\t"
					   "clr w1\n\t"
					   "mov #%[sdhdr], w2\n\t"
					   "call _readsd_block\n\t"
					   "cp0 w0\n\t"
					   "bra GE, L_sdheadrd1\n\t"
					   "mov #0x4, w0\n\t"
					   "call _printLEDnum\n\t"
					   "bra .\n\t"
					   "L_sdheadrd1: nop"
					   :
					   : [sdhdr] "g"(sdheader)
					   : "w0", "w1", "w2" );

    /* If BatStack ID is 0x00 in this SD card, then write this Stack's ID to it
       (and thus formally associate with it). */
    if (*sdheader == 0x00) {
        *sdheader = batstack_id;
        *(sdheader+1) = build_date & 0xff;
        *(sdheader+2) = (build_date >> 8) & 0xff;
		load_params_flag = 0; // Use default parameters
    } else if (*sdheader != batstack_id) { /* Do not commit adultery. Abort program. */
       toggle_LEDs_forever();
		while (1) ;
    } else { /* BatStack ID match; check sample period to see whether
			    parameters in header are valid. */
		if (*(sdheader+4) == 0 && *(sdheader+5) == 0) {
			load_params_flag = 0; // Use defaults
		} else {
			load_params_flag = 1; // Load parameters from header.
		}
	}
    if (load_params_flag) {
		swidth_mactive = *(sdheader+3);
		sample_period = *(sdheader+4);
		sample_period |= (*(sdheader+5))<<8;
		posttrigger_len = *(sdheader+6);
		posttrigger_len |= (*(sdheader+7))<<8;
	} else {
		*(sdheader+3) = swidth_mactive & 0xff;
		*(sdheader+4) = sample_period & 0xff;
		*(sdheader+5) = (sample_period>>8) & 0xff;
		*(sdheader+6) = posttrigger_len & 0xff;
		*(sdheader+7) = (posttrigger_len>>8) & 0xff;
	}

    total_trials = *(sdheader+8) & 0xff;

	/*if (readsd_block( 1, sdheader+512 ) < 0) {
		printLEDnum(4);
		while (1) ;
		}*/
	/* See notes above about why I need to write call to readsd_block
	   myself (in assembly). */
	__asm__ volatile ( "mov #1, w0\n\t"
					   "clr w1\n\t"
					   "mov #%[sdhdr], w2\n\t"
					   "mov #512, w3\n\t"
					   "add w3, w2, w2\n\t"
					   "call _readsd_block\n\t"
					   "cp0 w0\n\t"
					   "bra GE, L_sdheadrd2\n\t"
					   "mov #0x4, w0\n\t"
					   "call _printLEDnum\n\t"
					   "bra .\n\t"
					   "L_sdheadrd2: nop"
					   :
					   : [sdhdr] "g"(sdheader)
					   : "w0", "w1", "w2", "w3" );
    
    /* Finally, set sector pointer as appropriate (to avoid
	   overwriting prior trial data). */
    if (total_trials > 0) {
        /* This bit of assembly code is used to efficiently determine the
           last trial start sector number listed in the SD card header.
           If you use a shift-and-bitmask approach in C, then the compiler
           will give you ugly and excessive code. */
        __asm__ volatile ( "mov %[total], w1\n\t"
						   "ze w1, w1\n\t"
						   "mul.uu w1, #12, w2\n\t"
						   "mov w2, w1\n\t"
						   "sub #3, w1\n\t"
						   "mov #%[sdhdr], w0\n\t"
						   "add w1, w0, w1\n\t"
						   "mov.b [w1+#1], w2\n\t"
						   "sl w2, #8, w2\n\t"
						   "mov.b [w1], w2\n\t"
						   "mov w2, %[tstart0]\n\t"
						   "inc2 w1, w1\n\t"
						   "mov.b [w1+#1], w2\n\t"
						   "sl w2, #8, w2\n\t"
						   "mov.b [w1], w2\n\t"
						   "mov w2, %[tstart1]"
						   : [tstart0] "=g"(*trialstartsect), [tstart1] "=g"(*(trialstartsect+1))
						   : [sdhdr] "g"(sdheader), [total] "g"(total_trials)
						   : "w0", "w1", "w2", "w3", "w4" );
        __asm__ volatile ( "mov %[tstart0], w0\n\t"
						   "mov %[tstart1], w1\n\t"
						   "mov #%[sectorptr], w2\n\t"
						   "mov w0, [w2++]\n\t"
						   "mov w1, [w2]"
						   : [sectorptr] "=g"(sectorptr)
						   : [tstart0] "g"(*trialstartsect), [tstart1] "g"(*(trialstartsect+1))
						   : "w0", "w1", "w2" );
        sectorptr += NUM_DMABLOCKS_PER_SRAM*2*NUM_SRAM_UNITS;
    } else {
        sectorptr = 2;
    }
}


/* Add new trial entry to SD card header.
   Note that this function increments total_trials. */
void sdcard_hdr_addtrial( unsigned long trialstartsect, unsigned int trial_date,
						  unsigned int trial_dsec, unsigned int trial_postlen )
{
    total_trials++;
    *(sdheader+8) = total_trials;
    *(sdheader + (total_trials*12 - 3)) = trialstartsect & 0xff;
    *(sdheader + (total_trials*12 - 3) + 1) = (trialstartsect >> 8) & 0xff;
    *(sdheader + (total_trials*12 - 3) + 2) = (trialstartsect >> 16) & 0xff;
    *(sdheader + (total_trials*12 - 3) + 3) = (trialstartsect >> 24);

	// timestamp
	*(sdheader + (total_trials*12 - 3) + 4) = trial_date & 0xff;
	*(sdheader + (total_trials*12 - 3) + 5) = (trial_date>>8) & 0xff;
	*(sdheader + (total_trials*12 - 3) + 6) = trial_dsec & 0xff;
	*(sdheader + (total_trials*12 - 3) + 7) = (trial_dsec>>8) & 0xff;
	
	// trial postlen
	*(sdheader + (total_trials*12 - 3) + 8) = trial_postlen & 0xff;
	*(sdheader + (total_trials*12 - 3) + 9) = (trial_postlen>>8) & 0xff;

	// last field is reserved for future use
	*(sdheader + (total_trials*12 - 3) + 10) = *(sdheader + (total_trials*12 - 3) + 11) = 0;
    
    /* Write current header to SD card. */
    /*if (writesd_block( 0, sdheader ) < 0) {
        toggle_LEDs_forever();
		}*/
	/* See notes above about why I need to write call to writesd_block
	   myself (in assembly). */
	__asm__ volatile ( "clr w0\n\t"
					   "clr w1\n\t"
					   "mov #%[sdhdr], w2\n\t"
					   "call _writesd_block\n\t"
					   "cp0 w0\n\t"
					   "bra GE, L_sdheadwr1\n\t"
					   "mov #0x4, w0\n\t"
					   "call _printLEDnum\n\t"
					   "bra .\n\t"
					   "L_sdheadwr1: nop"
					   :
					   : [sdhdr] "g"(sdheader)
					   : "w0", "w1", "w2" );
	/*if (writesd_block( 1, sdheader+512 ) < 0) {
        toggle_LEDs_forever();*/
	__asm__ volatile ( "mov #1, w0\n\t"
					   "clr w1\n\t"
					   "mov #%[sdhdr], w2\n\t"
					   "mov #512, w3\n\t"
					   "add w3, w2, w2\n\t"
					   "call _writesd_block\n\t"
					   "cp0 w0\n\t"
					   "bra GE, L_sdheadwr2\n\t"
					   "mov #0x4, w0\n\t"
					   "call _printLEDnum\n\t"
					   "bra .\n\t"
					   "L_sdheadwr2: nop"
					   :
					   : [sdhdr] "g"(sdheader)
					   : "w0", "w1", "w2", "w3" );
}


/* Data transfer to SD card from SRAM */
void sdcard_transfer_data()
{
    int n;
    unsigned int data;
    unsigned int offset;
    int transfer_done = 0; /* Flag to indicate when we are done transfering. */
	unsigned char buf[SECTOR_LEN];

    init_SRAM_read();
    
    printLEDnum( 0x00 ); /* Clear the LEDs from whatever prior state they were in. */
    
    /* Initialize at the pivot point and cycle over all SRAM units. */
    sram_unit = *sram_trig_addr >> 14;
    num_dmablocks = *(sram_trig_addr+1);
    offset = 0x3FFF & *sram_trig_addr;
    LATE = 0x00FF & offset;
    LATB = (NUM_DMABLOCKS_PER_SRAM - num_dmablocks) << 5;
    LATB |= (0x0100 & offset) >> 4;
    
    n = 0;
    while (1) {
    
        LED1 ^= 1; /* Twiddle port RC3 for each sector written to the SD card. */
    
        while (offset < DMA_BLOCK_LEN) {
            /*
             * Read SRAM data
             */
            /* LATAbits.LATA5 = 0;     // This enables 74LVT125 buffers
            //LATAbits.LATA5 = 1;     // This enables 74LVT124 buffers (Data is written to second SRAM board, if exists)
            */

            LATAbits.LATA9 = 0;   // SRAM output enable
            // stall for 4 instructions (100 ns, assuming 25 ns instruction cycle period)
            NOP;
            NOP;
            NOP;
            NOP;
            data = PORTD & 0x03ff; /* Data is read from the port and upper 6 bits are ignored (via mask). */
            //data = n;
            LATAbits.LATA9 = 1;        // SRAM output disable

            // stall for 2 instructions (50 ns)
            NOP;
            NOP;

            if (LATE == 0x00FF) {
                LATB += 0x0010;
                LATE = 0x0000;
            } else {
                LATE++;
            }
            
            buf[n] = (data & 0x00FF); // Write data to buffer
            buf[n+1] = (data >> 8);
            n += 2;
            
            if (n == 512) {
                /*if (writesd_block( sectorptr++, buf ) < 0) {
                    toggle_LEDs_forever();
					}*/
				/* See notes above about why I need to write call to writesd_block
				   myself (in assembly). */
				__asm__ volatile ( "mov #_sectorptr, w2\n\t"
								   "mov [w2++], w0\n\t"
								   "mov [w2], w1\n\t"
								   "mov %[buf], w2\n\t"
								   "call _writesd_block\n\t"
								   "cp0 w0\n\t"
								   "bra GE, L_datasdwr1\n\t"
								   "mov #0x4, w0\n\t"
								   "call _printLEDnum\n\t"
								   "bra .\n\t"
								   "L_datasdwr1: nop"
								   :
								   : [buf] "g"(buf), [sptr] "g"(sectorptr)
								   : "w0", "w1", "w2" );
				sectorptr++;
                n = 0; /* Reset sector byte counter. */
            }
            
            offset++;
            
            if (sram_unit == (*sram_trig_addr) >> 14
                && num_dmablocks == *(sram_trig_addr+1) && offset == (*sram_trig_addr & 0x01FF)) {
                transfer_done = 1;
                break;
            }
        }
        if (transfer_done)
            break;
        num_dmablocks--;
        offset = 0;
        
        if (num_dmablocks == 0) {  /* Time to change SRAM units? */
            sram_unit++;
            if (sram_unit >= NUM_SRAM_UNITS)
                sram_unit = 0;
            num_dmablocks = NUM_DMABLOCKS_PER_SRAM;
            LATA = SRAMchipW[sram_unit];
            LATB = 0x0000;
            LATE = 0x0000;
        }
    
    }

}
