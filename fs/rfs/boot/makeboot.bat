@Echo OFF
tasm /m2 /q /zn rfsboot.asm
IF Exist *.obj link /TINY /NOLOGO rfsboot.obj ,boot.dat ,,,,,
IF Exist *.obj del *.obj
IF Exist *.map del *.map
