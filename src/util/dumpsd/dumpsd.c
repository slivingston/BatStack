/* dumpsd.c - Extract trial data from an SD card, including notes
 * about the BatStack ID, software build date, etc.
 *
 * Scott Livingston  <slivingston@caltech.edu>
 *
 * November 2009, January, April, May 2010.
 *
 * NOTES: - Base for trial data file naming is limited to 32
 *          characters. This is arbitrary.
 *
 *        - Currently, for the sake of speed (by reducing the number
 *          of system calls), this program reads entire trials (likely
 *          8 MB) at a time.
 *
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <unistd.h>
#include <sys/types.h>
#include <fcntl.h>


#define NAMEBASE_LEN 128
#define NAMEADD_LEN 32

#define NUMSECTORS_PER_TRIAL 16384
/* Assuming 8 MB of trial data (i.e. 4 1-Mword SRAM units filled). */

#define HEADER_SIZE 1024 // in bytes


/* Convert a 4 byte array to the corresponding address (unsigned long
   or int) value, assuming little endian order. */
off_t letoaddr( unsigned char *buf )
{
	off_t result = 0;
	int i;

	for (i = 0; i < 4; i++) {
		result |= (unsigned long)(*(buf+i)) << (i*8);
	}

	return result;
}


int main( int argc, char **argv )
{
	char base[NAMEBASE_LEN+1];
	struct tm *timestamp;
	time_t tepoch; /* Seconds since the Epoch. */
	char verbose = 0; /* Verbose mode flag */
	char header_only = 0; /* Print header only flag */

	char fname[NAMEBASE_LEN+NAMEADD_LEN+1]; /* Hold constructed file name. */
	unsigned char batstack_id;
	unsigned char build_year, build_mon, build_day;
	unsigned char swidth; /* Sample width (in bits) */
	unsigned char active_mics; /* ...1 bit per channel */
	unsigned int  sample_period; // in 10-ns units
	unsigned int  postlen;
	unsigned char total_trials;

	unsigned char current_trial; /* For stepping through trials' data on SD card. */
	off_t trial_addr; /* Start sector address; should be available in SD card header. */
	unsigned int trial_date;
	unsigned int trial_dsec; // decaseconds (since midnight)
	unsigned int trial_postlen; // POSTLEN at time of recording

	unsigned char sdheader[HEADER_SIZE]; /* Header sector */
	unsigned char buf[NUMSECTORS_PER_TRIAL*512]; /* Sector buffer. */
	int fd;
	int i; /* Generic counter variables, etc. */
	unsigned int nb; /* For tracking number of bytes read/written. */

	FILE *fp; /* For file I/O a la stdio library (i.e., libc). */

	if (argc < 2 || argc > 4) {
		printf( "Usage: %s filename [-vh] [name_base]\n", argv[0] );
		return 1;
	}
	
	*base = NULL; /* Indicate base name is unset. */

	/* Handle optional process arguments */
	if (argc > 2) {

		for (i = 2; i < argc; i++) {
			/* Is it a flag specifier? */
			if (*(argv[i]) == '-') {
				while (*(++(argv[i])) != '\0') { /* Examine each character in turn. */
					switch (*(argv[i])) {
					case 'v':
						verbose = 1; /* Enable verbose mode. */
						break;
					case 'h':
						header_only = 1; /* Only display SD card header. */
						break;
					default:
						fprintf( stderr, "Unrecognized option: \'%c\'\n", *(argv[i]) );
						break;
					}
				}
			} else { /* Assume this is the desired basename. */
				if (*base == NULL) {
					strncpy( base, argv[2], NAMEBASE_LEN+1 );
				} else {
					fprintf( stderr, "Attempted to specify basename more than once. Aborting.\n" );
					return -1;
				}
			}
		}

	}

	if (*base == NULL) {

		/* Use default, YYYYMMDD. */
		tepoch = time( NULL );
		timestamp = localtime( &tepoch );
		snprintf( base, NAMEBASE_LEN+1, "%04d%02d%02d",
				  timestamp->tm_year+1900, timestamp->tm_mon+1, timestamp->tm_mday );

	}
	*(base+NAMEBASE_LEN) = '\0'; /* Force null termination. */

	if ((fd = open( argv[1], O_RDONLY )) == -1) {
		perror( "open" );
		return -1;
	}

	/* Read and extract major components of SD card header. */
	i = read( fd, sdheader, HEADER_SIZE );
	if (i == -1) {
		perror( "read" );
		return -1;
	}
	if (verbose) {
		printf( "%d bytes read (from header sector).\n", i );
	}

	batstack_id = *sdheader;
	swidth = (*(sdheader+3)) >> 4;
	active_mics = (*(sdheader+3)) & 0x0F;
	sample_period = *(sdheader+4);
	sample_period |= (*(sdheader+5)) << 8;
	postlen = *(sdheader+6);
	postlen |= (*(sdheader+7)) << 8;
	total_trials = *(sdheader+8);

	/* Build date */
	build_day = (*(sdheader+1)) & 0x1F;
	build_mon = ((*(sdheader+1)) & 0xE0) >> 5;
	build_mon |= ((*(sdheader+2)) & 0x01) << 3;
	build_year = ((*(sdheader+2)) & 0xFE) >> 1;


	if (verbose) {
		/* Print various notes about SD card (based on header). */
		printf( "Associated BatStack ID: %x\n", batstack_id );
		printf( "Firmware build date: %02d/%02d/%04d\n", build_day, build_mon, (unsigned int)build_year+1970 );
		printf( "Sample width: %d bits\nActive mic channels: ", swidth );
		for (i = 0; i < 4; i++) {
			if (active_mics & (0x08 >> i)) {
				printf( "%d ", i+1 );
			}
		}
		printf( "\n" );
		printf( "Sample period: %.4f us\n", sample_period/100. ); // in microseconds
		printf( "Post-trigger length (in samples per channel): %d\n", postlen*256 );
		printf( "Number of trials on SD card: %d\n", total_trials );
		printf( "Trial start sectors:\n" );
		for (current_trial = 1; current_trial <= total_trials; current_trial++) {
			trial_addr = letoaddr( sdheader+12*current_trial-3 );
			trial_date = *(sdheader+12*current_trial+1);
			trial_date |= (*(sdheader+12*current_trial+2)) << 8;
			trial_dsec = *(sdheader+12*current_trial+3);
			trial_dsec |= (*(sdheader+12*current_trial+4)) << 8;
			trial_postlen = *(sdheader+12*current_trial+5);
			trial_postlen |= (*(sdheader+12*current_trial+6)) << 8;
			printf( "  %15d (%02d/%02d/%04d %02d:%02d:%02d; postlen %d)\n",
					(int)(trial_addr),
					trial_date & 0x1F, (trial_date & 0x1E0)>>5, (trial_date & 0xFE00)>>9,
					trial_dsec/360, (trial_dsec%360)/6, (trial_dsec%6)*10,
					trial_postlen );
		}
	}


	/* Step through trial data and dump it to separate files (binary
	   blobs) with naming convention of

	   <base name>_<BatStack ID>_trial[trial number, zero-padded].bin

	   Also dump relevant header entries to a plaintext trial data
	   "notes" file. Naming convention is

	   <base name>_<BatStack ID>_params.txt
	*/

	if (verbose) {
		printf( "Writing params file..." );
	}
	if (snprintf( fname, NAMEBASE_LEN+NAMEADD_LEN+1, "%s_%02x_params.txt", base, batstack_id ) < 0) {
		perror( "snprintf" );
		return -1;
	}
	if ((fp = fopen( fname, "w" )) == NULL) { /* This will write over any existing file with this same name. */
		perror( "fopen" );
		return -1;
	}
	
	fprintf( fp, "%d\n", batstack_id );
	fprintf( fp, "%02d %02d %04d\n", build_day, build_mon, (unsigned int)build_year+1970 );
	fprintf( fp, "%d\n", swidth );
	for (i = 0; i < 4; i++) {
		if (active_mics & (0x08 >> i)) {
			fprintf( fp, "%d ", i+1 );
		}
	}
	fprintf( fp, "\n%.4f\n", sample_period/100. ); // in microseconds
	fprintf( fp, "%d\n", postlen*256 );
	fprintf( fp, "%d\n", total_trials );
	for (current_trial = 1; current_trial <= total_trials; current_trial++) {
		/* Get start sector at which to begin reading. */
		trial_addr = letoaddr( sdheader+12*current_trial-3 );
		trial_date = *(sdheader+12*current_trial+1);
		trial_date |= (*(sdheader+12*current_trial+2)) << 8;
		trial_dsec = *(sdheader+12*current_trial+3);
		trial_dsec |= (*(sdheader+12*current_trial+4)) << 8;
		trial_postlen = *(sdheader+12*current_trial+5);
		trial_postlen |= (*(sdheader+12*current_trial+6)) << 8;
		/* trial_addr day month year hour min seconds postlen */
		fprintf( fp, "%d %02d %02d %04d %02d %02d %02d %d\n",
				 (int)(trial_addr),
				 trial_date & 0x1F, (trial_date & 0x1E0)>>5, (trial_date & 0xFE00)>>9,
				 trial_dsec/360, (trial_dsec%360)/6, (trial_dsec%6)*10,
				 trial_postlen );
	}
	if (total_trials > 0)
		fprintf( fp, "\n" );

	fclose( fp );
	if (verbose) {
		printf( "Done.\n" );
	}


	if (header_only) { /* If only header was desired, then we may quit now. */
		close( fd );
		return 0;
	}

	if (verbose) {
		printf( "Writing trial data files...\n" );
	}
	for (current_trial = 1; current_trial <= total_trials; current_trial++) {

		if (verbose) {
			printf( "Trial %d ", current_trial );
		}

		if (snprintf( fname, NAMEBASE_LEN+NAMEADD_LEN+1, "%s_%02x_trial%02d.bin", base, batstack_id, current_trial ) < 0) {
			perror( "snprintf" );
			return -1;
		}

		if ((fp = fopen( fname, "w" )) == NULL) {
			perror( "fopen" );
			return -1;
		}

		/* Get start sector at which to begin reading. */
		trial_addr = letoaddr( sdheader+12*current_trial-3 );

		if (verbose) {
			/* This might cause problems if the off_t type is too wide
			   for printf. */
			printf( "(sector %d) ...", (int)(trial_addr) );
		}

		/* Read in trial data */
		
		if (lseek( fd, trial_addr*512, SEEK_SET ) == -1) {
			perror( "lseek" );
			return -1;
		}
		nb = read( fd, buf, NUMSECTORS_PER_TRIAL*512 );
		if (nb == -1) {
			perror( "read" );
			return -1;
		}
		while (nb < NUMSECTORS_PER_TRIAL*512) {
			i = read( fd, buf+nb, NUMSECTORS_PER_TRIAL*512-nb );
			if (i == -1) {
				perror( "read" );
				return -1;
			} else if (i == 0){ /* End of file? */
				fprintf( stderr, "Warning: only found %d bytes (%d sectors) for trial %d\n",
						 nb, (int)(nb/512.), current_trial );
				break;
			}
			nb += i;
			if (nb == NUMSECTORS_PER_TRIAL*512) /* Done reading trial? */
				break;
		}

		if ((i = fwrite( buf, 1, nb, fp )) < nb) {
			fprintf( stderr, "Warning: incomplete trial file write: %d bytes to %s\n",
					 i, fname );
		}

		fclose( fp );

		if (verbose) {
			printf( "Done.\n" );
		}

	}


	close( fd );
	return 0;
}

