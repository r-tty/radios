#******************************************************************************#
#  makefile.mak - RadiOS makefile.					       #
#******************************************************************************#

.SILENT

main.exe: main.obj DRIVERS\HARD\harddevs.obj DRIVERS\SOFT\softdrvs.obj RFS\rfs.obj
 C:\TASM\TD\tlink /m /3 /c main.obj DRIVERS\HARD\harddevs.obj DRIVERS\SOFT\softdrvs.obj RFS\rfs.obj

main.obj: main.asm INCLUDE\*.ah KERNEL\*.* KERNEL\PROCESS\*.* KERNEL\MEMMAN\*.* KERNEL\UTILS\*.*
 C:\TASM\BIN\tasm /m2 /ml /q /iINCLUDE main.asm

DRIVERS\HARD\harddevs.obj: DRIVERS\HARD\*.asm DRIVERS\HARD\*.ah INCLUDE\*.ah
 cd DRIVERS\HARD
 C:\TASM\BIN\tasm /m2 /ml /q /i..\..\INCLUDE harddevs.asm
 cd ..\..

DRIVERS\SOFT\softdrvs.obj: DRIVERS\SOFT\*.asm DRIVERS\SOFT\*.ah INCLUDE\*.ah
 cd DRIVERS\SOFT
 C:\TASM\BIN\tasm /m2 /ml /q /i..\..\INCLUDE softdrvs.asm
 cd ..\..

RFS\rfs.obj: RFS\*.asm RFS\*.ah INCLUDE\*.ah
 cd RFS
 C:\TASM\BIN\tasm /m2 /ml /q /i..\INCLUDE rfs.asm
 cd ..
