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
			.sect ".sysmem"
			.bss buff,33

			.sect ".const"				; initialized data rom for
	 									; constants. Use this .sect to
										; put data in ROM

newLine		.byte 0x0d,0x0a 			; add a CR and a LF
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


mainLoop
			mov.b #0x32, R7				; Input counter
			mov.w #buff, R6

inLoop		call #INCHAR_UART
			call #OUTA_UART
			cmp.w #0x0d, R4
			jeq #inDone					; Enter detected
			mov.b R4, (R6)
			addi.w #0x01, R6
			addi.b #-1, R7				; decrmenet loop counter
			tst R7						; Check if more bits are needed
			jnz inLoop

inDone		mov.b #0x00, (R6)

			mov.w #newLine, R5			; newline address
			call #OUTA_STR_UART			; Print newline

			mov.w #buff, R5				; buffer address
			call #OUTA_STR_UART			; Print buffer

			mov.w #newLine, R5			; newline address
			call #OUTA_STR_UART			; Print newline

			mov.w #buff, R5				; buffer address
			call SORT_BYTE
			call #OUTA_STR_UART			; Print buffer

			mov.w #newLine, R5			; newline address
			call #OUTA_STR_UART			; Print newline

			jmp mainLoop				; Loop

SORT_BYTE
;----------------------------------------------------------------
; Sorts the byte array starting at register 5 and
; uses register 4 as a temp value
;----------------------------------------------------------------
			push R5
			push R4
			;
			pop R4
			pop R5
			ret

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

OUTH_UART
;----------------------------------------------------------------
; prints to the screen the Hex value stored in register 4 and
; uses register 5 as a temp value
;----------------------------------------------------------------
			push R4
			push R5
			mov.b R4, R5
			mul.b #0x10, R4
			add.b #strg1, R4			; Add offset of hex val relative to array start
			mov.b 0(R4), R4				; Hex[i>>4] (Getting char from string)
			call #OUTA_UART				; Prints char

			mov.b R5, R4
			bic.b #0x0F, R4				; Gets 4 lsb
			add.b #strg1, R4			; Prints char based on offset
			call #OUTA_UART

			pop R5
			pop R4
			rtn

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

INBIT_UART
;----------------------------------------------------------------
; returns a 1 or 0 value in register 4
; invalid inputs will return 1
;----------------------------------------------------------------
			call #INCHAR_UART
			call #OUTA_UART

			xor.b R4,R4,#0x30		; If input is '0' xor 0x30 = 0
			tst R4					; If it ends up being zero rtn
			JZ INBIT_ret
			mov.b #0x01,R4			; Else ret 1
INBIT_ret	ret

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
