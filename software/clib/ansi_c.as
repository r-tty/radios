
; --- Definitions ---
bits 32

; --- Externals ---
extern ?KERNEL
extern Exit

extern ?KERNEL.MT
extern CreateThread,SuspendThread,ResumeThread
extern EnterCritSec,ExitCritSec

extern ?KERNEL.FS
extern Open,Close,Read,Write,Seek

; --- Code ---

section .text

		call	far Exit
