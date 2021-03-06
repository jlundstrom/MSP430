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

			.sect ".sysmem"				; initialized data rom for
	 									; constants. Use this .sect to
										; put data in ROM
strg1		.string "SW1 = 0, SW2 = 0"
										; String used for print function
	 									; in ROM
			.byte 0x0d,0x0a 			; add a CR and a LF
			.byte 0x00					; null terminate the string with

; This is the code area flash begins at address 0x3100 can be
; used for program code or constants

			.text 						; program start
			.global _START 				; define entry point
;----------------------------------------------------------------
START		mov.w #300h,SP				; Initialize 'x1121
	 									; stackpointer
StopWDT		mov.w #WDTPW+WDTHOLD,&WDTCTL	; Stop WDT
SetupP2		bis.b #02h,&P2DIR			; P2.2 output

			call #Init_UART				; go initialize the uart

			mov.b #0x00,R6				; Zero out current SW status

mainLoop
			mov.b P1IN,R4				; Loop untill button state change
			and.b #0x03,R4				; Filter out everything but SW1 & SW2
			cmp.b R4,R6					; Did SW status change?
			jeq mainLoop					; Check again if no

			mov.w R4,R6					; Set status to current button press

			mov.w #strg1,R5				; Load pointer

			and.b #0x01,R4				; Filter down to only SW1
			cmp.b #0x00,R4
			jz	setSW1_0				; Set to zero if its pressed
			mov.b #0x31,6(R5)			; Otherwise set SW1 status char to '1'
			jmp checkSW2
setSW1_0	mov.b #0x30,6(R5)			; Set SW1 status char to '0'

checkSW2	mov.b R6,R4					; Get full status register
			and.b #0x02,R4				; Get SW2 status
			cmp.b #0x00,R4
			jeq setSW2_0				; Check SW2 current case
			mov.b #0x31,15(R5)			; If not pressed set SW2 status to '1'
			jmp print
setSW2_0	mov.b #0x30,15(R5)			; Set SW2 status char to '0'

print
			call #OUTA_STR_UART			; Print string with modified status

			jmp mainLoop				; Loop and wait for next status change

OUTA_STR_UART
;----------------------------------------------------------------
; prints to the screen the ASCII String starting at register 5 and
; uses register 4 as a temp value
;----------------------------------------------------------------
			push R4						; Store R5&R4 because we overwite them
			push R5

getChar		mov.b 0(R5),R4				; Get char at Address
			cmp.b #0x00,R4				; Is it the null terminator?
			jz RtnPrint					; If so return
			call #OUTA_UART				; Else Call print char command
			inc R5						; Increment to next address
			jmp getChar					; Get the next character


RtnPrint	pop R5						; Restore registers we modified
			pop R4
			ret							; Return to caller

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
