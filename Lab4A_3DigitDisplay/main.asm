;----------------------------------------------------------------------
; LCD Driver for the for MSP 430X4XXX experimenter board using
; Softbaugh LCD
; Davies book pg 259, 260
; setup a pointer to the area of memory of the TMS430 that points to
; the segments
; of the softbaugh LCD LCDM3 = the starting address
;----------------------------------------------------------------------
		.cdecls C,LIST,"msp430fg4618.h" ; cdecls tells assembler
										; to allow
										; the device header file
;----------------------------------------------------------------------

; #LCDM3 is the start of the area of memory of the TMS430 that points
; to the segments
; of the softbaugh LCD LCDM3 = the starting address
; each of the seven segments for each display is store in memory
; starting at address LCDM3
; which is the right most seven segment of the LCD
; The bit order in each byte is
; dp, E, G, F, D, C, B, A or
; :, E, G, F, D, C, B, A
; after the seven segments these memory locations are used to turn on
; the special characters
; such as battery status, antenna, f1-f4, etc.
; there are 7 seven segment displays

;	data area ram starts 0x1100
;----------------------------------------------------------------------
;	the .sect directives are defined in lnk_msp430f4618.cmd
;			.sect ".stack"		; data ram for the stack
			.sect ".sysmem"		; data rom for initialized data
								; constants
		; there are 11 locations that are needed for the softbaugh LCD
		; only 7 used for the seven segment displays
LCD_SIZE	.byte 11				; eleven bytes needed by the LCD
Digits		.byte 	0x5f, 0x06, 0x6b, 0x2f, 0x36, 0x3d, 0x7d, 0x07, 0x7f, 0x37, 0x77, 0x7c, 0x59, 0x6e, 0x79, 0x71
;			.sect ".text"		; program rom for code
;			.sect ".cinit"		; program rom for global inits
;			.sect ".reset"		; MSP430 RESET Vector
;			.sect ".sysmem"		; data ram for initialized
								; variables



; This is the code area
; flash begins at address 0x3100
;----------------------------------------------------------------------
; Main Code
;----------------------------------------------------------------------

			.text 						; program start
			.global _START 				; define entry point
;----------------------------------------------------------------
START		mov.w #300h,SP				; Initialize 'x1121
	 									; stackpointer
StopWDT		mov.w #WDTPW+WDTHOLD,&WDTCTL	; Stop WDT
SetupP2		bis.b #02h,&P2DIR			; P2.2 output
			bic.w #0x03, &P1DIR			; Enable SW as input

		; go initialize the LCD Display
			call #Init_LCD

		; LCD_SIZE-4 only gives the 7 segment displays plus DP, and
		; colons (colons = dp)
		; Right most display is at LCDSeg[0];
		; R6 is a loop counter to cover all of the segments. This count
		; counts up from 0
			mov.b #0x00, R6
		; R5 points to the beginning memory for the LCD
		; Turn on all of the segments
		; LCD_SIZE-4 only gives the 7 segment displays plus DP, and
		; colons: colons = dp
		; Right most display is at LCDSeg[0];
		; To turn on a segment of the LCD a one is written in the
		; the appropriate location in the LCD memory
		; Setting all the bits to 1 for all memory locations turns on
		; all of the display elements
		; including all special characters
		; move 0xff into R7 to turn on all LCD segments the LCD memory
			mov.w #0x00, R5
Mainloop	mov.b P1IN, R4
			and.b #0x03, R4
			cmp #0x01, R4
			jeq Dec
			cmp #0x02, R4
			jeq Inc
			jmp Wait

Dec			dec.w R5
			jmp Wait
Inc			inc.w R5

Wait		call #RollOverForDec
			call #SetLCD
			mov.w #0x00001,R14 			; Delay to R15
L2			mov.w #0xFFFFF,R15 			; Delay to R15
L1			dec.w R15					; Decrement R15
			jnz L1						; Delay over?
			dec.w R14
			jnz L2


			jmp Mainloop				; Again

;----------------------------------------------------------------------
; Deals with rolling over values to keep it Dec Aligned
;----------------------------------------------------------------------
RollOverForDec
		; Input and output is R5
			push R6

			mov.w R5, R6
			and.w #0x00F, R6
			cmp.w #0x00A, R6
			jne jmp1
			add.w #0x06, R5
jmp1		cmp.w #0x00F, R6
			jne jmp2
			sub.w #0x06, R5

jmp2		mov.w R5, R6
			and.w #0x0F0, R6
			cmp.w #0x0A0, R6
			jne jmp3
			add.w #0x60, R5
jmp3		cmp.w #0x0F0, R6
			jne jmp4
			sub.w #0x60, R5

jmp4		mov.w R5, R6
			and.w #0xF00, R6
			cmp.w #0xA00, R6
			jne jmp5
			add.w #0x600, R5
jmp5		cmp.w #0xF00, R6
			jne jmp6
			sub.w #0x600, R5

jmp6		pop R6
			ret

;----------------------------------------------------------------------
; Prints a BCD Stored in a word 4-bits per digit
;----------------------------------------------------------------------
SetLCD
		; Input is R5
			push R5
			push R6
			push R7
			push R8
			mov.w #0x00, R6
SetLCDFor	cmp.w #0x03, R6
			jz SetLCDRtn
			mov.w R5, R7
			and.w #0x0F, R7
			add.w #Digits, R7
			mov.w #LCDM3, R8
			add.w R6, R8

			mov.b 0(R7), 0(R8)

			rra.w R5
			rra.w R5
			rra.w R5
			rra.w R5

			inc.b R6
			jmp SetLCDFor

SetLCDRtn	pop R8
			pop R7
			pop R6
			pop R5
			ret

;----------------------------------------------------------------------
; Initialize the LCD system
;----------------------------------------------------------------------
Init_LCD
		; Using the LCD A controller for the MSP430fg4618
		; the pins of the LCD are memory mapped onto the mp430F4xxx
		; memory bus and
		; are accessed via LCDSeg[i] array
		; See page 260 of Davie's text
		; LCD_SIZE-4 only gives the 7 segment displays plus DP, and
		; (colons are the same bit setting)
		; LCD_SIZE-4 only gives the 7 segment displays plus DP, and
		; colons: colons / dp
		; Right most seven segment display is at LCDSeg[0];
		; Display format
		;			 AAA
		; 			F	B
		;		X 	F	B
		; 			 GGG
		; 		X	E	C
		; 			E	C
		;		DP	 DDD
		; bit order
		; dp, E, G, F, D, C, B, A or
		;  :, E, G, F, D, C, B, A
		; initialize the segment memory to zero to clear the LCD
		; writing a zero in the LCD memory location clears turns off
		; the LCD segment
		; R6 is a loop counter to cover all of the segments
		; including all special characters
			mov.b #0x00, R6
		; R5 points to the beginning memory for the LCD
			mov.w #LCDM3, R5
		; move 0 into R7 to clear the LCD memory
			mov.b #0x00, R7
lpt			mov.b R7, 0(R5)
		; Increment R5 to point to the next seven segment display
		; Increment R6 for the next count in the loop
			inc.w R5
			inc.b R6
		; See if the loop is finished
			cmp.b LCD_SIZE, R6
			jnz lpt
		; Port 5 ports 5.2-5.4 are connected to com1,com2,com3 of LCD
		; com0 fixed and already assigned
		; Need to assign com1 - com3 to port5
		; BIT4 | BIT3 |BIT2 = 1 P5.4, P.3, P5.2 = 1
			mov.b #0x1C, &P5SEL
		; Used the internal voltage for the LCD bit 4 = 0 (VLCDEXT=0)
		; internal bias voltage set to 1/3 of Vcc, charge pump
		; disabled,
		; page 26-25 of MSP430x4xx user manual
			mov.b #0x00, &LCDAVCTL0
		; LCDS28-LCDS0 pins LCDS0 = lsb and LCDS28 = MSB need
		; LCDS4 through LCDS24
		; from the experimenter board schematic the LCD uses S4-S24,
		; S0-S3 are not used here
		; Only use up to S24 on the LCD 28-31 not needed.
		; Also LCDACTL1 not required since not using S32 - S39
		; Davie's book page 260
		; page 26-23 of MSP430x4xx user manual
			mov.b #0x7E, &LCDAPCTL0
		; The LCD uses the ACLK as the master clock as the scan
		; rate for the display segments
		; The ACLK has been set to 32768 Hz with the external 327768 Hz
		; crystal
		; Let's use scan frequency of 256 Hz (This is fast enough not
		; to see the display flicker)
		; or a divisor of 128
		; LCDFREQ division(3 bits), LCDMUX (2 bits), LCDSON segments
		; on, Not used, LCDON LCD module on
		; 011 = freq /128, 11 = 4 mux's needed since the display uses
		; for common inputs com0-com3
		; need to turn the LCD on LCDON = 1
		; LCDSON allows the segments to be blanked good for blinking
		; but needs to be on to
		; display the LCD segments LCDSON = 1
		; Bit pattern required = 0111 1101 = 0x7d
		; page 26-22 of MSP430x4xx user manual
			mov.b #0x7d, &LCDACTL
			ret
;----------------------------------------------------------------------
; Interrupt Vectors
;----------------------------------------------------------------------
			.sect ".reset" ; MSP430 RESET Vector
			.short START ;
			.end
