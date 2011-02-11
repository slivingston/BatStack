/* env.c
 *
 * Scott Livingston
 * April 2010.
 *
 */


#include "platform.h"


/* To support a configurable trigger time, (uint16) posttrigger_len specifies
   the number of 256 sample blocks to record after the trigger. Assuming 4 Mwords
   of sample data, and 4 microphone channels (hence 1 Mword or 1048576 samples per
   channel), there are therefore 4096 such blocks of 256 samples each; note that
   a single block includes in total 1024 samples, since there are 4 mic channels.
   
   For examples, posttrigger_len := 0 implies an end-trigger;
                                 := 4096 implies a start-trigger; and
                                 := 2048 implies middle trigger (i.e. equal
                                    recording time before and after trigger press.)
*/
volatile unsigned int posttrigger_len = 0; /* Default to start-trigger mode. */

/* non-zero implies receipt of trigger signal, and the board should be
   recording posttrigger_len blocks of post-trigger samples. This is
   in most cases only cleared from within the DMA5 ISR. */
volatile unsigned int trigger_hit = 0;

/* This should only be cleared from within the DMA5 ISR.  It indicates
   whether the ISR is servicing the first interrupt since trigger,
   which must be treated as a special case. */
volatile unsigned int first_int_since_trigger = 1; 

/* [0] -- bits 7:0 correspond to Latch E at trigger time, and 15:14
          (i.e. upper-most two bits) specify the sram_unit;
   [1] -- bits 15:4 correspond to Latch B at trigger time.
   
   Remaining bits not noted above are undefined (but may be used
   later, hence are "reserved").  Note that this address might
   decrease by up to 3 words to account for triggers occuring in the
   midst of writing a 4-channel sample (this adjustment ensures
   alignment; otherwise, our numbering of recorded samples to channel
   numbers will be off, among other things. */
volatile unsigned int __attribute__ ((aligned (2))) sram_trig_addr[2];
                                        
/* Address read from DSADR at the time of trigger detection.
   This value should only be considered valid from when it is
   set upon a device trigger through the completion of recording
   microphone streams to the SRAM units. */
volatile unsigned int DMAptr_at_trigger = 0;

/* Only 4 in current design; hence, sram_unit is in {0,1,2,3} */
volatile unsigned int sram_unit = 0;
unsigned int SRAMchipW[4] = {0x8002, 0x8004, 0x8008, 0x8010};
unsigned int SRAMchipR[4] = {0x8202, 0x8204, 0x8208, 0x8210};
volatile unsigned int num_dmablocks = 0;
/* Number of DMA transfer blocks to be written to each SRAM unit. */

unsigned int DMAbufA[DMA_BLOCK_LEN] __attribute__((space(dma)));
unsigned int DMAbufB[DMA_BLOCK_LEN] __attribute__((space(dma)));

/* SD card header fields */
unsigned char batstack_id = 0x01; /* Make unique for each BatStack in a setup! */
unsigned int build_date;// currently initialized in main. = 0x5097; /* 2010 April 23 */
unsigned char swidth_mactive = 0xAF; /* 10 bit sample width,
										all 4 mic channels active */
unsigned int sample_period = 375; /* 3.75 us; sample period field is in 10-ns units. */
unsigned char total_trials;
volatile unsigned char __attribute__ ((aligned(2),far)) sdheader[1024];
/* A working copy of the SD card header is kept in RAM to avoid
   having to first read it before updating the "total trials"
   on the card following each trial recording.

   This may waste too much RAM. */

unsigned long sectorptr = 2; /* Pointer to "current" sector address of
                                SD card, typically meaning the next
                                available sector for writing. */

volatile unsigned int dmablock_flag = 0;
