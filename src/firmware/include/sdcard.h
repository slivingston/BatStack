/* sdcard.h
 *
 *
 * Scott Livingston
 * Apr 2010.
 *
 */

#ifndef _SDCARD_H_
#define _SDCARD_H_


void sdcard_read_hdr();
void sdcard_hdr_addtrial( unsigned long trialstartsect, unsigned int trial_date,
						  unsigned int trial_dsec, unsigned int trial_postlen );
void sdcard_transfer_data();


#endif
