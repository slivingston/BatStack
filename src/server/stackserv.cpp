/*
 * stackserv - Proudly serving BatStacks since 2010.
 *
 * NI-DAQ board routines are based loosely on code provided by NI-DAQmx examples,
 * specifically Acq-IntClk-AnlgStart.c and MultVoltUpdates-IntClk.c.
 *
 * Currently, interface is command-line driven. A GUI frontend will be added soon.
 *
 *
 * Scott Livingston <slivingston@caltech.edu>
 * April 2010
 *
 */


#include <stdio.h>

#include <NIDAQmx.h>


#define DAQmxErrChk(functionCall) if( DAQmxFailed(error=(functionCall)) ) goto Error; else


#define MIDV 1.65
#define BUF_LEN (64<<3)
#define SAMPLE_RATE 200000.0
#define HIGH 3.3 // logic high
#define LOW 0    // logic low

#define DATA_OFFSET (BUF_LEN>>1)


int32 f64nibble2hex( float64 *nibble )
{ // Assumes nibble is array of length 4, MSb first
	if (*nibble < MIDV && *(nibble+1) < MIDV && *(nibble+2) < MIDV && *(nibble+3) < MIDV) {
		return 0;
	} else if (*nibble >= MIDV && *(nibble+1) < MIDV && *(nibble+2) >= MIDV && *(nibble+3) < MIDV) {
		return 10; // A
	} else if (*nibble >= MIDV && *(nibble+1) < MIDV && *(nibble+2) >= MIDV && *(nibble+3) >= MIDV) {
		return 11; // B
	} else if (*nibble >= MIDV && *(nibble+1) >= MIDV && *(nibble+2) < MIDV && *(nibble+3) >= MIDV) {
		return 13; // D
	} else if (*nibble >= MIDV && *(nibble+1) >= MIDV && *(nibble+2) >= MIDV && *(nibble+3) < MIDV) {
		return 14; // E
	} else if (*nibble >= MIDV && *(nibble+1) >= MIDV && *(nibble+2) >= MIDV && *(nibble+3) >= MIDV) {
		return 15; // F
	}
	return 5; // 5 indicates failure, as it is currently not implemented.
}

int32 f64byte2hex( float64 *byte )
{ // Assumes byte is array of length 8, MSb first
	int32 result = f64nibble2hex( byte+4 );
	result |= f64nibble2hex( byte ) << 4;
	return result;
}

int32 f64word2hex_le( float64 *word )
{ // Assumes word is array of length 16, little endian
	int32 result = f64byte2hex( word );
	result |= f64byte2hex( word+8 ) << 8;
	return result;
}


int main( int argc, char **argv )
{
	int32       error=0;
	TaskHandle  taskHandle_in=0;
	TaskHandle  taskHandle_out=0;
	int32       rw_stat;
	float64     clk_out[BUF_LEN];
	float64		data[BUF_LEN];
	char        errBuff[2048]={'\0'};
	int re_ind, fall_ind, re2_ind; /* For tracking clock ticks. */

	// Clear data buffer
	//for (int i = 0; i < BUF_LEN; i++)
	//	*(data+i) = 0x0;

	// Generate clock
	for (int i = 0; i < BUF_LEN; i+=2) {
		*(clk_out+i) = LOW;
		*(clk_out+i+1) = HIGH;
	}
	*(clk_out+BUF_LEN-1) = LOW; // Force low termination

	DAQmxErrChk (DAQmxCreateTask("in",&taskHandle_in));
	DAQmxErrChk (DAQmxCreateAIVoltageChan(taskHandle_in,"Dev1/ai4:5","",DAQmx_Val_RSE,0,5,DAQmx_Val_Volts,NULL));
	DAQmxErrChk (DAQmxCfgSampClkTiming(taskHandle_in,"PFI0",SAMPLE_RATE,DAQmx_Val_Rising,DAQmx_Val_FiniteSamps,BUF_LEN>>1));
	//DAQmxErrChk (DAQmxCfgAnlgEdgeStartTrig(taskHandle_in,"PFI0",DAQmx_Val_Rising,1.0));
	//DAQmxErrChk (DAQmxSetAnlgEdgeStartTrigHyst(taskHandle_in, 0.0));

	DAQmxErrChk (DAQmxCreateTask("out",&taskHandle_out));
	DAQmxErrChk (DAQmxCreateAOVoltageChan(taskHandle_out,"Dev1/ao0","",0,3.3,DAQmx_Val_Volts,NULL));

	/*
	printf( "tick" );
	for (int i = 0; i < 10; i++) { // 10 ticks
		printf( " %d", i+1 );
		DAQmxErrChk( DAQmxWriteAnalogScalarF64( taskHandle_out, true, 10.0, LOW, NULL ) );
		DAQmxErrChk( DAQmxWaitUntilTaskDone( taskHandle_out, 1 ) );
		DAQmxErrChk( DAQmxWriteAnalogScalarF64( taskHandle_out, true, 10.0, HIGH, NULL ) );
		DAQmxErrChk( DAQmxWaitUntilTaskDone( taskHandle_out, 1 ) );
	}
	*/

	DAQmxErrChk( DAQmxCfgSampClkTiming(taskHandle_out,"",SAMPLE_RATE,DAQmx_Val_Rising,DAQmx_Val_FiniteSamps,BUF_LEN));
	DAQmxErrChk( DAQmxDisableStartTrig( taskHandle_out ) );

	DAQmxErrChk (DAQmxReadAnalogF64(taskHandle_in,BUF_LEN>>1,10.0,DAQmx_Val_GroupByChannel,data,BUF_LEN,&rw_stat,NULL));
	
	//DAQmxErrChk (DAQmxWriteAnalogF64(taskHandle_out,BUF_LEN,0,10.0,DAQmx_Val_GroupByChannel,clk_out,&rw_stat,NULL));
	

	//DAQmxErrChk( DAQmxWaitUntilTaskDone( taskHandle_out, 1 ) );
	DAQmxErrChk( DAQmxWaitUntilTaskDone( taskHandle_in, 1 ) );


	if( rw_stat>1 ) {
		printf("Acquired %d samples per channel\n",rw_stat);

		// Estimate clock rate; NOT GLITCH TOLERANT.
		if (*(data) > MIDV) {
			re_ind = 0;
			while (*(data+re_ind) > MIDV && re_ind < BUF_LEN)
				re_ind++;
			if (re_ind >= BUF_LEN) {
				if( taskHandle_in!=0 ) {
					DAQmxStopTask(taskHandle_in);
					DAQmxClearTask(taskHandle_in);
					printf("fail\n");
				}
				return -1;
			}
		} else {
			re_ind = 0;
		}
		while (*(data+re_ind) < MIDV && re_ind < BUF_LEN)
			re_ind++;
		if (re_ind >= BUF_LEN) {
			if( taskHandle_in!=0 ) {
				DAQmxStopTask(taskHandle_in);
				DAQmxClearTask(taskHandle_in);
				printf("fail\n");
			}
			return -1;
		}
		fall_ind = re_ind+1;
		while (*(data+fall_ind) > MIDV && fall_ind < BUF_LEN)
			fall_ind++;
		if (fall_ind >= BUF_LEN) {
			if( taskHandle_in!=0 ) {
				DAQmxStopTask(taskHandle_in);
				DAQmxClearTask(taskHandle_in);
				printf("fail\n");
			}
			return -1;
		}
		re2_ind = fall_ind+1;
		while (*(data+re2_ind) < MIDV && re2_ind < BUF_LEN)
			re2_ind++;
		if (re2_ind >= BUF_LEN) {
			if( taskHandle_in!=0 ) {
				DAQmxStopTask(taskHandle_in);
				DAQmxClearTask(taskHandle_in);
				printf("fail\n");
			}
			return -1;
		}

		printf( "Approx. clock rate of %.2f Hz\n\n", SAMPLE_RATE/(re2_ind-re_ind) );

		int nibble_count = 0;
		int msg_count = 0;
		for (int offset = 0; offset < BUF_LEN; offset += DATA_OFFSET) {
			nibble_count = 0;
			msg_count = 0;
			for (int k = offset; k < offset+DATA_OFFSET && k < BUF_LEN; k+=16) {
				printf( "0x%04X\n", f64word2hex_le( data+k ) );
				msg_count++;
				if (msg_count >= 2) {
					msg_count = 0;
					printf( "\n" );
				}
				//if (nibble_count >= 4) {
				//	nibble_count = 0;
				//	printf( " ( " );
				//	for (int j = 0; j < 4; j++)
				//		printf( "%.4f ", *(data+k-4+j) );
				//	printf( ") 0x%X\n", f64nibble2hex( data+k-4 ) );
				//	msg_count++;
				//}
				//if (msg_count >= 8) {
				//	msg_count = 0;
				//	printf( "\n" );
				//}
				//if (*(data+k) < MIDV) {
				//	printf( "0" );
				//} else {
				//	printf( "1" );
				//}
				//nibble_count++;
			}
			printf("\n\n---\n\n");
		}
		
	}
	

Error:
	if( DAQmxFailed(error) )
		DAQmxGetExtendedErrorInfo(errBuff,2048);
	if( taskHandle_in!=0 ) {
		DAQmxStopTask(taskHandle_in);
		DAQmxClearTask(taskHandle_in);
	}
	if( taskHandle_out!=0 ) {
		DAQmxStopTask(taskHandle_out);
		DAQmxClearTask(taskHandle_out);
	}
	if( DAQmxFailed(error) )
		printf("DAQmx Error: %s\n",errBuff);
	return 0;
}
