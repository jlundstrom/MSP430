//---------------------------------------------------------------
// Console I/O through the on board UART for MSP 430X4XXX
//---------------------------------------------------------------
void Init_UART(void);
void OUTA_UART(unsigned char A);
void OUTA_STR_UART(unsigned char* A);
unsigned char INCHAR_UART(void);
#include "msp430fg4618.h"
#include "stdio.h"

int main(void) {
	volatile unsigned char a;
	volatile unsigned int i; // volatile to prevent optimization
	unsigned char str[] = "Laboratory #2 for EEL4742 Embedded Systems";
	WDTCTL = WDTPW + WDTHOLD; // Stop watchdog timer
	Init_UART();

	OUTA_STR_UART(str); // Print string to UART

	return 0;
}

void OUTA_STR_UART(unsigned char* A) {
	while (*A) { // Loop while pointer is not pointing at a null
		OUTA_UART(*A); // Print character
		A = A + 1; // Increment pointer
	}
}

void OUTA_UART(unsigned char A) {
//---------------------------------------------------------------
//***************************************************************
//---------------------------------------------------------------
// IFG2 register (1) = 1 transmit buffer is empty,
// UCA0TXBUF 8 bit transmit buffer
// wait for the transmit buffer to be empty before sending the
// data out
	do {
	} while ((IFG2 & 0x02) == 0);
// send the data to the transmit buffer
	UCA0TXBUF = A;
}

unsigned char INCHAR_UART(void) {
//---------------------------------------------------------------
//***************************************************************
//---------------------------------------------------------------
// IFG2 register (0) = 1 receive buffer is full,
// UCA0RXBUF 8 bit receive buffer
// wait for the receive buffer is full before getting the data
	do {
	} while ((IFG2 & 0x01) == 0);
// go get the char from the receive buffer
	return (UCA0RXBUF);
}
void Init_UART(void) {
//---------------------------------------------------------------
// Initialization code to set up the uart on the experimenter
// board to 8 data,
// 1 stop, no parity, and 9600 baud, polling operation
//---------------------------------------------------------------
	P2SEL = 0x30; // transmit and receive to port 2 b its 4 and 5
	// Bits p2.4 transmit and p2.5 receive
	UCA0CTL0 = 0; // 8 data, no parity 1 stop, uart, async
	// (7)=1 (parity), (6)=1 Even, (5)= 0 lsb first,
	// (4)= 0 8 data / 1 7 data,
	// (3) 0 1 stop 1 / 2 stop, (2-1) -- UART mode,
	// (0) 0 = async
	UCA0CTL1 = 0x41;
	// select ALK 32768 and put in
	// software reset the UART
	// (7-6) 00 UCLK, 01 ACLK (32768 hz), 10 SMCLK,
	// 11 SMCLK
	// (0) = 1 reset
	UCA0BR1 = 0; // upper byte of divider clock word
	UCA0BR0 = 3; // clock divide from a clock to bit clock 32768/9600
	// = 3.413
	// UCA0BR1:UCA0BR0 two 8 bit reg to from 16 bit
	// clock divider
	// for the baud rate
	UCA0MCTL = 0x06;
	// low frequency mode module 3 modulation pater
	// used for the bit clock
	UCA0STAT = 0; // do not loop the transmitter back to the
	// receiver for echoing
	// (7) = 1 echo back trans to rec
	// (6) = 1 framing, (5) = 1 overrun, (4) =1 Parity,
	// (3) = 1 break
	// (0) = 2 transmitting or receiving data
	UCA0CTL1 = 0x40;
	// take UART out of reset
	IE2 = 0; // turn transmit interrupts off
//---------------------------------------------------------------
//***************************************************************
//---------------------------------------------------------------
			// IFG2 register (0) = 1 receiver buffer is full,
			// UCA0RXIFG
			// IFG2 register (1) = 1 transmit buffer is empty,
			// UCA0RXIFG
			// UCA0RXBUF 8 bit receiver buffer
			// UCA0TXBUF 8 bit transmit buffer
}
