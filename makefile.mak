#******************************************************************************#
#  makefile.mak - RadiOS makefile.					       #
#******************************************************************************#

.SILENT

main.exe: main.obj DRIVERS\harddevs.obj \
		   DRIVERS\softdrvs.obj \
		   FS\rfs.obj \
		   MONITOR\monitor.obj
# C:\TASM\TD\tlink /m /3 /c
  C:\TASM\BIN\link /MAP main.obj \
			DRIVERS\harddevs.obj \
			DRIVERS\softdrvs.obj \
			FS\rfs.obj\
#			FS\msdos.obj \
			MONITOR\monitor.obj ,,,,,

main.obj: main.asm INCLUDE\*.ah KERNEL\*.a?? KERNEL\PROCESS\*.a?? KERNEL\MEMMAN\*.a??
 C:\TASM\BIN\tasm /m2 /ml /q /iINCLUDE main.asm

DRIVERS\harddevs.obj: DRIVERS\HARD\*.* INCLUDE\*.ah
 cd DRIVERS\HARD
 C:\TASM\BIN\tasm /m2 /ml /q /i..\..\INCLUDE harddevs.asm ,..\harddevs.obj
 cd ..\..

DRIVERS\softdrvs.obj: DRIVERS\SOFT\*.* INCLUDE\*.ah
 cd DRIVERS\SOFT
 C:\TASM\BIN\tasm /m2 /ml /q /i..\..\INCLUDE softdrvs.asm ,..\softdrvs.obj
 cd ..\..

FS\rfs.obj: FS\RFS\*.a?? INCLUDE\*.ah
 cd FS\RFS
 C:\TASM\BIN\tasm /m2 /ml /q /i..\..\INCLUDE rfs.asm ,..\rfs.obj
 cd ..\..

MONITOR\monitor.obj: MONITOR\*.a??
 cd MONITOR
 C:\TASM\BIN\tasm /m2 /ml /q /i..\INCLUDE monitor.asm
 cd ..
