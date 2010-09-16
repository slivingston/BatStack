/* env.h
 *
 * Global variables... defined here, pulled into others. See env.c for
 * descriptions and initial values.
 *
 *
 * Scott Livingston
 * April 2010.
 *
 */

#ifndef _ENV_H_
#define _ENV_H_


#include "platform.h"


extern volatile unsigned int posttrigger_len;

extern volatile unsigned int trigger_hit;
extern volatile unsigned int first_int_since_trigger;

extern volatile unsigned int __attribute__ ((aligned (2))) sram_trig_addr[2];
                                        
extern volatile unsigned int DMAptr_at_trigger;

extern volatile unsigned int sram_unit;
extern unsigned int SRAMchipW[4];
extern unsigned int SRAMchipR[4];
extern volatile unsigned int num_dmablocks;

extern unsigned int DMAbufA[DMA_BLOCK_LEN] __attribute__((space(dma)));
extern unsigned int DMAbufB[DMA_BLOCK_LEN] __attribute__((space(dma)));

extern unsigned char batstack_id;
extern unsigned int build_date;
extern unsigned char swidth_mactive;
extern unsigned int sample_period;
extern unsigned char total_trials;
extern volatile unsigned char __attribute__ ((aligned(2),far)) sdheader[1024];

extern unsigned long sectorptr;

extern volatile unsigned int dmablock_flag;


#endif
