;****************************************************************
; Console I/O through the on board UART for MSP 430X4XXX
; experimenter board RAM at 0x1100 - 0x30ff, FLASH at 0x3100;
; - 0xfbff
;****************************************************************
			.cdecls C,LIST,"msp430fg4618.h"
; cdecls tells assembler to allow the device header file
;----------------------------------------------------------------
; Main Code
;----------------------------------------------------------------
; This is the stack and variable area of RAM and begins at
; address 0x1100 can be used for program code or constants

; This is the code area flash begins at address 0x3100 can be
; used for program code or constants

			.text 						; program start
			.global _START 				; define entry point
;----------------------------------------------------------------
START		mov.w #300h,SP				; Initialize 'x1121
	 									; stackpointer
StopWDT		mov.w #WDTPW+WDTHOLD,&WDTCTL	; Stop WDT
SetupP2		bis.b #06h,&P2DIR			; P2.2 output

			call #Init_UART				; go initialize the uart

Mainloop	call #INCHAR_UART			; Get user input
			call #OUTA_UART				; Echo back input
			mov.b R4, R5				; Get user entered char

			xor.b #0x47,R5				; is char G?
			cmp.b #0x00,R5
			jz InputG					; If it is jump to green toggle
			mov.b R4, R5				; Refetch user entered char
			xor.b #0x59,R5				; check if its a Y
			cmp.b #0x00,R5
			jz InputY					; If it is jump to yellow toggle
			jmp Mainloop				; If neither wait for next input

InputG		xor.b #0x04,P2OUT			; Toggle green LED
			jmp Mainloop
InputY		xor.b #0x02,P2OUT			; Toggle yellow LED
			jmp Mainloop


OUTA_UART
;----------------------------------------------------------------
; prints to the screen the ASCII value stored in register 4 and
; uses register 5 as a temp value
;----------------------------------------------------------------
; IFG2 register (1) = 1 transmit buffer is empty,
; UCA0TXBUF 8 bit transmit buffer
; wait for the transmit buffer to be empty before sending the
; data out
			push R5
lpa			mov.b &IFG2,R5
			and.b #0x02,R5
			cmp.b #0x00,R5
			jz lpa
; send the data to the transmit buffer UCA0TXBUF = A;
			mov.b R4,&UCA0TXBUF
			pop R5
			ret

INCHAR_UART
;----------------------------------------------------------------
; returns the ASCII value in register 4
;----------------------------------------------------------------
; IFG2 register (0) = 1 receive buffer is full,
; UCA0RXBUF 8 bit receive buffer
; wait for the receive buffer is full before getting the data
			push R5
lpb			mov.b &IFG2,R5
			and.b #0x01,R5
			cmp.b #0x00,R5
			jz lpb
			mov.b &UCA0RXBUF,R4
			pop R5
; go get the char from the receive buffer
			ret

Init_UART
;----------------------------------------------------------------
; Initialization code to set up the uart on the experimenter board to 8 data,
; 1 stop, no parity, and 9600 baud, polling operation
;----------------------------------------------------------------
;P2SEL=0x30;
; transmit and receive to port 2 b its 4 and 5
			mov.b #0x30,&P2SEL
; Bits p2.4 transmit and p2.5 receive UCA0CTL0=0
; 8 data, no parity 1 stop, uart, async
			mov.b #0x00,&UCA0CTL0
; (7)=1 (parity), (6)=1 Even, (5)= 0 lsb first,
; (4)= 0 8 data / 1 7 data, (3) 0 1 stop 1 / 2 stop, (2-1) --
; UART mode, (0) 0 = async
; UCA0CTL1= 0x41;
			mov.b #0x41,&UCA0CTL1
; select ALK 32768 and put in software reset the UART
; (7-6) 00 UCLK, 01 ACLK (32768 hz), 10 SMCLK, 11 SMCLK
; (0) = 1 reset
;UCA0BR1=0;
; upper byte of divider clock word
			mov.b #0x00,&UCA0BR1
;UCA0BR0=3; ;
; clock divide from a clock to bit clock 32768/9600 = 3.413
			mov.b #0x03,&UCA0BR0
; UCA0BR1:UCA0BR0 two 8 bit reg to from 16 bit clock divider
; for the baud rate
;UCA0MCTL=0x06;
; low frequency mode module 3 modulation pater used for the bit
; clock
			mov.b #0x06,&UCA0MCTL
;UCA0STAT=0;
; do not loop the transmitter back to the receiver for echoing
			mov.b #0x00,&UCA0STAT
; (7) = 1 echo back trans to rec
; (6) = 1 framing, (5) = 1 overrun, (4) =1 Parity, (3) = 1 break
; (0) = 2 transmitting or receiving data
;UCA0CTL1=0x40;
; take UART out of reset
			mov.b #0x40,&UCA0CTL1
;IE2=0;
; turn transmit interrupts off
			mov.b #0x00,&IE2
; (0) = 1 receiver buffer Interrupts enabled
; (1) = 1 transmit buffer Interrupts enabled
;----------------------------------------------------------------
;****************************************************************
;----------------------------------------------------------------
; IFG2 register (0) = 1 receiver buffer is full, UCA0RXIFG
; IFG2 register (1) = 1 transmit buffer is empty, UCA0RXIFG
; UCA0RXBUF 8 bit receiver buffer, UCA0TXBUF 8 bit transmit
; buffer
			ret
;----------------------------------------------------------------
; Interrupt Vectors
;----------------------------------------------------------------
			.sect	".reset"			; MSP430 RESET Vector
			.short	START ;
.end