;-------------------------------------------------------------------------------
;  ints.asm - interrupt handlers.
;-------------------------------------------------------------------------------

include "portsdef.ah"
include "pic.ah"

macro mIntHandler Num,Procedure
proc Int&Num&Handler
	IFNB <Procedure>
	mov	[ExceptionNum],Num
	call	Procedure
	ENDIF
	iret
endp
endm

segment KDATA
ExceptionNum	DB	0			; Exception number
ExcPrintPos	DB	0
ends


mIntHandler Reserved
mIntHandler 0,K_TmpExcHandler
mIntHandler 1,K_TmpExcHandler			; Temporary exception handler
mIntHandler 2,K_TmpExcHandler
mIntHandler 3,K_TmpExcHandler
mIntHandler 4,K_TmpExcHandler
mIntHandler 5,K_TmpExcHandler
mIntHandler 6,K_TmpExcHandler
mIntHandler 7,K_TmpExcHandler
mIntHandler 8,K_TmpExcHandler
mIntHandler 9,K_TmpExcHandler
mIntHandler 10,K_TmpExcHandler
mIntHandler 11,K_TmpExcHandler
mIntHandler 12,K_TmpExcHandler
mIntHandler 13,K_TmpExcHandler
mIntHandler 14,K_TmpExcHandler
mIntHandler 15,K_TmpExcHandler
mIntHandler 16,K_TmpExcHandler
mIntHandler 17,K_TmpExcHandler

proc K_TmpExcHandler
		mov	ebx,0B8000h
		add	bl,[ExcPrintPos]
		mov	al,[ExceptionNum]
		mov	ah,15
		mov	[ebx],ax
		add	[ExcPrintPos],2
		jmp	$
endp		;---------------------------------------------------------------


; --- Low-level OS services ---

mIntHandler 30
mIntHandler 31
mIntHandler 32
mIntHandler 33
mIntHandler 34
mIntHandler 35
mIntHandler 36
mIntHandler 37
mIntHandler 38
mIntHandler 39
mIntHandler 3A
mIntHandler 3B
mIntHandler 3C
mIntHandler 3D
mIntHandler 3E
mIntHandler 3F


; --- High-level OS services ---

mIntHandler 50
mIntHandler 51
mIntHandler 52
mIntHandler 53
mIntHandler 54
mIntHandler 55
mIntHandler 56
mIntHandler 57
mIntHandler 58
mIntHandler 59
mIntHandler 5A
mIntHandler 5B
mIntHandler 5C
mIntHandler 5D
mIntHandler 5E
mIntHandler 5F


; --- Hardware interrupt handlers ---

		; IRQ0: system timer.
proc Int70Handler
		push	eax ebx edx
		mov	eax,[TimerTicksLo]
		inc	eax
		mov	[TimerTicksLo],eax
		or	eax,eax
		jz	@@SetTTHi
		jmp	short @@1
@@SetTTHi:	inc	[TimerTicksHi]

@@1:		pop	edx ebx
		mPICACK 0
		pop	eax
		;call	K_SwitchTask
		iret
endp		;---------------------------------------------------------------


		; IRQ1: keyboard.
proc Int71Handler
		sti
		push	eax edx
		mov	eax,EV_IRQ+1
		mCallDriver DRVID_Keyboard,DRVF_HandleEv
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int72Handler
		push	eax
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 3: serial ports #2 & #4
proc Int73Handler
		push	eax edx
		mov	eax,EV_IRQ+3
		mCallDriver DRVID_Serial,DRVF_HandleEv
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 4: serial ports #1 & #3
proc Int74Handler
		push	eax edx
		mov	eax,EV_IRQ+4
		mCallDriver DRVID_Serial,DRVF_HandleEv
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 5: audio device.
proc Int75Handler
		push	eax edx
		mov	eax,EV_IRQ+5
		mCallDriver DRVID_Audio,DRVF_HandleEv
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 6: FDD.
proc Int76Handler
		push	eax edx
		mov	eax,EV_IRQ+6
		mCallDriver DRVID_FDD,DRVF_HandleEv
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------


		; IRQ 7: parallel port #1.
proc Int77Handler
		push	eax edx
		mov	eax,EV_IRQ+7
		mCallDriver DRVID_Parallel,DRVF_HandleEv
		pop	edx
		mPICACK 0
		pop	eax
		iret
endp		;---------------------------------------------------------------



		; IRQ 8: CMOS real-time clock.
proc Int78Handler
		push	eax
		call	CMOS_HandleInt
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int79Handler
		push	eax
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int7AHandler
		push	eax
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int7BHandler
		push	eax
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int7CHandler
		push	eax
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int7DHandler
		push	eax edx
		mov	eax,EV_IRQ+13
		mCallDriver DRVID_FPU,DRVF_HandleEv
		pop	edx
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int7EHandler
		push	eax
		mov	eax,EV_IRQ+0			; Interface 0
		mCallDriver DRVID_HDIDE,DRVF_HandleEv
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------


proc Int7FHandler
		push	eax
		mov	eax,EV_IRQ+1			; Interface 1
		mCallDriver DRVID_HDIDE,DRVF_HandleEv
		mPICACK 1
		pop	eax
		iret
endp		;---------------------------------------------------------------
