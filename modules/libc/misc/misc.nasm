
module libc.misc

exportproc _mmap_device_memory, _munmap_device_memory
exportproc _mmap_device_io, _munmap_device_io

section .text

proc _mmap_device_memory
		ret
endp		;---------------------------------------------------------------

proc _munmap_device_memory
		ret
endp		;---------------------------------------------------------------

proc _mmap_device_io
		ret
endp		;---------------------------------------------------------------

proc _munmap_device_io
		ret
endp		;---------------------------------------------------------------
