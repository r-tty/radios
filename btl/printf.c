/*
 * Routines for printf
 */

#include <stdarg.h>

#define isdigit(d) ((d) >= '0' && (d) <= '9')
#define Ctod(c) ((c) - '0')

/*
 * Convert the integer D to a string and save the string in BUF. If
 * BASE is equal to 'd', interpret that D is decimal, and if BASE is
 * equal to 'x', interpret that D is hexadecimal
 */
void itoa(char *buf, int base, int d)
{
    char *p = buf;
    char *p1, *p2;
    unsigned long ud = d;
    int divisor = 10;
    char hc = (base == 'X') ? 'A' : 'a';
    
    /* If %d is specified and D is minus, put `-' in the head.  */
    if (base == 'd' && d < 0) {
	    *p++ = '-';
	    buf++;
	    ud = -d;
    } else if (base == 'x' || base == 'X')
	divisor = 16;

    /* Divide UD by DIVISOR until UD == 0 */
    do {
	int remainder = ud % divisor;
      
        *p++ = (remainder < 10) ? remainder + '0' : remainder + hc - 10;
    } while (ud /= divisor);

    /* Terminate BUF */
    *p = 0;
  
    /* Reverse BUF */
    p1 = buf;
    p2 = p - 1;
    while (p1 < p2) {
	char tmp = *p1;
	*p1 = *p2;
	*p2 = tmp;
	p1++;
	p2--;
    }
}


/*
 * Mini-printf
 */
void printf (const char *fmt, ...)
{
    char **arg = (char **) &fmt;
    int c, i, leftadj = 0, padlen = 0;
    char buf[20];

    arg++;
  
    while ((c = *fmt++) != 0) {
	if (c != '%')
	    putchar (c);
        else {
	    char *p;
	    int len = 0, putsuffix = 0;
check:
	    c = *fmt++;
	    switch (c) {
		case 'X':			/* Hex number */
		case 'x':
		case 'd':			/* Decimal number */
		case 'u':
		    itoa (buf, c, *((int *) arg++));
	    	    p = buf;
		    goto string;

		case 's':			/* String */
	    	    p = *arg++;
	    	    if (!p)
			p = "(null)";
string:
		    if (padlen) {
			char *q = p;
			/* calculate string length first */
			while (*q++)
			    len++;
			if (!leftadj)
			    for (i = 0; i < padlen - len; i++)
				putchar(' ');
		    }
		    /* Print the string itself */
	    	    while (*p)
			putchar (*p++);
		    /* Print suffix if requested */
		    if (putsuffix) {
			switch (c) {
			    case 'X':
			    case 'x':
				putchar('h');
				break;
			    case 'B':
			    case 'b':
			    case 'o':
				putchar(c);
			}
			len++;
		    }
		    /* Pad with spaces if requested */
		    if (leftadj && padlen)
			    for (i = 0; i < padlen - len; i++)
				putchar(' ');
		    padlen = leftadj = 0;
	    	    break;

		case '#':			/* Print suffix for numbers */
		    putsuffix = 1;
		    goto check;

		case '-':			/* Left adjustment */
		    leftadj = 1;
		    /* Fall through */
		default:
		    if (isdigit(*fmt)) {
			while (isdigit(*fmt))
			    padlen = 10 * padlen + Ctod(*fmt++);
			goto check;
		    }
	    	    putchar (*((int *) arg++));
	    	    break;
	    }
	}
    }
}
