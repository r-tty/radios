#******************************************************************************#
#  makefile.mak - RadiOS makefile.					       #
#******************************************************************************#

.AUTODEPEND
.SILENT

# --- Paths --- #
RADIOSPATH = C:\USR\RADIOS
INCLUDEPATH = $(RADIOSPATH)\INCLUDE
OBJPATH = $(RADIOSPATH)\ETC\OBJECT
LIBPATH = $(OBJPATH)\LIB
RCPATH = $(RADIOSPATH)\RC

.PATH.obj=$(OBJPATH)
.PATH.lib=$(LIBPATH)

# --- Commands --- #
TASM = C:\USR\BIN\tasm.exe /m2 /ml /q /zn /i$(INCLUDEPATH)
LINK = C:\USR\BIN\link.exe /BATCH /MAP /NOIGNORECASE
TLIB = C:\USR\BIN\tlib.exe
BCC = C:\USR\BIN\bcc32.exe

# --- Dependencies --- #
main.exe: kernel.obj drvhard.lib drvsoft.lib fs.lib monitor.lib init.obj rkdt.obj
 $(LINK) @&&!
$(OBJPATH)\kernel.obj $(OBJPATH)\init.obj $(OBJPATH)\rkdt.obj ,main.exe ,,$(LIBPATH)\drvhard.lib $(LIBPATH)\drvsoft.lib $(LIBPATH)\fs.lib $(LIBPATH)\monitor.lib ,,,
!


init.obj: INIT\*.asm INCLUDE\*.ah
 cd INIT
 $(TASM) init.asm ,$(OBJPATH)\init.obj
 cd ..

kernel.obj: KERNEL\*.a?? KERNEL\MTASK\*.a?? \
            KERNEL\MEMMAN\*.a?? KERNEL\API\*.a?? INCLUDE\*.ah
 cd KERNEL
 $(TASM) kernel.asm ,$(OBJPATH)\kernel.obj
 cd ..


drvhard.lib: harddevs.obj ide.obj fd.obj
 cd $(OBJPATH)
 $(TLIB) LIB\drvhard.lib /C +-harddevs.obj +-ide.obj +-fd.obj
 IF Exist LIB\*.bak del LIB\*.bak >NUL
 cd ..\..

drvsoft.lib: softdrvs.obj
 cd $(OBJPATH)
 $(TLIB) LIB\drvsoft.lib /C +-softdrvs.obj
 IF Exist LIB\*.bak del LIB\*.bak >NUL
 cd ..\..

fs.lib: rfs.obj commonfs.obj
 cd $(OBJPATH)
 $(TLIB) LIB\fs.lib /C +-rfs.obj +-commonfs.obj
 IF Exist LIB\*.bak del LIB\*.bak >NUL
 cd ..\..

monitor.lib: monitor.obj operands.obj dispatch.obj
 cd $(OBJPATH)
 $(TLIB) LIB\monitor.lib /C +-monitor.obj +-operands.obj +-dispatch.obj
 IF Exist LIB\*.bak del LIB\*.bak >NUL
 cd ..\..


harddevs.obj: DRIVERS\HARD\*.* INCLUDE\*.ah
 cd DRIVERS\HARD
 $(TASM) harddevs.asm ,$(OBJPATH)\harddevs.obj
 cd ..\..

ide.obj: DRIVERS\HARD\ide.asm INCLUDE\*.ah
 cd DRIVERS\HARD
 $(TASM) ide.asm ,$(OBJPATH)\ide.obj
 cd ..\..

fd.obj: DRIVERS\HARD\fd.asm INCLUDE\*.ah
 cd DRIVERS\HARD
 $(TASM) fd.asm ,$(OBJPATH)\fd.obj
 cd ..\..

softdrvs.obj: DRIVERS\SOFT\*.a?? DRIVERS\SOFT\BINFMT\*.a?? INCLUDE\*.ah
 cd DRIVERS\SOFT
 $(TASM) softdrvs.asm ,$(OBJPATH)\softdrvs.obj
 cd ..\..


rfs.obj: FS\RFS\*.a?? INCLUDE\*.ah
 cd FS\RFS
 $(TASM) rfs.asm ,$(OBJPATH)\rfs.obj
 cd ..\..

commonfs.obj: FS\*.asm INCLUDE\commonfs.ah
 cd FS
 $(TASM) commonfs.asm ,$(OBJPATH)\commonfs.obj
 cd ..


monitor.obj: MONITOR\*.a?? INCLUDE\*.ah
 cd MONITOR
 $(TASM) monitor.asm ,$(OBJPATH)\monitor.obj
 cd ..

operands.obj: MONITOR\OP\*.a?? INCLUDE\*.ah
 cd MONITOR\OP
 $(TASM) operands.asm ,$(OBJPATH)\operands.obj
 cd ..\..

dispatch.obj: MONITOR\OP\*.a?? INCLUDE\*.ah
 cd MONITOR\OP
 $(TASM) dispatch.asm ,$(OBJPATH)\dispatch.obj
 cd ..\..


rkdt.obj: KERNEL\RKDT\rkdt.asm INCLUDE\*.ah
 cd KERNEL\RKDT
 $(TASM) rkdt.asm ,$(OBJPATH)\rkdt.obj
 cd ..\..
