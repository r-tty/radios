#*******************************************************************************
#  makefile - RadiOS makefile.
#*******************************************************************************


main.exe: main.obj DRIVERS\HARD\harddevs.obj DRIVERS\SOFT\softdrvs.obj RFS\rfs.obj
 C:\TASM\TD\tlink /m /3 /c main.obj DRIVERS\HARD\harddevs.obj DRIVERS\SOFT\softdrvs.obj RFS\rfs.obj

main.obj: main.asm
 C:\TASM\BIN\tasm /m2 /ml /iINCLUDE main.asm

DRIVERS\HARD\harddevs.obj: DRIVERS\HARD\harddevs.asm
 cd DRIVERS\HARD
 C:\TASM\BIN\tasm /m2 /ml /i..\..\INCLUDE harddevs.asm
 cd ..\..

DRIVERS\SOFT\softdrvs.obj: DRIVERS\SOFT\softdrvs.asm
 cd DRIVERS\SOFT
 C:\TASM\BIN\tasm /m2 /ml /i..\..\INCLUDE softdrvs.asm
 cd ..\..

RFS\rfs.obj: RFS\rfs.asm
 cd RFS
 C:\TASM\BIN\tasm /m2 /ml rfs.asm
 cd ..
