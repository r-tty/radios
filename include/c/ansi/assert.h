#ifdef __cplusplus
extern "C" {
#endif

void __assertfail(char *__msg, char *__cond,
                  char *__file, int __line);

#ifdef __cplusplus
}
#endif

#ifdef NDEBUG
#define assert(p)   ((void)0)
#else
#define _ENDL "\n"
#define assert(p) ((p) ? (void)0 : (void) __assertfail( \
                   "Assertion failed: %s, file %s, line %d" _ENDL, \
                   #p, __FILE__, __LINE__ ) )
#endif
