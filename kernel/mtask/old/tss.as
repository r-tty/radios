; tss.asm
;
; Function: Multitasking
;   Handles allocating all task memory except what is loaded
;   Handles Deallocating on error
;   Handles creating/ linking new tasks into the parent tree
;      Task switch is done on a round-robin basis
;   Handles deleting tasks
;   Handles task switch
;
	IDEAL
	P386

include "os.asi"
include "segs.asi"
include "tss.asi"
include "page.asi"
include "gdt.asi"
include "errors.asi"
include "sys.mac"
include "glbltss.asi"
include "descript.ase"
include "page.ase"
include "pageall.ase"
include "boot.ase"
include "dispatch.ase"
include "page.ase"
include "loader.ase"
include "pageall.asi"
include "remaps.ase"
include "prints.ase"
include "memory.asi"
include "sems.asi"
include "xstack.ase"
include "sems.ase"
include "glbltss.ase"

	PUBLIC	TaskHandler, TaskSwitch, TaskInit, canmultitask, NewTask
	PUBLIC	stackbase
STACKPATTERN = 0c444414ch

SEGMENT seg386data
stackbase dd	?		; base of system stack for interrupt switches
tasksel dw	?		; Selector of last made/deleted task
ldtsel	dw	?		; LDT selector of last task
pagedir	dd	?		; physical page dir address
pagesys	dd	?		; physical system page address	
pageuser dd	?		; physical user program page address
pageuser2 dd	?		; physical user memory alloc page addres
alloceduser2 dd	?		; set true if seperate physical umem alloced
tssuser	dd	?		; segment (to OS) address of task frame
stacksys dd	?		; physical system stack address
stackuser dd	?		; physical user stack address
canmultitask dd 1		; zero if can multitask
usertaskbranch dd	0	; null word, used for intertask jumps
firstrobin dw	0		; selector of any (typically last accessed) task
	align
tsssys	dd	0		; segment address of system TSS
systaskbranch dd	0	; null word, used for intertask jumps
selsys dw	0   		; Selector of system TSS
	align
thistaskbranch dd	0	; null word, used for intertask jumps
thistasksel dw	0		; Selector of an arbitrary task to execute
ENDS	seg386data
SEGMENT seg386
	assume	ds:dgroup,es:dgroup
;
;
; Deallocates all memory indexed by a user page table
;
PROC	DeletePage
	ZA	edi		; segment address
dp_loop:
	test	[dword ptr edi],PG_PRESENT	; If not present
	jz	short dp_done			; we are done
	mov	eax,[edi]			; get the physical address
	mov	[dword ptr edi],PG_DISABLE	; mark it unused
	call	PageDealloc			; Deallocate the page
	add	edi,4				; next table entry
	jmp	dp_loop
dp_done:
	ret
ENDP	DeletePage
;
; Delete any and all memory allocated for this task
;
PROC	DeleteMem
	mov	ax,[tasksel]		; Does it have a selector?
	or	ax,ax			;
	jz	short $$l1		;
	call	DescriptorAddress	; Yes, get its GDT address
	call	ReleaseGDTDescriptor	; Release it
$$l1:
	mov	ax,[ldtsel]		; Does it have an LDT?
	or	ax,ax			;
	jz	short	$$l2		;
	call	DescriptorAddress	; Get the GDT address
	call	ReleaseGDTDescriptor	; Release it
$$l2:
	mov	eax,[pagedir]		; Does it have a Page dir?
	or	eax,eax			;
	jz	short $$l3		;
	call	PageDealloc		; Yes, deallocate it
$$l3:
	mov	eax,[pageuser]		; Does it have a user page table
	or	eax,eax			;
	jz	short $$l4		;
	mov	edi,eax			; Yes
	call	PageDealloc		; Deallocate it
	add	edi,4*USER_PROGRAM_OFFSET
	call	DeletePage		; Deallocate any entries in it
$$l4:
	mov	eax,[alloceduser2]	; Does it have a private memory page
	or	eax,eax			;   table
	jz	short $$l5		;
	mov	eax,[pageuser2]		; Yes, get it
	mov	edi,eax			;
	call	PageDealloc             ; Deallocate it
	call	DeletePage		; Deallocate any entries in it
$$l5:
	mov	eax,[stacksys]		; Does it have a system stack?
	or	eax,eax			;
	jz	short $$l6		;
	call	PageDealloc		; Yes, deallocate it
$$l6:
	mov	eax,[stackuser]		; Does it have a user stack?
	or	eax,eax			;
	jz	short $$l7		;
	call	PageDealloc		; Yes, deallocate it
$$l7:
	mov	eax,[tssuser]		; Does it have a TSS
	or	eax,eax   		;
	jz	short $$l8		;
	add	eax,[zero]		; Make it physical
	call	RemoveTSSPage		; so we can deallocate it
$$l8:
	ret
ENDP	DeleteMem
;
; Unlink a task by pulling it off the round robin
; and unlinking it from parents, siblings
;
PROC	UnlinkTask
	mov	bx,ax			; bx = task sel
	mov	cx,[edi + TSS.SIBLINGS] ; cx = sibling sel
	mov	dx,[edi + TSS.ROBIN]	; dx = next entry on robin
	cmp	dx,ax			; See if this routes to itself
	jnz	short hasrobin		;
	mov	[word ptr firstrobin],0	; If so we are killing the robin
	inc	[canmultitask]		; and we can't multitask any more
	jmp	unlinked		; Get out!
hasrobin:
	cmp	bx,[firstrobin]		; Make sure firstrobin
	jnz	short okfirst		; points to a valid task
	mov	[firstrobin],dx		;
okfirst:
	mov	esi,edi			; ESI gets task pointer
	mov	ax,[esi + TSS.ROBIN]	; Get TSS of next task in robin
	call	DescriptorAddress	; By getting descriptor pointer
	call	GetDescriptorBase	; and pulling base out of descriptor
	ZA	edi			; This segment, of course
	cli				; We have to keep robin changes
					; indivisible
	mov	ax,[esi + TSS.LASTROBIN]; Transfer out backpointer
	mov	[edi + TSS.LASTROBIN],ax; over to the forward task
	mov	ax,[esi + TSS.LASTROBIN]; Get TSS of last task in robin
	call	DescriptorAddress	;
	call	GetDescriptorBase	;
	ZA	edi			; This segment of course
	mov	ax,[esi + TSS.ROBIN]	; Transfer our forward pointer
	mov	[edi + TSS.ROBIN],ax    ;   over to the backward task
	sti
	mov	ax,[esi + TSS.PARENT]	; Now get our mama's TSS
	or	ax,ax
	jz	short unlinked
	call	DescriptorAddress	;
	call	GetDescriptorBase	;
	ZA	edi			;
	cmp	bx,[edi + TSS.CHILDREN]	; See if I'm her oldest living child
	jz	short directchild	; Yes - unlink me
	mov	ax,[edi + TSS.CHILDREN] ; Otherwise We start with her first child
siblp:
	call	DescriptorAddress	; Get the TSS for this child
	call	GetDescriptorBase	;
	ZA	edi			;
	cmp	bx,[edi + TSS.SIBLINGS] ; See if I'm it's sibling
	jz	short siblingof		; Yes, go unlink me
	mov	ax,[edi + TSS.SIBLINGS]	; Else grab this sibling
	jmp	siblp			; And go again
siblingof:
	mov	ax,[esi + TSS.SIBLINGS]	; My older brother gets a pointer
	mov	[edi + TSS.SIBLINGS],ax	; to my younger brother, I'm going away
	jmp	short unlinked
directchild:
	mov	ax,[esi + TSS.SIBLINGS]	; My mama gets a pointer to my next
	mov	[edi + TSS.CHILDREN],ax	; youngest brother
unlinked:
					; Ok, guess the family talk is done
	ret
ENDP	UnlinkTask
;
; Removes a task from the link, along with any children of the task
;  and any siblings of those children.  Nice and recursive
;
PROC	RemoveTask
	push	edi			; Save regs for recursion
	push	eax			;
	call	DescriptorAddress	; Get the TSS for this task
	call	GetDescriptorBase       ;
	ZA	edi			;
	mov	ax,[edi + TSS.CHILDREN] ; See if any children
	or	ax,ax			;
	jz	nochildren		; No, nice & easy
	push	edi                     ; otherwise save this task
	push	eax			;
	call	DescriptorAddress	; Jump to first child
	call	GetDescriptorBase	;
	ZA	edi			;
	mov	ax,[edi + TSS.SIBLINGS] ; Grab its first sibling
sibloop:
	or	ax,ax			; See if any more siblings
	jz	short donesiblings	; No, done with siblings
	push	eax			; Save sibling descriptor
	call	DescriptorAddress	; Get the TSS of this sibling
	call	GetDescriptorBase	;
	ZA	edi                     ;
	mov	ax,[edi + TSS.SIBLINGS] ; Grab the next sibling
	xchg	[esp],eax		; Remove this sibling & its children
	call	RemoveTask		;
	pop	eax                     ; Pointer to next sibling
	jmp	sibloop			; Do more
donesiblings:
	pop	eax			; Grab first child
	call	RemoveTask		; Go remove it and its children
	pop	edi			; Restore task pointer
	; when we get here, we have a task with no children allocated
nochildren:
	sub	eax,eax			; Mark we have nothing to remove
	mov	[tasksel],ax		;
	mov	[ldtsel],ax		;
	mov	[pagedir],eax           ;
	mov	[pagesys],eax		;
	mov	[pageuser],eax		;
	mov	[pageuser2],eax		;
	mov	[alloceduser2],eax	;
	mov	[tssuser],eax		;
	mov	[stacksys],eax		;
	mov	[stackuser],eax		;
	pop	eax			;
	mov	[tssuser],edi		; Save user tss
	mov	[tasksel],ax		; Grab the task
	call	UnlinkTask		; Unlink the task
	mov	esi,[tssuser]		; Get user tss
	mov	ax,[esi + TSS.LDT]	; grab the ldt selector
	mov	[ldtsel],ax		;
	mov	eax,[esi  + TSS.CR3]	; Grab the page dir pointer
	mov	[pagedir],eax		;
	mov	edi,eax			;
	ZA	edi			; Make it segment relative
	call	UnAllocStack		; Deallocate any extended stack
	mov	eax,[edi]		; From the page dir we get
	and	eax,NOT (PG_SIZE - 1)	;   First, the system page table
	mov	[pagesys],eax		;
	test	[word ptr esi + TSS.PARENT],-1 ; If we have a parent
	jnz	nounlinkheap		; we don't have a private memory arena
	mov	eax,[edi + ARENATABLEENTRY*4];   otherwise we can get the page table
	and	eax,NOT (PG_SIZE - 1)	;
	mov	[pageuser2],eax         ;   and mark it for deletion
	mov	[alloceduser2],eax	;
nounlinkheap:
	mov	eax,[edi + 4]		; next grab user program page table
	and	eax,NOT (PG_SIZE -1)	;
	mov	[pageuser],eax		;
	mov	edi,eax			; From the user page table we get
	ZA	edi			;
	mov	eax,[edi + USERSTACKPAGEOFS * 4]	; The user stack
	mov	[stackuser],eax		;
	mov	eax,[edi + SYSTACKPAGEOFS * 4] ; The system stack
	mov	[stacksys],eax		;
	mov	[dword ptr edi + USERSTACKPAGEOFS * 4],PG_DISABLE ; Mark them disabled
	mov	[dword ptr edi + SYSTACKPAGEOFS * 4], PG_DISABLE
	test	[word ptr esi + TSS.PARENT],-1 ; Now if we have a parent
	jz	deleteexec                      ;
	mov	[dword ptr edi+4*USER_PROGRAM_OFFSET],PG_DISABLE	; mark the code page table entry
					; so the program will remain extant
					; ( marked by other page tables)
deleteexec:
	call	DeleteMem		; Go delete all marked resources

	pop	edi			; Pop reg
	ret
ENDP	RemoveTask
;
; Allocate a stack page
;
PROC	StackAlloc
	call	PageAlloc		; Get the page
	jc	nostack			; error get out
	push	eax			; Save it
	mov	edi,eax			; Fill it with a pattern
	ZA	edi			;
	cld				;
	mov	ecx,PG_SIZE/4		;
	mov	eax,STACKPATTERN	;
	rep	stosd                   ;
	pop	eax                     ;
nostack:
	ret
ENDP	StackAlloc
;
; Allocate a page table page
;
PROC	PageTableAlloc
	call	PageAlloc		; Get the page
	jc	epta			; Get out error
	mov	edi,eax			;
	push	eax                     ;
	ZA	edi                     ;
	push	edi                     ;
	call	PageTableDisable        ; Mark all entries not present
	pop	edi			;
	pop	eax			;
epta:
	ret
ENDP	PageTableAlloc
;
; Allocate a TSS page
;
PROC	TaskPageAlloc
	call	AddTSSPage		; Get the page
	jc	etpa			; error get out
	mov	edi,eax			; Otherwise fill it with 0
	ZA	edi			; to guarantee contents of
	push	eax			;   uninitialized fields
	push	edi			;
	mov	ecx,PG_SIZE / 4		;
	sub	eax,eax			;
	rep	stosd			;
	pop	edi                     ;
	pop	eax			;
etpa:
	ret
ENDP	TaskPageAlloc
;
; Link a task into the round robin
;
PROC	LinkTask
	mov	edi,[tssuser]		; Get task base
	mov	bx,[tasksel]		; And selector
	mov	[edi + TSS.SELECTOR],bx	; Put selector in task
	mov	[edi + TSS.LINK], bx	; Fill in link for IRETS
	or	ax,ax			; See if has a parent
	jz	notachild		; No, just link into robin
	mov	[edi + TSS.PARENT],ax	; Otherwise link in parent
	push	eax			; Get the parent tss
	call	DescriptorAddress	;
	call	GetDescriptorBase	;
	ZA	edi			;
	test	[edi + TSS.CHILDREN],-1	; See if parent is new to parenting
	jz	short nf_makechild	; Yes, just add me in as a child
	mov	ax,[edi + TSS.CHILDREN]	; Otherwise get children
nf_findsib:
	call	DescriptorAddress	; Find TSS of this child
	call	GetDescriptorBase	;
	ZA	edi			;
	test	[edi + TSS.SIBLINGS],-1	; See if it has any siblings
	jz	short nf_makesibling	; No, make me youngest
	mov	ax,[edi + TSS.SIBLINGS]	; Else get sibling
	jmp	nf_findsib		; Go find next sibling
nf_makesibling:
	mov	ax,[tasksel]		; Get this task
	mov	[edi + TSS.SIBLINGS] ,ax; Make it a sibling
	jmp	nf_childed		; Go link into robin
nf_makechild:
	mov	ax,[tasksel]		; Get this task
	mov	[edi + TSS.CHILDREN],ax	; Make it the parent's only child
nf_childed:
	pop	eax                     ; Get parent task
linkrobin:
	call	DescriptorAddress	;
	call	GetDescriptorBase       ;
	ZA	edi                     ;
	mov	esi,[tssuser]		;
	mov	[esi + TSS.ROBIN],ax	; Fill in our robin with parent
	mov	ax,[edi + TSS.LASTROBIN]; Get parent last robin
	mov	[esi + TSS.LASTROBIN],ax; Fill in our last robin
	push	eax			; Save parent last robin
	cli				; Keep robin changes indivisible
	mov	ax,[tasksel]		; Get our task
	mov	[edi + TSS.LASTROBIN],ax; Parent last robin is us
	pop	eax			;
	call	DescriptorAddress	; Find TSS of our last robin
	call	GetDescriptorBase	;
	ZA	edi			;
	mov	ax,[tasksel]		; Point it to us
	mov	[edi + TSS.ROBIN],ax	;
	mov	[firstrobin],ax		; Firstrobin is us
	ret

	; Not a child. If there are no other parents we simply run the task
notachild:
	mov	ax,[firstrobin]		; See if any other tasks
	test	ax,-1			;
	jnz	linkrobin		; Yes, just link us in and return
	;
	; Better not get here unless NewTask was called directly at priv
	; level 0, otherwise we are going to corrupt the system either by
	; wrecking the system task or by not performing the necessary
	; stack switch
	;
	mov	ax,[tasksel]		; Else get our task
	mov	[firstrobin],ax		; Make us the one and only
	mov	edi,[tssuser]		; Get the task
	mov	[edi + TSS.ROBIN],ax	; Point it at itself
	mov	[edi + TSS.LASTROBIN],ax;

	; Now start running task
	lldt	[edi + TSS.LDT]		; Get ldt
	ltr	[edi + TSS.SELECTOR]	; Get task

	mov	eax,[edi + TSS.CR3]	; Get paging
	mov	CR3,eax			;

	cli
	mov	eax,[edi + TSS.STACKBASE]; Initialize stack base of inner stack
	mov	[stackbase],eax		;
	
	push	[dword ptr edi + TSS.SS]; Push ss:esp
	push	[edi + TSS.ESP]		;
	push	[edi + TSS.EFLAGS]	; PUSH eflags
	or	[dword ptr ss:esp], IntEnable; Make sure interrupts are up
	push	[dword ptr edi + TSS.CS]; Push cs:eip
	push	[edi + TSS.EIP]		;
	mov	es,[edi + TSS.ES]	; Load seg registers
	mov	fs,[edi + TSS.FS]	;
	mov	gs,[edi + TSS.GS]	;
	dec	[canmultitask]		; Turn on multitasking
	mov	ds,[edi + TSS.DS]	; Final seg register
	iretd				; IRET to load stack, flags, code
					; Note this iret does a stack switch
					; because the CS from the TSS points
					; into the private LDT at a descriptor
					; which is marked priv level 3 adn we
					; are running at 0
ENDP	LinkTask
;
; Create a new task
;
NTP_LOAD EQU ebp+8
PROC	NewTask
	ENTER	0,0
	push	eax			; Save parent
	sub	eax,eax			; Now mark we haven't allocated
	mov	[tasksel],ax		; anything, in case a resource runs
	mov	[ldtsel],ax		; dry and we have to go deallocate
	mov	[pagedir],eax		;
	mov	[pagesys],eax		;
	mov	[pageuser],eax		;
	mov	[pageuser2],eax		;
	mov	[alloceduser2],eax	;
	mov	[tssuser],eax		;
	mov	[stacksys],eax		;
	mov	[stackuser],eax		;


	ALLOCEXT   			; Allocate user stack in extmem
	call	StackAlloc		;
	jc	NoMemory		; Go deallocate everything on error
	mov	[stackuser],eax		;

	ALLOCSYS			; But System (level 0) stack
	call	StackAlloc		; must be in the lower 640K
	jc	NoMemory		; so when we have an interrupt
	mov	[stacksys],eax		; and go to DOS we are fine

	mov	eax,[syspagetab]	; Get system page table
	add	eax,PG_SIZE		; In case want to access video
	add	eax,[zero]		; or any memory in A0000-FFFFF range
	mov	[pagesys],eax		;

	ALLOCEXT			; User mem in extended memory
	call	PageTableAlloc          ;
	jc	NoMemory                ;
	mov	[PageUser],eax          ;
	mov	eax,USERSTACKPAGEOFS	; User stack at offset 4ff000
	mov	ebx,[stackuser]		;
	or	ebx, PG_WRITEABLE OR PG_USERMODE;
	call	PageTableEnterAddress	;
	mov	eax,SYSTACKPAGEOFS	; System stack somewhere below that
	mov	ebx,[stacksys]		;
	or	ebx,PG_WRITEABLE OR PG_USERMODE;
	call	PageTableEnterAddress	;

	pop	eax			; See if has parent
	or	eax,eax			;
	push	eax			;
	jnz	short copyheap		; Copy its heap if so
	ALLOCEXT			; Otherwise allocate a new one in ext
	call	PageTableAlloc		; 
	jc	NoMemory		;
	mov	[pageuser2],eax         ;
	inc	[alloceduser2]          ; Mark that we have allocated it
	jmp	madeheap		; All done with that
copyheap:
	call	DescriptorAddress	; Otherwise get parent tss
	call	GetDescriptorBase
	ZA	edi
	mov	edi,[edi + TSS.CR3]	; Get parent page table
	ZA	edi			;
	mov	eax,[edi+ARENATABLEENTRY*4]; Load second page table entry
	and	eax,NOT (PG_SIZE -1)	;
	mov	[pageuser2],eax		; And that's what we use here
madeheap:
	ALLOCEXT			; Allocate page dir in ext memory
	call	PageTableAlloc		;
	jc	NoMemory		;
	mov	[Pagedir],eax		;
	sub	eax,eax			; First entry in page dir is system
	mov	ebx,[pagesys]		;
	or	ebx,PG_USERMODE OR PG_WRITEABLE
	call	PageTableEnterAddress	;
	mov	ebx,[pageuser]		; Second entry is user code/data
	or	ebx,PG_USERMODE OR PG_WRITEABLE
	inc	eax			
	Call	PageTableEnterAddress	;
	mov	ebx,[pageuser2]		; Third entry is shared memory
	or	ebx,PG_USERMODE or PG_WRITEABLE	;
	mov	eax,ARENATABLEENTRY	;
	call	PageTableEnterAddress	;
	push	edi			; Copy TSS page table from system page dir
	mov	edi,CR3			;  so it will be shared by all tasks
	ZA	edi
	mov	ebx,[edi + TSSPAGE*4]   ;  but paging is system only so
	pop	edi                     ;  can't corrupt it at the task level
	mov	[edi + TSSPAGE*4],ebx   ;

	ALLOCEXT			; Allocate TSS in ext memory
	call	TaskPageAlloc		; so interrupts can access
	jc	NoMemory		;
	mov	[tssuser],edi		;

	call	FindFreeDescriptor      ; Now find a TSS descriptor
	jc	NoDescript		;
	mov	[tasksel],ax		;
	mov	esi,edi			;
	mov	al,ST_TSS		; Grab it and mark it TSS priv 0
	call	GrabGDTDescriptor	;
	mov	eax,[tssuser]		; Get linear address of TSS
	add	eax,[zero]		;
	call	SetDescriptorBase	; Set the descriptor base to that
	mov	eax,PG_SIZE-1		; TSS is 4K long
	call	SetDescriptorLimit	;
	

	call	FindFreeDescriptor      ; Find a LDT descriptor
	jc	NoDescript		;
	mov	[ldtsel],ax		;
	mov	al,ST_LDT OR DT_DPL3    ; mark it LDT priv level 3
	call	GrabGDTDescriptor	;
	mov	eax,[tssuser]		; Find the TSS linear
	add	eax,[zero]              ;
	lea	eax,[eax + TSS.LOCALLDT]; Get LDT offset from TSS
	call	SetDescriptorBase	; This is the base
	mov	eax,8*LOCALLDTSIZE-1	; Limit of number LDTS * 8
	call	SetDescriptorLimit	;
	
	mov	edi,[tssuser]           ; First LDT descriptor
	lea	edi,[edi + TSS.LOCALLDT]
	mov	al,MT_ER OR DT_DPL3	; is CODE, priv level 3
	call	GrabDescriptor		;
	mov	eax,USERDATABASE	; HEre is base
	call	SetDescriptorBase	;
	mov	eax,USERDATALIM		; Here is limit
	call	SetDescriptorLimit	;

	add	edi,8			; Second LDT descriptor
	mov	al,MT_RW OR DT_DPL3	; is data, priv level 3
	call	GrabDescriptor		;
	mov	eax,USERDATABASE           ; The base
	call	SetDescriptorBase	;
	mov	eax,USERDATALIM		; The limit
	call	SetDescriptorLimit	;
	
	add	edi,8			; Third LDT descriptor
	mov	al,MT_RWD OR DT_DPL3	; is downward expandable user stack
	call	GrabDescriptor		; priv level 3 
	mov	eax,USERDATABASE	; The base
	call	SetDescriptorBase	;
	mov	eax,USERSTACKLIM	; The limit
	call	SetDescriptorLimit	;

	add	edi,8                   ; Fourth LDT descriptor
	mov	al,MT_RWD OR DT_DPL0	; is downward expandable system stack
	call	GrabDescriptor		; priv level 0
	mov	eax,USERDATABASE	; Base
	call	SetDescriptorBase	;
	mov	eax,SYSTEMSTACKLIM	; Limit
	call	SetDescriptorLimit	;
	
	sub	eax,eax			; Assume no parent
	test	[byte ptr NTP_LOAD],1	;
	jnz	short doload
	pop	eax                     ; Get parent
	push	eax			;
doload:
	mov	edi,[pageuser]		; Get page table to load into
	add	edi,4*USER_PROGRAM_OFFSET;
	ZA	edi			;
	call	loader			; Go load or copy the routine
	jc	invalidtask		;

	mov	edi,[tssuser]		; Get TSS
	lea	edi,[edi + TSS.LOCALLDT]; Base of CODE descriptor
	mov	ebx,eax			; Amount of space to allocate prior to code
	push	edi			;
	call	GetDescriptorBase	; Get the old base
	mov	eax,edi			; Calculate new base
	add	eax,ebx			;
	pop	edi			;
	call	SetDescriptorBase	; Set it
	call	GetDescriptorLimit	; And lower the limit
	sub	eax,ebx			;
	call	SetDescriptorLimit	;

	mov	ebx,ecx			; Amount of space to allocate prior to data
	add	edi,8			; Point to data segment descriptor
	push	edi			;
	call	GetDescriptorBase	; Get the old base
	mov	eax,edi			; Calculate new base
	add	eax,ebx			;
	pop	edi			;
	call	SetDescriptorBase	; Set it
	call	GetDescriptorLimit	; And lower the limit
	sub	eax,ebx			;
	call	SetDescriptorLimit	;

	mov	edi,[tssuser]           ; Get TSS
	pushfd				; Load up flags
	pop	eax			; Better not be anything volatile,
	sub	al,al			; because user task will inherit
	or	eax,IntEnable		; Plus interrupts will be enabled
	or	eax,IPL3		; And IOPL is 3 so tasks can do io
					; Which is of course a security violation
					; especially on a PC
	mov	[edi + TSS.EFLAGS],eax	;
	mov	[edi + TSS.STATE],SEM_NOWAIT; Not waiting on semaphores
	mov	eax,[stacksys]		; Initialize the interrupt stack base
	add	eax,PG_SIZE - SYSTEMSTACK;
	mov	[edi + TSS.STACKBASE],eax;
	mov	[edi + TSS.CS],LDT_CODE	; Load up seg regs
	mov	[edi + TSS.ES],LDT_DATA	;
	mov	[edi + TSS.DS],LDT_DATA	;
	mov	[edi + TSS.SS], LDT_USERSTACK ;
	mov	[edi + TSS.FS], DSABS OR 3 ;
	mov	[edi + TSS.GS], DSABS OR 3 ;
	mov	[edi + TSS.SS0], LDT_SYSTACK ; Initialize all three inner
	mov	[edi + TSS.SS1], LDT_SYSTACK ; stacks, although only levels
	mov	[edi + TSS.SS2], LDT_SYSTACK ; 0 and 3 are used
	mov	[edi + TSS.EIP],edx	; Initial IP
	mov	[edi + TSS.ESP0], SYSTEMSTACK	; Initial stack pointers
	mov	[edi + TSS.ESP1], 0	; UNUSED!!!
	mov	[edi + TSS.ESP2], 0	; UNUSED!!!
	mov	[edi + TSS.ESP], USERSTACK;
	mov	[edi + TSS.BMO],-1	; Disallow I/O at user level
	mov	eax,[pagedir]		; Set up page dir
	mov	[edi + TSS.CR3],eax	;
	mov	ax,[ldtsel]		; Set up LDT
	mov	[edi + TSS.LDT],ax	;
	mov	[edi + TSS.NOTIFY],0	; Noone to notify
	
	pop	eax			;
	push	edi
	call	LinkTask		; Link the task into the robin
	pop	edi
					; We'll never get here if this is
					; the first task
	clc
	mov	ax,[tasksel]		; Always return task selector
	LEAVE
	ret	04
invalidtask:
	jmp	short newerr  		; Just use loader error if task invalid
nomemory:
	mov	al,ERR_NOMEM		; No memory error
	jmp	short newerr
nodescript:
	mov	al,ERR_NODESC		; No descriptors error
newerr:
	cbw				; Error is a dword
	cwde				;
	xchg	[esp],eax		; Put on stack & get parent
	
	call	DeleteMem		; Delete everything allocated
	pop	eax			;
	stc				; Set carry
	LEAVE
	ret	04
ENDP	NewTask
;
; We have a system task to switch to system data space and pageing
; while making/breaking tasks.
; Initialize it
;
PROC	TaskInit
	mov	[canmultitask],1	; Can't multitask until task loaded
	ALLOCSYS			; Get a TSS for it
	call	TaskPageAlloc		;
	mov	bl,ERR_NOMEM 		; In case of error
	jc	ti_error		;
	mov	[tsssys],edi		; Save it
	call	FindFreeDescriptor	; Get a descriptor for the TSS
	mov	bl,ERR_NODESC		;
	jc	ti_err2			;
	mov	[selsys],ax		; Save it
	mov	al,ST_TSS		; Grab it and mark it TSS level 0
	call	GrabGDTDescriptor	;
	mov	eax,[tsssys]		; Get the linear address
	add	eax,[zero]		;
	call	SetDescriptorBase	; For the descriptor base
	mov	eax,PG_SIZE-1		; Set up the limit
	call	SetDescriptorLimit	;
	mov	edi,[tsssys]		; Get system task TSS
	pushfd				; Set IOPL to 3
	pop	eax			;
	or	eax,IPL3		;
	push	eax			;
	popfd				;
	and	eax,NOT IntEnable       ; Turn off interrupts
	mov	[edi + TSS.EFLAGS],eax	; And this is the initial flags
	mov	[edi + TSS.CS],CS386	; Load up segs
	mov	[edi + TSS.ES],DS386	;
	mov	[edi + TSS.DS],DS386	;
	mov	[edi + TSS.SS],DS386	;
	mov	[edi + TSS.FS],DSABS	;
	mov	[edi + TSS.GS],DSABS	;
	mov	[edi + TSS.SS0],DS386	;
	mov	[edi + TSS.SS1],DS386	;
	mov	[edi + TSS.SS2],DS386	;
	mov	[edi + TSS.ESP0], offset toss ; And top of stack
	mov	[edi + TSS.ESP1], offset toss ;
	mov	[edi + TSS.ESP2], offset toss ;
	mov	[edi + TSS.ESP], offset toss	;
	mov	ax,[selsys]
	mov	[edi + TSS.ROBIN],ax	; Make the system TSS
	mov	[edi + TSS.LASTROBIN],ax; its own robin
	mov	[edi + TSS.LINK],ax     ;
	mov	eax,PT_SYSTEMDIR	; It gets the system page tables
	mov	[edi + TSS.CR3],eax	;
	mov	ax,0			; And has no LDT
	mov	[edi + TSS.LDT],ax	;
	ret                             ;

ti_err2:
	mov	eax,[tsssys]            ; Deallocate TSS if no descriptor
	call	PageDealloc		;
ti_error:
	mov	al,bl			; Get error as dword
	cbw				;
	cwde				;
	stc				;
	ret				;

ENDP	TaskInit
;
; move a string to the system data area
;
PROC	MoveToSystemStack		
	or	esi,esi
	jz	short nostring
	push	esi			; Save source
	dec	ecx			; Save room for ending null
	jcxz	nomove			; Quit if nothing t ocopy
domove:
	movsb                           ; Move a byte
	test	[byte ptr esi],0ffh	; See if was 0
	loopnz	domove			; Loop while not
nomove:
	mov	[byte ptr es:edi],0	; place ending 0
	pop	esi			; restore source
nostring:
	ret
ENDP	MoveToSystemStack
;
; Move filename and command line to system stack
;
PROC	ParmsToStack
	cmp	eax,TA_SPAWN
	jz	short pts_spawnmove
	cmp	eax,TA_SPAWNWAIT
	jz	short pts_spawnmove
	cmp	eax,TA_NEW
	jz	short pts_domove
	cmp	eax,TA_NEWWAIT
	jnz	short pts_nomove
pts_domove:
	push	es			; Set ES to system
	push	DS386			;
	pop	es			;
	push	ecx			; Save DS selector
	push	esi			; Save command line
	mov	esi,ebx                 ; Get file name
	mov	ecx,FILENAMELIM		; Move to system stack
	mov	edi,offset boss		; 
	call	MoveToSystemStack	;
	pop	esi			; Restore command line
	pop	ecx
	pop	es
pts_spawnmove:
	push	es
	push	DS386
	pop	es
	push	ecx
	mov	ecx, COMMANDLINELIM	;
	mov	edi,offset boss+FILENAMELIM; Move to system stack
	call	MoveToSystemStack	;
	pop	ecx			; Restore DS selector
	pop	es			; Restore user ES
pts_nomove:
	ret
ENDP	ParmsToStack
;
; Initialize for New Task
;
PROC	new_init
	push	gs			; Getseg for load file init
	push	ds			;
	pop	gs			;
	call	init_load_file		; Set up the load file
	pop	gs			; Restore seg
	ret
ENDP	new_init
;
; Task function - create new task
;

PROC	new
	call	new_init
	push	1			; Load task
	sub	eax,eax       		; It has no parent
	call	NewTask			; It is new
nonewtask:
	ret
ENDP	new
;
; Task function - create new task and wait for it
;
PROC	NewWait
	push	edx
	call	new_init
	pop	eax
	push	eax
	sub	eax,eax
	push	1
	call	NewTask
	pop	ebx
	jc	nonewtask
	mov	[edi + TSS.NOTIFY],bx	; Parent to notify goes in child db
	mov	eax,ebx
	call	DescriptorAddress	;
	call	GetDescriptorBase        ;
	ZA	edi			; Now wait the parent
	lea	ebx,[edi + TSS.WAITING]
	mov	[dword ptr ebx],0
	mov	[edi + TSS.RESOURCE] , ebx	; Bool to wait on
	mov	[edi + TSS.STATE],SEM_WAITRUE	; Wait condition
	ret
ENDP	NewWait
;
; Init command line for spawn
;
PROC	SpawnInit
	push	gs			; Getseg for load file init
	push	ds			;
	pop	gs			;
	call	init_load_file		; Set up the load file
	pop	gs			; Restore seg
	ret
ENDP	SpawnInit
;
; Task function - spawn task
;
PROC	spawn
	call	SpawnInit
	mov	eax,edx			; Get task parent
	push	ebx			; Save start address
	push	0
	call	NewTask			; Make the task
	pop	ebx			;
	mov	edi,[tssuser]		; Initialize TSS with start address
	mov	[edi + TSS.EIP],ebx	;
	ret
ENDP	spawn
;
; Task function - spawn a task and wait for completion
;
PROC	spawnwait
	push	edx
	call	Spawn
	pop	ebx
	mov	[edi + TSS.NOTIFY],bx	; Who to notify
	jc	nospawnwait
	mov	eax,ebx
	call	DescriptorAddress	;
	call	GetDescriptorBase        ;
	ZA	edi			;
	lea	ebx,[edi + TSS.WAITING]
	mov	[dword ptr ebx],0
	mov	[edi + TSS.RESOURCE] , ebx	; Bool to wait on
	mov	[edi + TSS.STATE],SEM_WAITRUE	; Wait condition
nospawnwait:
	ret
ENDP	spawnwait
;
; Task function - delete task
;
PROC	delete
	push	edx
	mov	eax,edx
	call	DescriptorAddress	;
	call	GetDescriptorBase        ;
	ZA	edi			;
	mov	ax,[edi + TSS.NOTIFY]
	or	ax,ax
	jz	short d_noparent
	call	DescriptorAddress	;
	call	GetDescriptorBase        ;
	ZA	edi			;
	bts	[edi + TSS.WAITING],0
d_noparent:
	pop	eax			; get task
	call	RemoveTask		; Remove it
	test	[firstrobin],-1		; If we have no robin
	jnz	done	
;
; Task function, exit os
;
doexit:		;
	inc	[canmultitask]
	jmp	_exit			; Exit the operating system
done:
	ret
ENDP	delete
;
; Task function - pause a task
;
PROC	pause
	mov	eax,edx			; Get the running task
	call	nextask			; Get the next task
	mov	[firstrobin],ax		;
	ret
ENDP	pause
;
; Task handler - run the system task
;
PROC	TaskHandler
	assume	ds:dgroup, es:nothing
	push	edi
	push	ds 			; MUST be on TOSS
	call	ParmsToStack		; Move filename and commandline into system data area
	push	DS386			; Get system data seg
	pop	ds			;
	mov	edi,[tsssys]		; Get system TSS
	mov	[edi + TSS.EAX],eax	; function code to system TSS
	mov	[edi + TSS.EBX],ebx	; parameter to system TSS
	cmp	eax,TA_NEW
	jz	short loadboss
	cmp	eax,TA_NEWWAIT
	jnz	short noloadboss
loadboss:
	mov	[edi + TSS.EBX],offset boss
noloadboss:
	mov	eax,[esp]		; Get DS selector off stack
	cwde
	mov	[edi + TSS.ECX],eax	; Save it in CX
	str	ax			; calling task to system TSS
	cwde				;
	mov	[edi + TSS.EDX],eax	;
	mov 	[edi + TSS.ESI],offset boss + FILENAMELIM	; command line
	mov	[edi + TSS.EIP],offset theSystemTask ; Program for TSS to run
	mov	[edi + TSS.ESP],offset toss ; And with an empty stack
	mov	eax,[zero]		;
	mov	[stackbase],eax         ; Offset stackbase from data seg
	jmp	[fword ptr systaskbranch]; Jump to system task
					; Task jump is like a call, when
					; the task that made the jump	
					; is resumed it will start here
	pop	ds			; Restore DS
	pop	edi
	ret
;
; Here we are at the system task
;
theSystemTask:
	inc	[canmultitask]		; Can't multitask while playing
	sti				; with tasks
	push	edx			; Save task TSS
	push	0
	call	TableDispatch		; Dispatch the function
	dd	6
	dd	new
	dd	newwait
	dd	spawn
	dd	spawnwait
	dd	pause
	dd	delete
	dd	doexit
	pop	edx			; Get task tss
	pushfd				; Save return flags
	push	eax			; and code
	mov	eax,edx			; Get TSS address
	call	DescriptorAddress	;
	call	GetDescriptorBase        ;
	ZA	edi			;
	pop	eax                     ; Get return value
	mov	[edi + TSS.EAX],eax	; Save in tss
	popfd				; Get return flags
	lahf				; 
	mov	[byte ptr edi + TSS.EFLAGS],ah ; Save in TSS
	mov	ax,[firstrobin]		; Get the new task TSS
	push	edi			;
	call	DescriptorAddress	;
	call	GetDescriptorBase	;
	ZA	edi			; 
	cli
	mov	eax,[edi + TSS.STACKBASE] ; Load up stackbase
	mov	[stackbase],eax		;
	pop	edi			;
	dec	[canmultitask]		; Can multitask now
	jmp	[fword ptr usertaskbranch]
ENDP	TaskHandler
;
; Find next available task
;
PROC	nextask
	inc	[canmultitask]		; Can't multitask now
	call	DescriptorAddress
	call	GetDescriptorBase
	ZA	edi
	mov	ax,[edi + TSS.ROBIN]	; Get selector of next task
ntloop:
	call	DescriptorAddress	;
	call	GetDescriptorBase	;
	ZA	edi			;
	cmp	[edi + TSS.STATE],SEM_NOWAIT ; See if waiting
	jz	okswitch		; No, switch
	push	eax
	mov	eax,[edi + TSS.RESOURCE]; Get resource we wait on
	bt	[dword ptr eax],0   	; See if ready
	pop	eax
	jc	short iswitch
	mov	ax,[edi + TSS.ROBIN]	
	jmp	short ntloop
iswitch:
	mov	[edi + TSS.STATE],SEM_NOWAIT; Not waiting any more
okswitch:
	dec	[canmultitask]		; Can multitask again
	ret
ENDP	nextask

;
; Time-slice taskswitch routine
;
PROC	TaskSwitch
	test	[canmultitask],-1	; See if allowed to multitask
	jnz	cantmultitask		; No, get out
	push	eax			; Else get TSS of this task
	push	edi			;
	push	ebx                     ;
	str	ax			; Get the running task
	mov	bx,ax
	sti				;
	call	nextask			; Get the next task
	cli
	cmp	ax,bx			; See if is same as last
	pop	ebx			;
	jz	switchtoself		; Yes, can't switch to self
	mov	[thistasksel],ax	;
	call	DescriptorAddress	; And its TSS
	call	GetDescriptorBase	;
	ZA	edi			;
	cli
	mov	eax,[edi + TSS.STACKBASE]; Load stackbase for this task
	mov	[stackbase],eax		;
	pop	edi			; Restore regs
	pop	eax			;
	jmp	[fword ptr thistaskbranch]; Jump to new task
					; Which of course will resume the old
					; task here later
	sti
cantmultitask:
	ret
switchtoself:
	pop	edi			; Pop regs
	pop	eax
	ret
ENDP	TaskSwitch
ENDS	SEG386
END