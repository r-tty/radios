;*******************************************************************************
;  3c509.nasm - 3Com Etherlink III (3c509) driver.
;  Copyright (c) 2000 RET & COM Research.
;*******************************************************************************

module hw.net.3c509

%include "sys.ah"
%include "driver.ah"

global Drv3c509


section .data

Drv3c509	DB	"%3c509"
		TIMES	16-$+Drv3c509 DB 0
		DD	Drv3c509_ET
		DW	0

Drv3c509_ET	DD	0


section .text
