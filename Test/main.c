/*
 * main.c
 */
void main(void) {
	int c;
	volatile unsigned char o;
	volatile unsigned char i;
	for (c = 8; c > 0; c--) {



		o = o << 1;


		i = INCHAR_UART(); // Get next character

		OUTA_UART(i); // Echo back input


		if (i == '1')



			o = o | 1;




	}
}
