@Echo OFF
IF "%1"=="" Goto END
rkhandle.com %1 -r
pklite.exe -e %1
exe2rc.com %1
del %1
:END