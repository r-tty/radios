;-------------------------------------------------------------------------------
; timers.nasm - timer system calls.
;-------------------------------------------------------------------------------

module tm.kern.timers

%include "sys.ah"
%include "errors.ah"
%include "pool.ah"
%include "hash.ah"
%include "thread.ah"
%include "time.ah"
%include "tm/kern.ah"
%include "tm/process.ah"

publicproc TM_InitTimers
publicdata TimerSyscallTable

importproc K_PoolInit, K_PoolAllocChunk, K_PoolFreeChunk, K_PoolChunkNumber
importproc K_CreateHashTab, K_FreeHashTab
importproc K_HashLookup, K_HashAdd, K_HashRelease
importproc K_SemV, K_SemP, BZero
importdata ?TicksCounter

struc tTimerDesc
.PCB		RESD	1
.State		RESD	1
.Ticks		RESD	1
.Sem		RESB	tSemaphore
.Next		RESD	1
.Prev		RESD	1
endstruc

MAX_TIMEOUTS	EQU	10

TM_ST_FREE 	EQU	0
TM_ST_ALLOC	EQU	1


section .data

TimerSyscallTable:
mSyscallTabEnt TimerCreate, 2
mSyscallTabEnt TimerDestroy, 1
mSyscallTabEnt TimerSettime, 4
mSyscallTabEnt TimerInfo, 4
mSyscallTabEnt TimerAlarm, 3
mSyscallTabEnt TimerTimeout, 5
mSyscallTabEnt 0


section .bss

?TimerCount	RESD	1
?MaxTimers	RESD	1
?TimerPool	RESB	tMasterPool_size
?TimerListHead	RESD	1
?TimerHashPtr	RESD	1

?TimeoutQue	RESD	1	; Address of timeout queue
?TimeoutTrailer	RESB	tTimerDesc_size
?TimeoutPool	RESB	tTimerDesc_size*MAX_TIMEOUTS


section .text

		; Initialize timer pool and hash table.
		; Input: EAX=maximum number of timers.
		; Output: CF=0 - OK;
		;	  CF=1 - error, AX=error code.
proc TM_InitTimers
		mpush	ebx,ecx,edx
		mov	[?MaxTimers],eax
		xor	edx,edx
		mov	[?TimerListHead],edx
		mov	ebx,?TimerPool
		mov	ecx,tITimer_size
		call	K_PoolInit
		jc	.Done
		call	K_CreateHashTab
		jc	.Done
		mov	[?TimerHashPtr],esi
.Done:		mpop	edx,ecx,ebx
		ret
endp		;---------------------------------------------------------------


; --- System calls -------------------------------------------------------------


		; int TimerCreate(clockid_t id, const struct sigevent *event);
proc sys_TimerCreate
		arg	id, event
		prologue

		Cmp32	?TimerCount,?MaxTimers
		jae	.Again

		; Allocate a timer descriptor and zero it
.AllocDesc:	mov	ebx,?TimerPool
		call	K_PoolAllocChunk
		jc	.Again
		mov	ebx,esi
		mov	ecx,tTimerDesc_size
		call	BZero
		inc	dword [?TimerCount]

		; Timer is considered to be owned by a calling process
		mCurrThread
		mov	ebx,[eax+tTCB.PCB]
		mov	[esi+tTimerDesc.PCB],ebx
		mEnqueue dword [eax+tProcDesc.TimerList], Next, Prev, esi, tTimerDesc, ecx

		; We use the chunk number as the identifier and PCB address
		; as the key for hashing.
		call	K_PoolChunkNumber
		mov	ecx,eax
		mov	edi,esi
		mov	esi,[?TimerHashPtr]
		call	K_HashAdd
		mov	eax,ecx

.Exit:		epilogue
		ret

.Again:		mov	eax,-EAGAIN
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int TimerDestroy(timer_t id);
proc sys_TimerDestroy
		arg	id
		prologue

		mCurrThread
		mov	ebx,[eax+tTCB.PCB]
		mov	eax,[%$id]
		call	K_HashLookup
		jc	.Invalid

		mov	esi,[edi+tHashElem.Data]
		call	K_PoolFreeChunk
		dec	dword [?TimerCount]
		call	K_HashRelease

.Exit:		epilogue
		ret

.Invalid:	mov	eax,-EAGAIN
		jmp	.Exit
endp		;---------------------------------------------------------------


		; int TimerSetTime(timer_id id, int flags,
		;	 const struct itimer *itime, struct itimer *otime);
proc sys_TimerSettime
		arg	id, flags, itime, otime
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerInfo(pid_t pid, timer_t id, int flags,
		;		struct timer_info *info);
proc sys_TimerInfo
		arg	pid, id flags, info
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerAlarm(clockid_t id, const struct itimer *itime,
		;		 struct itimer *otime);
proc sys_TimerAlarm
		arg	id, itime, otime
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int TimerTimeout(clockid_t id, int flags,
		;		   const struct sigevent *notify,
		;		   const uint64 *ntime, uint64 *otime)
proc sys_TimerTimeout
		arg	id, flags, notify, ntime, otime
		prologue
		MISSINGSYSCALL
		epilogue
		ret
endp		;---------------------------------------------------------------


;------ Old timeout stuff-------------------------------------------------------

		; MT_InitTimerDesc - initialize timeout pool.
		; Input: none.
		; Output: none.
proc MT_InitTimerDesc
		mov	ecx,MAX_TIMEOUTS
		mov	ebx,?TimeoutPool
.InitQLoop:	mov	byte [ebx+tTimerDesc.State],TM_ST_FREE
		add	ebx,tTimerDesc_size
		loop	.InitQLoop

		mov	ebx,?TimeoutTrailer
		mov	dword [ebx+tTimerDesc.Ticks],-1
		mov	byte [ebx+tTimerDesc.State],TM_ST_ALLOC

		; Enqueue trailer
		mEnqueue dword [?TimeoutQue], Next, Prev, ebx, tTimerDesc, ecx
		ret
endp		;---------------------------------------------------------------


		; MT_SetTimerDesc - set timeout.
		; Input: ECX=number of ticks.
		; Output: none.
proc MT_SetTimerDesc
		; We just hunt for free timeout slot.
		; Goin' do it when interrupts are disabled.
		pushfd
		cli
		mov	eax,ecx
		mov	ecx,MAX_TIMEOUTS
		mov	ebx,?TimeoutPool
.HuntLoop:	cmp	byte [ebx+tTimerDesc.State],TM_ST_FREE
		je	.Init
		add	ebx,tTimerDesc_size
		loop	.HuntLoop
		jmp	.NoSpace

		; Initialize this timeout.
		; Set its ticks value to current system ticks plus
		; the amount of ticks it wants to wait; makes searching
		; the timeout queue easier.
.Init:		mov	byte [ebx+tTimerDesc.State],TM_ST_ALLOC
		add	eax,[?TicksCounter]
		mov	[ebx+tTimerDesc.Ticks],eax
		push	ebx
		lea	ebx,[ebx+tTimerDesc.Sem]
		mSemInit ebx
		xor	eax,eax
		mSemSetVal ebx
		pop	ebx

		; Go through the timeout queue until we reach
		; the one with higher timeout ticks than this one.
		; This results in having timeout queue sorted
		; by timeout ticks in ascending order.
		mov	edx,[?TimeoutQue]
.SearchLoop:	mov	eax,[ebx+tTimerDesc.Ticks]
		cmp	[edx+tTimerDesc.Ticks],eax
		ja	.Insert
		mov	edx,[edx+tTimerDesc.Next]
		jmp	.SearchLoop

		; Insert this one before the one found above.
.Insert:	mov	[ebx+tTimerDesc.Next],edx
		mov	eax,[edx+tTimerDesc.Prev]
		mov	[ebx+tTimerDesc.Prev],eax
		mov	[eax+tTimerDesc.Next],ebx
		mov	[edx+tTimerDesc.Prev],ebx
		cmp	edx,[?TimeoutQue]
		jne	.1
		mov	[edx+tTimerDesc.Prev],ebx

.1:		popfd
		; Now actually wait for the timeout to elapse
		; we have previously initialized the semaphore
		; to non-singnaled state, so we block here
		lea	eax,[ebx+tTimerDesc.Sem]
		call	K_SemP
		ret

.NoSpace:	popfd
		ret
endp		;---------------------------------------------------------------


		; MT_CheckTimeout - go through timeouts queue and release
 		;		    those that expired.
		; Input: none.
		; Output: none.
proc MT_CheckTimeout
		mpush	ebx,edx
		pushfd
		cli
		
		mov	edx,[?TimeoutQue]
.ChkLoop:	mov	eax,[?TicksCounter]
		cmp	eax,[edx+tTimerDesc.Ticks]
		jb	.Done
		lea	eax,[edx+tTimerDesc.Sem]
		call	K_SemV
		mDequeue dword [?TimeoutQue], Next, Prev, edx, tTimerDesc, ebx
		mov	edx,[edx+tTimerDesc.Next]
		jmp	.ChkLoop
		
.Done:		popfd
		mpop	edx,ebx
		ret
endp		;---------------------------------------------------------------
