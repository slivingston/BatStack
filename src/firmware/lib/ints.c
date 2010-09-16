/* ints.c
 * 
 * Contains definitions of interrupt service routines (ISRs).
 * Note that this includes ISRs for (non-maskable) traps.
 *
 * Scott Livingston <slivingston@caltech.edu>
 * Jan, Apr 2010.
 *
 */


#include "env.h"


/*
* DMA5 (i.e., DMA channel 5) ISR for ADC1 block transfers (peripheral-to-SRAM in this case).
*/
//void __attribute__ ((__interrupt__(__irq__(61)))) DMA5Int()
void _ISR __attribute__((auto_psv)) _DMA5Interrupt( void )
{

    unsigned int offset = 0; /* ...for this particular transfer block. This variable is used
                                to keep track of where we are; it must be that
                                0 <= offset < DMA_BLOCK_LEN. */
	unsigned int *adc_dataptr;
    
    IFS3bits.DMA5IF = 0;  /* Clear interrupt flag */
    if (dmablock_flag == 0) { /* Interrupt to service transfer block A. */
        adc_dataptr = DMAbufA;
    } else { /* Interrupt to service transfer block B. */
        adc_dataptr = DMAbufB;
    }
    dmablock_flag ^= 1; /* Toggle transfer block indicator. */
	//LED4 = dmablock_flag;
    
    if (DMAptr_at_trigger & 0x8000) {
        /* Currently we are copying contents of SRAM units to the SD card.
           Ignore this A/D data block. */
        return;
    }

    if (trigger_hit) { /* Post-trigger period. */

        if (first_int_since_trigger) {
        
            first_int_since_trigger = 0; /* Clear this flag. */
            
            DMAptr_at_trigger &= 0x03FF; /* Mask to achieve offset w.r.t. a DMA RAM offset. */
            DMAptr_at_trigger = DMAptr_at_trigger >> 1; /* Use word addressing. */
            
            /* Now we must calculate the SRAM unit address corresponding to the trigger time.
               This serves as a pivot point for recording any remaining A/D samples and later
               transfering from the SRAM units to the SD card. It is referenced as time 0 (in seconds). */
            *sram_trig_addr = DMAptr_at_trigger;
            offset = sram_unit; /* We briefly co-opt offset for calculating the SRAM unit on which to stop recording. */
            *(sram_trig_addr+1) = (posttrigger_len << 1) + NUM_DMABLOCKS_PER_SRAM - num_dmablocks;
            while (*(sram_trig_addr+1) >= NUM_DMABLOCKS_PER_SRAM) {
                *(sram_trig_addr+1) -= NUM_DMABLOCKS_PER_SRAM;
                offset++;
            }
            *(sram_trig_addr+1) = NUM_DMABLOCKS_PER_SRAM - *(sram_trig_addr+1);
            if (offset >= NUM_SRAM_UNITS)
                offset -= NUM_SRAM_UNITS;
            *sram_trig_addr |= offset << 14; /* whence sram_trig_addr<15:14> = [sram unit on which to stop]<1:0> */
            
            /* Handle the special case where posttrigger_len = 4096, i.e., pure start-trigger mode.
               This means we should dump the current block and ignore the pivot point. */
            if (posttrigger_len == 4096) {
            
                for (offset = 0; offset < DMA_BLOCK_LEN; offset++) {
                    /*
                     * Write Data
                     */
                    /*LATAbits.LATA5 = 0;     // This enables 74LVT125 buffers (Data is written to first SRAM board)
                    //LATAbits.LATA5 = 1;     // This enables 74LVT124 buffers (Data is written to second SRAM board, if exists)
                    */
                    
                    LATD = *(adc_dataptr + offset);
                    LATAbits.LATA15 = 0;      // A15 = 0 implies Write Enable
                    /* Here we supposedly need a delay for 2 instruction cycles before writing to SRAM unit. */
                    NOP;
                    NOP;
                    
                    LATAbits.LATA15 = 1;       // Write Disable

                    if (LATE == 0x00FF) {
                        LATB += 0x0010;
                        LATE = 0x0000;
                    } else {
                        LATE++;
                    }
                }
                num_dmablocks--;
                
            } else {
            
                /* Dump current DMA transfer block, watch for the pivot address.
                   This for loop is identical to that below (all transfers after
                   the first following the trigger), but is copied here to reduce
                   ISR execution time for those other non-first instances. */
                for (offset = 0; offset < DMA_BLOCK_LEN; offset++) {
                    /*
                     * Write Data
                     */
                    if (sram_unit == (*sram_trig_addr) >> 14 && num_dmablocks == *(sram_trig_addr+1) && offset == (*sram_trig_addr & 0x01FF)) {
                        /* Yes, this is the pivot point. We are done recording this trial. */
                        trigger_hit = 0;
                        DMAptr_at_trigger = 0x8000;
                        return; /* Note that we can simply drop out of the ISR now, since we are going
                                   to ignore the A/D data stream for the next tens of seconds (at least)
                                   while this trial recording is transfered to the SD card. */
                    }
                    
                    /*LATAbits.LATA5 = 0;     // This enables 74LVT125 buffers (Data is written to first SRAM board)
                    //LATAbits.LATA5 = 1;     // This enables 74LVT124 buffers (Data is written to second SRAM board, if exists)
                    */
                    
                    LATD = *(adc_dataptr + offset);
                    LATAbits.LATA15 = 0;      // A15 = 0 implies Write Enable
                    /* Here we supposedly need a delay for 2 instruction cycles before writing to SRAM unit. */
                    NOP;
                    NOP;
                    
                    LATAbits.LATA15 = 1;       // Write Disable

                    if (LATE == 0x00FF) {
                        LATB += 0x0010;
                        LATE = 0x0000;
                    } else {
                        LATE++;
                    }
                }
                num_dmablocks--;
            
            }
            
        } else {
        
            /* Dump current DMA transfer block, watch for the pivot address */
            for (offset = 0; offset < DMA_BLOCK_LEN; offset++) {
                /*
                 * Write Data
                 */
                if (sram_unit == (*sram_trig_addr) >> 14 && num_dmablocks == *(sram_trig_addr+1) && offset == (*sram_trig_addr & 0x01FF)) {
                    /* Yes, this is the pivot point. We are done recording this trial. */
                    trigger_hit = 0;
                    DMAptr_at_trigger = 0x8000;
                    return; /* Note that we can simply drop out of the ISR now, since we are going
                               to ignore the A/D data stream for the next tens of seconds (at least)
                               while this trial recording is transfered to the SD card. */
                }
                
                /*LATAbits.LATA5 = 0;     // This enables 74LVT125 buffers (Data is written to first SRAM board)
                //LATAbits.LATA5 = 1;     // This enables 74LVT124 buffers (Data is written to second SRAM board, if exists)
                */
                
                LATD = *(adc_dataptr + offset);
                LATAbits.LATA15 = 0;      // A15 = 0 implies Write Enable
                /* Here we supposedly need a delay for 2 instruction cycles before writing to SRAM unit. */
                NOP;
                NOP;
                
                LATAbits.LATA15 = 1;       // Write Disable

                if (LATE == 0x00FF) {
                    LATB += 0x0010;
                    LATE = 0x0000;
                } else {
                    LATE++;
                }
            }
            num_dmablocks--;
        
        }
        
    } else { /* Still waiting for trigger. */
        
        /* Write entire DMA transfer block */
        for (offset = 0; offset < DMA_BLOCK_LEN; offset++) {
            /*
             * Write Data
             */
            /*LATAbits.LATA5 = 0;     // This enables 74LVT125 buffers (Data is written to first SRAM board)
            //LATAbits.LATA5 = 1;     // This enables 74LVT124 buffers (Data is written to second SRAM board, if exists)
            */
            
            LATD = *(adc_dataptr + offset);
            LATAbits.LATA15 = 0;      // A15 = 0 implies Write Enable
            /* Here we supposedly need a delay for 2 instruction cycles before writing to SRAM unit. */
            NOP;
            NOP;
            
            LATAbits.LATA15 = 1;       // Write Disable

            if (LATE == 0x00FF) {
                LATB += 0x0010;
                LATE = 0x0000;
            } else {
                LATE++;
            }
        }
        num_dmablocks--;
        
    }
    
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


/*
 * Oscillator fail trap
 */
void _ISR __attribute__((auto_psv)) _OscillatorFail( void )
{
	//printLEDnum( 0x1 );
	/* Print PC at time of trap (i.e. peek at stack). */
	__asm__ volatile( "mov [W15-8], W0\n\t"
					  "rcall _printLEDword\n\t"
					  "mov [W15-6], W0\n\t"
					  "rcall _printLEDword" );
	while (1) ;
}


/*
 * Address error trap
 */
void _ISR __attribute__((auto_psv)) _AddressError( void )
{
	//printLEDnum( 0x2 );
	__asm__ volatile( "mov [W15-8], W0\n\t"
					  "rcall _printLEDword\n\t"
					  "mov [W15-6], W0\n\t"
					  "rcall _printLEDword" );
	while (1) ;
}


/*
 * Stack error trap
 */
void _ISR __attribute__((auto_psv)) _StackError( void )
{
	printLEDnum( 0x6 );
	while (1) ;
}


/*
 * Math error trap
 */
void _ISR __attribute__((auto_psv)) _MathError( void )
{
	printLEDnum( 0x5 );
	while (1) ;
}


/*
 * DMA conflict error trap
 */
void _ISR __attribute__((auto_psv)) _DMACError( void )
{
	printLEDnum( 0x3 );
	while (1) ;
}


/*
 * Default interrupt handler
 */
void _ISR __attribute__((auto_psv)) _DefaultInterrupt( void )
{
	printLEDnum( 0xf );
	while (1) ;
}
