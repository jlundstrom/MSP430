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
strg1		.string	"0123456789ABCDEF"
MHeader		.string	"M["
CRLF		.byte 0x0d,0x0a 			; add a CR and a LF
			.byte 0x00					; null terminate the string with
			.byte 0x00					; null terminate the string with

MATHRES		.string " C=_, Z=_, N=_"
			.byte 0x00

MemPointer	.byte 0x00					; null terminate the string with

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
			mov.w #CRLF,R5				; Prints a new lines
			call #OUTA_STR_UART

			mov.b #0x3e, R4				; Prints "> "
			call #OUTA_UART
			mov.b #0x20, R4
			call #OUTA_UART

			call #INCHAR_UART			; Get and print user input
			call #OUTA_UART

			cmp #0x4d, R4				; If 'M' go to Memory Mode
			jeq MEM_MODE

			cmp #0x44, R4				; If 'D' go to Data/Hex Dump Mode
			jeq DATA_MODE

			cmp #0x48, R4				; If 'H' go to Math Mode
			jeq MATH_MODE


			jmp mainLoop				; Loop and wait for next status change

MEM_MODE
;----------------------------------------------------------------
; Enters Memory Mode - register 6 will hold the active address
;----------------------------------------------------------------
			call #GET_HEX_WORD
			mov.w R5, MemPointer

			mov.w #CRLF,R5				; String Pointer
			call #OUTA_STR_UART

Core_Mem	mov.b #0x4d, R4				; Prints "M["
			call #OUTA_UART
			mov.b #0x5b, R4
			call #OUTA_UART

			mov.w MemPointer, R4		; Prints Memory Cursor
			call #PRINT_HEX_WORD		; "M[BEEF"

			mov.b #0x5d, R4				; Prints "]>"
			call #OUTA_UART				; "M[BEEF]>"
			mov.b #0x3e, R4
			call #OUTA_UART

			call #INCHAR_UART			; Get User Input
			call #OUTA_UART

			cmp #0x50, R4				; 'P' Goto Memory Increment
			jeq Core_Mem_Inc

			cmp #0x4E, R4				; 'N' Goto Memory Decrement
			jeq Core_Mem_Dec

			cmp #0x20, R4				; ' ' Return to Main Program
			jeq mainLoop

			cmp #0x52, R4				; 'R' Goto Print data @ Address
			jeq Core_Mem_Print

			cmp #0x57, R4				; 'W' Goto Write Data @ Address
			jeq Core_Mem_Write

Core_Mem_N	mov.w #CRLF,R5				; Print Newline
			call #OUTA_STR_UART
			jmp Core_Mem				; Stay in Memory Mode


Core_Mem_Inc
			inc.w MemPointer
			jmp Core_Mem_N

Core_Mem_Dec
			dec.w MemPointer
			jmp Core_Mem_N

Core_Mem_Print
			mov.w #CRLF,R5				; Print newline
			call #OUTA_STR_UART
			mov.w MemPointer, R4		; Gets location of Memory Cursor
			mov.w 0(R4), R4				; Gets data @ Address
			call #PRINT_HEX_WORD		; Prints hex representation
			jmp Core_Mem_N				; Return to Memory Mode

Core_Mem_Write
			call #GET_HEX_WORD			; Get data from user
			mov.w MemPointer, R4		; Save to Address
			mov.w R5, 0(R4)
			jmp Core_Mem_N				; Return to Memory Mode

DATA_MODE
			call #GET_HEX_WORD			; Get Starting Address
			mov.w R5, R6
			call #GET_HEX_WORD			; Get Ending Address
			mov.w R5, R7
			; add.w #0x02, R7			; Adds offset to be inclusive
										; Todo: add support for sets not divisable by 16

			mov.w #CRLF,R5				; String Pointer
			call #OUTA_STR_UART

			mov.b #0x00, R8

Data_loop
			mov.w @R6, R4				; Read current starting address and print it
			call #PRINT_HEX_WORD
			add.w #0x02, R6

			mov.b #0x20, R4				; Print ' '
			call #OUTA_UART

			inc.b R8
			cmp.b #0x08, R8
			jeq Data_Mode_CRLF

Data_Mode_Rtn
			cmp.w R7, R6
			jl	Data_loop

Data_Mode_N
			mov.w #CRLF,R5				; Prints newline
			call #OUTA_STR_UART
			jmp mainLoop

Data_Mode_CRLF
			call #PRINT_ASCII_Line
			mov.w #CRLF,R5				; Prints newline
			call #OUTA_STR_UART
			mov.w #0x00, R8
			jmp Data_Mode_Rtn


PRINT_ASCII_Line
;----------------------------------------------------------------
; Prints 16 bytes behind register 6 as a clean string
;----------------------------------------------------------------
			push R5
			push R8
			mov.w R6, R8
			add.w #-0x10, R8

Print_Ascii_Loop
			mov.w 0(R8), R5				; Get data @ Address
			swpb R5						; Print left half
			call #PRINT_CLEAN_ASCII
			swpb R5
			call #PRINT_CLEAN_ASCII		; Print right half
			add.w #0x02, R8
			cmp.w R8, R6
			jne Print_Ascii_Loop

			pop R8
			pop R5
			ret


PRINT_CLEAN_ASCII
;----------------------------------------------------------------
; Prints the value stroed in register 5 as a ASCII only if valid
;----------------------------------------------------------------
			push R4
			cmp.b #0x21, R5				; Check if printable ascii char
			jl Print_Dot
			cmp.b #0x7F, R5
			jge Print_Dot

			mov.b R5, R4				; Otherwise print valid char
			call #OUTA_UART
			pop R4
			ret

Print_Dot	mov.b #0x2E, R4				; Prints '.'
			call #OUTA_UART
			pop R4
			ret

MATH_MODE
			push R5
			push R4
			push R6
			call #INCHAR_UART			; Get math mode
			call #OUTA_UART

			cmp #0x41, R4				; 'A' Goto Add
			jeq ADD_MATH

			cmp #0x53, R4				; 'S' Goto Sub
			jeq SUB_MATH

RTN_MATH	pop R6
			pop R4
			pop R5
			jmp mainLoop

ADD_MATH
			call #GET_HEX_WORD
			mov.w R5, R6
			call #GET_HEX_WORD
			add.w R6, R5
			mov.w R2, R6

			jmp MATH_PRINT

SUB_MATH
			call #GET_HEX_WORD
			mov.w R5, R6
			call #GET_HEX_WORD
			sub.w R6, R5
			mov.w R2, R6

MATH_PRINT	mov.w R5, R4

			mov.w #CRLF,R5
			call #OUTA_STR_UART

			call #PRINT_HEX_WORD

			mov.w #MATHRES,R5

			; " C=_, N=_, Z=_"
			mov.w R6, R4
			and.w #0x01, R4				; Take first bit and add to 0x30
			add.b #0x30, R4
			mov.b R4, 3(R5)				; Store at C position
			rra R6						; Shift and take first bit and add to 0x30
			mov.w R6, R4
			and.w #0x01, R4
			add.b #0x30, R4
			mov.b R4, 8(R5)				; Store at N position
			rra R6						; Shift and take first bit and add to 0x30
			mov.w R6, R4
			and.w #0x01, R4
			add.b #0x30, R4
			mov.b R4, 13(R5)			; Store at Z position

			call #OUTA_STR_UART

			jmp RTN_MATH

OUTH_UART
;----------------------------------------------------------------
; prints to the screen the Hex value stored in register 4 and
; uses register 5 as a temp value
;----------------------------------------------------------------
			push R4
			push R5
			mov.b R4, R5
			rra.b R4
			rra.b R4
			rra.b R4
			rra.b R4
			and.w #0x0F, R4
			add.w #strg1, R4			; Add offset of hex val relative to array start
			mov.b 0(R4), R4				; Hex[i>>4] (Getting char from string)
			call #OUTA_UART				; Prints char

			mov.b R5, R4
			and.w #0x0F, R4				; Gets 4 lsb
			add.w #strg1, R4			; Prints char based on offset
			mov.b 0(R4), R4				; Hex[i>>4] (Getting char from string)
			call #OUTA_UART

			pop R5
			pop R4
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

PRINT_HEX_WORD
;----------------------------------------------------------------
; Prints the value stroed in register 4 as a hex value
;----------------------------------------------------------------
			swpb R4
			call #OUTH_UART
			swpb R4
			call #OUTH_UART
			ret

GET_HEX_WORD
;----------------------------------------------------------------
; Requests 16-bits worth of hex data from user
; uses register 4 as a temp value and returns in R5
;----------------------------------------------------------------
			push R4
			mov.w #0x00, R5
			call #GET_HEX_VALUE
			mov.b R4, R5
			rlc.b R5					; Need to shift 4 times or mul by 16
			rlc.b R5					; So 0x0F -> 0xF0
			rlc.b R5
			rlc.b R5
			bic.b #0x0F, R5
			call #GET_HEX_VALUE
			bis.b R4, R5

			swpb R5						; e.g. 0x33FF -> 0xFF33
			call #GET_HEX_VALUE
			rlc.w R4					; Need to shift 4 times or mul by 16
			rlc.w R4
			rlc.w R4
			rlc.w R4
			and.w #0xF0, R4
			bis.w R4, R5
			call #GET_HEX_VALUE
			bis.w R4, R5
			pop R4
			ret

GET_HEX_VALUE
;----------------------------------------------------------------
; Gets a character from the screen and converts it to hex if its
; Returns in R4 					e.g. '2' => 0x2 and 'F' => 0xF
;----------------------------------------------------------------
			call #INCHAR_UART
			call #OUTA_UART

			cmp #0x3A, R4
			jge chkAlpha				; '0'-'9' is 0x30-0x39
			cmp #0x30, R4
			jl chkAlpha
			and.b #0x0F, R4				; Return first 4 bits set
			jmp RtnGHV
chkAlpha	cmp #0x47, R4
			jge	Invalid					; 'A'-'F' is 0x41-0x46
			cmp #0x41, R4
			jl Invalid
			sub.b #0x37, R4				; 0x37 is offset from ascii
			jmp RtnGHV
Invalid		jmp GET_HEX_VALUE			; if invalid Try Again
RtnGHV		and.w #0x0F, R4
			ret

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
