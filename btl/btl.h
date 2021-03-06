/*
 * btl.h - definitions and function prototypes
 */

#define	KERNIMG		0x110000	/* Kernel image is loaded here */
#define	KERNSTART	0x4000		/* ...and its .text will be here */
#define BOOTPARM	0x107C00	/* Boot parameters area */
#define MEMMAP		0x108000	/* BIOS memory map area */

#define MAXMODULES	64		/* Maximum number of boot modules */

void putchar(char c);
void puts(char *s);
char getc(void);

void printf(const char *fmt, ...);
void panic(const char *fmt, ...);

void printlong(unsigned long u);
