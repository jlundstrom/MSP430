//---------------------------------------------------------------------
// LCD Driver for the for MSP 430X4XXX experimenter board using
// Softbaugh LCD
// Davies book pg. 259, 260
//---------------------------------------------------------------------

#include "msp430fg4618.h"
#include "stdio.h"

void Init_LCD(void);
void SetLCD(unsigned int i);
unsigned int RollOverForDec(unsigned int i);
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
unsigned char Digits[] = { 	0x5f, 0x06, 0x6b, 0x2f, // 0-3
							0x36, 0x3d, 0x7d, 0x07, // 4-7
							0x7f, 0x37, 0x77, 0x7c, // 8-b
							0x59, 0x6e, 0x79, 0x71}; // c-f
// there are 11 locations that are needed for the softbaugh LCD
// ony 7 used for the seven segment displays
int LCD_SIZE = 11;
int Num_SIZE = 3;

int main(void) {
	volatile unsigned char a;
	volatile unsigned char swStatus;
	volatile unsigned int i; // volatile to prevent optimization
	volatile unsigned int number;
	WDTCTL = WDTPW + WDTHOLD; // Stop watchdog timer
	// setup pprt 3 as an output so to be able to turn on the LED
	P2DIR |= 0x02; // Set P1.0 to output direction
	P1DIR &= ~0x03; // Enable switches as inputs
	// go Initialize the LCD
	Init_LCD();
	number = 0x00;
	while (1) {
		if ((P1IN & 0x3) == 0x01)
			number -= 1;
		else if((P1IN & 0x3) == 0x02)
			number += 1;

		number = RollOverForDec(number);
		SetLCD(number);

		i = 0x0FFF; // SW Delay
		while (i != 0)
			i--;
	}

}

unsigned int RollOverForDec(unsigned int i) {
//	unsigned int orig = i;
//	char pos;
//	for (pos = 1; pos <= Num_SIZE; pos++) {
//		if ((orig & 0x0F) == 0x0A)
//			i += 6 << (4 * (pos - 1));
//		else if ((orig & 0x0F) == 0x0F)
//			i -= 6 << (4 * (pos - 1));
//		orig = i >> (4 * pos);
//	}
//	return i;
	if ((i&0x00F) == 0x00A)
		i += 0x6;
	if ((i&0x00F) == 0x00F)
		i -= 0x6;
	if ((i&0x0F0) == 0x0A0)
		i += 0x60;
	if ((i&0x0F0) == 0x0F0)
		i -= 0x60;
	if ((i&0xF00) == 0xA00)
		i += 0x600;
	if ((i&0xF00) == 0xF00)
		i -= 0x600;
	return i;
}

void SetLCD(unsigned int i) {
	char pos = 0;
	for (pos = 0; pos < Num_SIZE; pos++) {
		LCDSeg[pos] = Digits[i & 0x0F];
		i = i >> 4;
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
