;-------------------------------------------------------------------------------
; posix/1_iodir.nasm - POSIX directory routines.
;-------------------------------------------------------------------------------

module libc.iodir

exportproc _opendir, _closedir, _readdir, _readdir_r, _rewinddir

section .text

		; DIR *opendir(const char *path);
proc _opendir
		arg	path
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int closedir(DIR *dirp);
proc _closedir
		arg	dirp
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; struct dirent *readdir(DIR *dirp);
proc _readdir
		arg	dirp
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; int readdir_r(DIR *dirp, struct dirent *entry,
		;		struct dirent **result);
proc _readdir_r
		arg	dirp, entry, result
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------


		; viod rewinddir(DIR *dirp);
proc _rewinddir
		arg	dirp
		prologue
		epilogue
		ret
endp		;---------------------------------------------------------------
