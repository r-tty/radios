@Echo OFF
C:
cd \BCPP\PROG\Z\kernel
C:\TC\BIN\tc pmdata.asm
cls
choice Delete *.BAK files
IF Errorlevel 2 Goto END
del *.bak > NUL
:END