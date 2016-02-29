



				mov.w #0x08, R6				; C = 8
ForConditional	tst.w R6					; c > 0
				jz ForBreak					; c == 0 then jump


				rla.b R5					; o = o << 1



				call #INCHAR_UART			; R4 = INCHAR_UART()


				call #OUTA_UART				; OUTA_UART(R4)


				cmp.w #0x31, R4				; null <= '1' - i
				jne ForContinue


				bis.b #0x1, R5


ForContinue		sub.w #1, R6
				jmp ForConditional
ForBreak
				mov.w R4, &C
