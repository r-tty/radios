
typedef long fpos_t;

extern void clearerr (FILE*);
extern int fclose (FILE*);
extern int feof (FILE*);
extern int ferror (FILE*);
extern int fflush (FILE*);
extern int fgetc (FILE *);
extern int fgetpos (FILE* fp, fpos_t *pos);
extern char* fgets (char*, int, FILE*);
extern FILE* fopen (const char*, const char*);
extern int fprintf (FILE*, const char* format, ...);
extern int fputc (int, FILE*);
extern int fputs (const char *str, FILE *fp);
extern size_t fread (void*, size_t, size_t, FILE*);
extern FILE* freopen (const char*, const char*, FILE*);
extern int fscanf (FILE *fp, const char* format, ...);
extern int fseek (FILE* fp, long int offset, int whence);
extern int fsetpos (FILE* fp, const fpos_t *pos);
extern long int ftell (FILE* fp);
extern size_t fwrite (const void*, size_t, size_t, FILE*);
extern int getc (FILE *);
extern int getchar (void);
extern char* gets (char*);
extern void perror (const char *);
extern int printf (const char* format, ...);
extern int putc (int, FILE *);
extern int putchar (int);
extern int puts (const char *str);
extern int remove (const char*);
extern int rename (const char* _old, const char* _new);
extern void rewind (FILE*);
extern int scanf (const char* format, ...);
extern void setbuf (FILE*, char*);
extern void setlinebuf (FILE*);
extern void setbuffer (FILE*, char*, int);
extern int setvbuf (FILE*, char*, int mode, size_t size);
extern int sprintf (char*, const char* format, ...);
extern int sscanf (const char* string, const char* format, ...);
extern FILE* tmpfile (void);
extern char* tmpnam (char*);
extern int ungetc (int c, FILE* fp);
extern int vfprintf (FILE *fp, char const *fmt0, void *arglist);
extern int vprintf (char const *fmt, void *arglist);
extern int vsprintf (char* string, const char* format, void *arglist);

#define putchar(c) putc(c, stdout)
#define getchar() getc(stdin)

