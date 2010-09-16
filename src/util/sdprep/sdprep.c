/* sdprep.c - Prepare an SD card for use in a BatStack. Currently this
 * only constitutes setting basic header information.
 *
 * Scott Livingston <slivingston@caltech.edu>
 *
 * September-November 2009, April 2010.
 *
 * NOTES: - In Unix, the SD card is a file (likely something under
 *          /dev). You should use the device file corresponding to the
 *          entire card, in particular, NOT one of the
 *          partitions. Note that this operation will corrupt the MBR
 *          of the SD card and possibly whatever filesystems it
 *          happens to step on. At time of writing, however, only the
 *          first two sectors (1024 bytes) are manipulated; hence, the
 *          partitions themselves may remain untouched. Using sdprep
 *          might require sudo privileges
 *
 *        - Multibyte entries are assumed to be little endian.
 *
 *        - Default BatStack ID is 0x00 (i.e., uninitialized).
 *
 *
 */


#include <stdio.h>
#include <stdlib.h>

#include <unistd.h>
#include <fcntl.h>


#define HEADER_SIZE 1024


int main( int argc, char **argv )
{
	unsigned char swidth_mactive; /* upper 4 bits: sample width;
									 lower 4 bits: microphone channel active flags. */
	unsigned char batstack_id;

	int fd;
	unsigned char buf[HEADER_SIZE];

	int i;

	if (argc < 2 || argc > 3) {
		printf( "Usage: %s filename [BatStack ID]\n", argv[0] );
		return 1;
	}

	if (argc == 3) {
		batstack_id = atoi( argv[2] ); /* Note this u8 value is read here and written to the SD card blindly. */
	} else {
		batstack_id = 0x00;
	}

	if ((fd = open( argv[1], O_WRONLY )) == -1) {
		perror( "open" );
		return -1;
	}

	if (lseek( fd, 0, SEEK_SET ) == -1) {
		perror( "lseek" );
		return -1;
	}

	/* Clear buffer to start. */
	for (i = 0; i < HEADER_SIZE; i++)
		*(buf+i) = 0x00;

	/* Set ID */
	*buf = batstack_id;

	/* Note buf array was cleared, hence "build date" bytes are
	   already cleared and need not be written here. */
	
	/* Prepare and set sample width (upper nibble) and mic channel
	   active flags (lower nibble). */
	swidth_mactive = 0xAF; /* Corresponding to 10 bit sample width,
							  and all mic channels active. */
	*(buf+3) = swidth_mactive;

	/* No trials recorded thus far! So, no need to write "number of
	   trials recorded" byte here. */

	i = write( fd, buf, HEADER_SIZE );
	if (i == -1) {
		perror( "write" );
		return -1;
	}
	printf( "%d bytes written.\n", i );
	
	close( fd );

	return 0;
}
