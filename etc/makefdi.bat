@Echo OFF
copy /B boot.dat /B +config.dat /B +main.rce radios.fdi
IF Exist radios.fdi fdvol 1440 A: radios.fdi
