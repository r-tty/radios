
typedef struct
   {
    ulong    j_ebp;
    ulong    j_ebx;
    ulong    j_edi;
    ulong    j_esi;
    ulong    j_esp;
    ulong    j_ret;
    ulong    j_excep;
    ulong    j_context;
   } jmp_buf[1];

void longjmp(jmp_buf JmpB, int RetVal);
int setjmp(jmp_buf JmpB);
