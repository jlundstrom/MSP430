//*********************************************************************
// LED turn on to blink the LED on Port 2 of the MSP430FG4618
// experimenter board RAM at 0x1100 - 0x30ff, FLASH at 0x3100 –
// 0xfbff
// Port 2 is used for the LED's Port 2 bit 2 is the green LED,
// Port 2 bit 1 is the yellow LED
// input buttons on port 1 bits SW1 = bit 0 and SW2 = Bit2
// 1 = SW not pressed 0 = pressed
//*********************************************************************
//---------------------------------------------------------------------
// must include the C header to get the predefined variable names
// used by the MSP430FG4618 on the experimenter board
//---------------------------------------------------------------------
#include "msp430fg4618.h"
int main(void) {
// tell the compiler not to optimize the variable I, otherwise the
// compiler may change how the variable is used
	volatile unsigned int i;
	WDTCTL = WDTPW + WDTHOLD; // Stop watchdog timer so the
	// program
	// runs indefinitely
	P2DIR |= 0x06; // Set port 2 bit 1 to as an
	P1DIR &= ~0x03;

	// output 1 = output 0 = input
	// turn the light on
	//P2OUT = 0x02;
	// go run the program forever
	for (;;) {
		// delay before turning changing the state of the LED
		for (i = 0; i <= 0xFFF9; i++)
				;
		// Change the state of the LED using the EX-OR function
		//P2OUT = P2OUT ^ 0x06;

		P2OUT = ~(((P1IN) << 1)& 0x06);
	}

}
