//---------------------------------------------------------------------
// LCD Driver for the for MSP 430X4XXX experimenter board using
// Softbaugh LCD
// Davies book pg. 259, 260
//---------------------------------------------------------------------

#include "msp430fg4618.h"
#include "stdio.h"

void Init_LCD(void);
// setup a pointer to the area of memory of the TMS430 that points to
// the segments
// of the softbaugh LCD LCDM3 = the starting address
// each of the seven segments for each display is store in memory
// starting at address LCDM3
// which is the right most seven segment of the LCD
// The bit order in each byte is
// dp, E, G, F, D, C, B, A or
// :, E, G, F, D, C, B, A
// after the seven segments these memory locations are used to turn on
// the special characters
// such as battery status, antenna, f1-f4, etc.
// there are 7 seven segment displays
unsigned char *LCDSeg = (unsigned char *) &LCDM3;
unsigned char Digits[] = {0x3f, 0x06, 0x5b, 0x4f, // 0-3
						 0x66, 0x6d, 0x7d, 0x07, // 4-7
						 0x7f, 0x67, 0x76, 0x7c, // 8-b
						 0x39, 0x5e, 0x79, 0x71}; // c-f
// there are 11 locations that are needed for the softbaugh LCD
// ony 7 used for the seven segment displays
int LCD_SIZE = 11;

int main(void) {
	volatile unsigned char a;
	volatile unsigned int i; // volatile to prevent optimization
	WDTCTL = WDTPW + WDTHOLD; // Stop watchdog timer
	// setup pprt 3 as an output so to be able to turn on the LED
	P2DIR |= 0x02; // Set P1.0 to output direction
	// go Initialize the LCD
	Init_LCD();
	// Turn on all of the segments
	// LCD_SIZE-4 only gives the 7 segment displays plus DP,
	// and colons colons = dp
	// Right most display is at LCDSeg[0];
	for (i = 0; i < LCD_SIZE; i++) {
		// To turn on a segment of the LCD a one is written in the
		// appropriate location in the LCD memory
		// Setting all the bits to 1 for all memory locations turns on
		// all of the display elements
		// Including all of the special characters
		LCDSeg[i] = 0xff;
	}
	// now that all the LCD segments have been turned on just toggle
	// the yellow LED on / off
	for (;;) {
		P2OUT ^= 0x02; // Toggle P1.0 using exclusive-OR
		i = 10000; // SW Delay
		do
			i--;
		while (i != 0);
	}
}

//---------------------------------------------------------------------
// Initialize the LCD system
//---------------------------------------------------------------------
void Init_LCD(void) {
	// Using the LCD A controller for the MSP430fg4618
	// the pins of the LCD are memory mapped onto the mp430F4xxx
	// memory bus and
	// are accessed via LCDSeg[i] array
	// See page 260 of Davie's text
	// LCD_SIZE-4 only gives the 7 segment displays plus DP, and
	// (colons are the same bit setting)
	// LCD_SIZE-4 only gives the 7 segment displays plus DP, and
	// colons (colons / dp)
	// Right most seven segment display is at LCDSeg[0];
	// Display format
	// AAA
	// F B
	// X F B
	// GGG
	// X E C
	// E C
	// DP DDD

	// bit order
	// dp, E, G, F, D, C, B, A or
	// :, E, G, F, D, C, B, A
	int n;
	for (n = 0; n < LCD_SIZE; n++) {
		// initialize the segment memory to zero to clear the LCD
		// writing a zero in the LCD memory location clears turns
		// off the LCD segment
		// Including all of the special characters
		// This way or
		*(LCDSeg + n) = 0;
		// LCDSeg[n]=0;
	}
	// Port 5 ports 5.2-5.4 are connected to com1, com2, com3 of LCD and
	// com0 is fixed and already assigned
	// Need to assign com1 - com3 to port5
	P5SEL = 0x1C; // BIT4 | BIT3 |BIT2 = 1 P5.4, P.3, P5.2 = 1
	// Used the internal voltage for the LCD bit 4 = 0 (VLCDEXT=0)
	// internal bias voltage set to 1/3 of Vcc, charge pump disabled,
	// page 26-25 of MSP430x4xx user manual
	LCDAVCTL0 = 0x00;
	// LCDS28-LCDS0 pins LCDS0 = lsb and LCDS28 = MSB need
	// LCDS4 through LCDS24
	// from the experimenter board schematic the LCD uses S4-S24,
	// S0-S3 are not used here
	// Only use up to S24 on the LCD 28-31 not needed.
	// Also LCDACTL1 not required since not using S32 - S39
	// Davie's book page 260
	// page 26-23 of MSP430x4xx user manual
	LCDAPCTL0 = 0x7E;
	// The LCD uses the ACLK as the master clock as the scan rate for
	// the display segments
	// The ACLK has been set to 32768 Hz with the external
	// 327768 Hz crystal
	// Let's use scan frequency of 256 Hz (This is fast enough not
	// to see the display flicker)
	// or a divisor of 128
	// LCDFREQ division(3 bits), LCDMUX (2 bits), LCDSON segments on,
	// Not used, LCDON LCD module on
	// 011 = freq /128, 11 = 4 mux's needed since the display uses for
	// common inputs com0-com3
	// need to turn the LCD on LCDON = 1
	// LCDSON allows the segments to be blanked good for blinking but
	// needs to be on to
	// display the LCD segments LCDSON = 1
	// Bit pattern required = 0111 1101 = 0x7d
	// page 26-22 of MSP430x4xx user manual
	LCDACTL = 0x7d;
}
