	SECTION .text
	SECTION .data
	SECTION .bss
SECTION .text
[BITS 32]
;
; Line 131:	 {
;
_error:
	PUSH	EBP
	MOV	EBP,ESP
	PUSH	EBX
	MOV	EBX,DWORD [EBP+08H]
;
; Line 132:	  if(ErrCode)
;
	TEST	EBX,EBX
	JE	NEAR	L_52
;
; Line 134:	    if(ErrCode>=8) WrString("FATAL ");
;
	CMP	EBX,BYTE 08H
	JL	SHORT	L_54
	LEA	EAX,[L_44]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
L_54:
;
; Line 135:	    WrString("ERROR: ");
;
	LEA	EAX,[L_45]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 136:	    switch(ErrCode)
;
	CMP	EBX,DWORD 01H
	JE	SHORT	L_58
	CMP	EBX,DWORD 02H
	JE	NEAR	L_59
	CMP	EBX,DWORD 03H
	JE	NEAR	L_60
	CMP	EBX,DWORD 08H
	JE	NEAR	L_61
	JMP	L_56
L_58:
;
; Line 138:	      case 1: WrString("disk operation failure");
;
	LEA	EAX,[L_46]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 139:	      break;case 2: WrString("startup configuration data not found");
;
	JMP	L_57
L_59:
	LEA	EAX,[L_47]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 140:	      break;case 3: WrString("boot sector signature not found");
;
	JMP	L_57
L_60:
	LEA	EAX,[L_48]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 141:	      break;case 8: WrString("no loadable devices");
;
	JMP	L_57
L_61:
	LEA	EAX,[L_49]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
L_56:
L_57:
;
; Line 143:	   }
;
	JMP	L_53
L_52:
;
; Line 144:	  else WrString("Program terminated normally");
;
	LEA	EAX,[L_50]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
L_53:
;
; Line 145:	  WrString(". Press any key...\n");
;
	LEA	EAX,[L_51]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 146:	  WaitKey();
;
	CALL	_WaitKey
;
; Line 147:	  ErrorCode=ErrCode;
;
	MOV	DWORD [_ErrorCode],EBX
;
; Line 148:	 }
;
	POP	EBX
	POP	EBP
	RET
;
; Line 153:	 {
;
_Help:
	RET
;
; Line 159:	 {
;
_LightLine:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 04H
	PUSH	EBX
;
; Line 160:	  byte HLattr=127,k;
;
	MOV	BYTE [EBP+0FFFFFFFFH],07FH
;
; Line 162:	  if(*CurrVidMode==7) HLattr=112;
;
	MOV	EAX,DWORD [_CurrVidMode]
	MOVSX	EAX,BYTE [EAX+00H]
	CMP	EAX,BYTE 07H
	JNE	SHORT	L_62
	MOV	BYTE [EBP+0FFFFFFFFH],070H
L_62:
	MOV	BL,05H
	JMP	L_66
L_64:
	MOVZX	EAX,BYTE [EBP+0FFFFFFFFH]
	PUSH	EAX
	MOVZX	AX,BYTE [EBP+08H]
	ADD	AX,BYTE 05H
	IMUL	AX,0A0H
	MOVZX	EBX,BL
	ADD	EAX,EBX
	PUSH	EAX
	CALL	_WrVidMem
	ADD	ESP,BYTE 08H
;
; Line 163:	  for(k=5;k<78*2;k+=2) WrVidMem((Row+5)*160+k,HLattr);
;
L_65:
	ADD	BL,BYTE 02H
L_66:
	MOVZX	EBX,BL
	CMP	EBX,09CH
	JB	NEAR	L_64
L_67:
;
; Line 164:	 }
;
	POP	EBX
	MOV	ESP,EBP
	POP	EBP
	RET
;
; Line 169:	 {
;
_BlankLine:
	PUSH	EBP
	MOV	EBP,ESP
	PUSH	EBX
	MOV	BL,05H
	JMP	L_70
L_68:
	PUSH	BYTE 07H
	MOVZX	AX,BYTE [EBP+08H]
	ADD	AX,BYTE 05H
	IMUL	AX,0A0H
	MOVZX	EBX,BL
	ADD	EAX,EBX
	PUSH	EAX
	CALL	_WrVidMem
	ADD	ESP,BYTE 08H
;
; Line 172:	  for(k=5;k<79*2;k+=2) WrVidMem((Row+5)*160+k,7);
;
L_69:
	ADD	BL,BYTE 02H
L_70:
	MOVZX	EBX,BL
	CMP	EBX,09EH
	JB	NEAR	L_68
L_71:
;
; Line 173:	 }
;
	POP	EBX
	POP	EBP
	RET
;
; Line 178:	 {
;
_GetString:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 018H
	PUSH	EBX
	PUSH	ESI
	PUSH	EDI
	MOV	ESI,DWORD [EBP+0CH]
;
; Line 182:	  WrString(Prompt);
;
	PUSH	DWORD [EBP+08H]
	CALL	_WrString
	POP	ECX
;
; Line 183:	  if((k=m=StrLen(edstr))!=0) WrString(StrCopy(TmpBuf,edstr));
;
	PUSH	ESI
	CALL	_StrLen
	POP	ECX
	MOV	BYTE [EBP+0FFFFFFEAH],AL
	MOV	BL,AL
	MOVSX	EAX,AL
	TEST	EAX,EAX
	JE	SHORT	L_73
	PUSH	ESI
	LEA	EAX,[EBP+0FFFFFFECH]
	PUSH	EAX
	CALL	_StrCopy
	ADD	ESP,BYTE 08H
	PUSH	EAX
	CALL	_WrString
	POP	ECX
L_73:
	JMP	L_77
L_75:
;
; Line 186:	    switch(ch=BKey=WaitKey())
;
	CALL	_WaitKey
	MOV	EDI,EAX
	MOV	BYTE [EBP+0FFFFFFEBH],AL
	CMP	AL,BYTE 09H
	JE	NEAR	L_85
	JG	SHORT	L_87
	CMP	AL,BYTE 08H
	JE	NEAR	L_82
	JG	NEAR	L_79
	CMP	AL,BYTE 00H
	JE	SHORT	L_81
	JMP	L_79
L_87:
	CMP	AL,BYTE 01BH
	JE	NEAR	L_84
	JG	NEAR	L_79
	CMP	AL,BYTE 0DH
	JE	NEAR	L_83
	JMP	L_79
L_81:
;
; Line 188:	       case '\0': switch(BKey >> 8)
;
	MOV	EAX,EDI
	SHR	EAX,08H
	CMP	EAX,DWORD 03BH
	JNE	NEAR	L_88
L_90:
;
; Line 190:			    case 59: Help();
;
	CALL	_Help
;
; Line 191:					 WrString(Prompt);
;
	PUSH	DWORD [EBP+08H]
	CALL	_WrString
	POP	ECX
;
; Line 192:					 TmpBuf[k]='\0';
;
	MOVSX	EBX,BL
	MOV	BYTE [EBP+EBX+0FFFFFFECH],00H
;
; Line 193:					 WrString(TmpBuf);
;
	LEA	EAX,[EBP+0FFFFFFECH]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 194:					 break;
;
L_88:
L_89:
;
; Line 196:			  continue;
;
	JMP	L_76
L_82:
;
; Line 197:	       case '\b': if(k)
;
	TEST	BL,BL
	JE	SHORT	L_91
;
; Line 198:			   { k--;
;
	DEC	BL
;
; Line 199:			     WrString("\b \b");
;
	LEA	EAX,[L_72]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 200:			   }
;
L_91:
;
; Line 201:			  continue;
;
	JMP	L_76
L_83:
;
; Line 202:	       case '\r': TmpBuf[k]='\0';
;
	MOVSX	EBX,BL
	MOV	BYTE [EBP+EBX+0FFFFFFECH],00H
;
; Line 203:			  StrCopy(edstr,TmpBuf);
;
	LEA	EAX,[EBP+0FFFFFFECH]
	PUSH	EAX
	PUSH	ESI
	CALL	_StrCopy
	ADD	ESP,BYTE 08H
;
; Line 204:			  WrChar('\n');
;
	PUSH	BYTE 0AH
	CALL	_WrChar
	POP	ECX
;
; Line 205:			  return edstr;
;
	MOV	EAX,ESI
	JMP	L_93
L_84:
;
; Line 206:	       case 27:  StrCopy(TmpBuf,edstr);
;
	PUSH	ESI
	LEA	EAX,[EBP+0FFFFFFECH]
	PUSH	EAX
	CALL	_StrCopy
	ADD	ESP,BYTE 08H
	JMP	L_94
L_96:
	PUSH	BYTE 08H
	CALL	_WrChar
	POP	ECX
L_94:
;
; Line 207:			  while(k--) WrChar('\b');
;
	MOV	AL,BL
	DEC	BL
	TEST	AL,AL
	JNE	SHORT	L_96
L_95:
;
; Line 208:			  WrString(TmpBuf);
;
	LEA	EAX,[EBP+0FFFFFFECH]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
	MOV	BL,00H
	JMP	L_99
L_97:
	PUSH	BYTE 020H
	CALL	_WrChar
	POP	ECX
;
; Line 209:			  for(k=0;k<=16					;k++) WrChar(' ');
;
L_98:
	INC	BL
L_99:
	MOVSX	EBX,BL
	CMP	EBX,BYTE 010H
	JLE	SHORT	L_97
L_100:
	JMP	L_101
L_103:
	PUSH	BYTE 08H
	CALL	_WrChar
	POP	ECX
L_101:
;
; Line 210:			  while(k--) WrChar('\b');
;
	MOV	AL,BL
	DEC	BL
	TEST	AL,AL
	JNE	SHORT	L_103
L_102:
;
; Line 211:			  k=m;
;
	MOV	BL,BYTE [EBP+0FFFFFFEAH]
;
; Line 212:	       break;case 9:  
;
	JMP	L_80
L_85:
;
; Line 213:			  WrString(Prompt);
;
	PUSH	DWORD [EBP+08H]
	CALL	_WrString
	POP	ECX
;
; Line 214:			  TmpBuf[k]='\0';
;
	MOVSX	EBX,BL
	MOV	BYTE [EBP+EBX+0FFFFFFECH],00H
;
; Line 215:			  WrString(TmpBuf);
;
	LEA	EAX,[EBP+0FFFFFFECH]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 216:			  break;
;
	JMP	L_80
L_79:
;
; Line 217:	       default:   if(k!=16					) WrChar(TmpBuf[k++]=ch);
;
	MOVSX	EBX,BL
	CMP	EBX,BYTE 010H
	JE	NEAR	L_104
	MOV	AL,BL
	INC	BL
	MOVSX	EAX,AL
	MOV	CL,BYTE [EBP+0FFFFFFEBH]
	MOV	BYTE [EBP+EAX+0FFFFFFECH],CL
	MOVSX	ECX,CL
	PUSH	ECX
	CALL	_WrChar
	POP	ECX
L_104:
L_80:
;
; Line 219:	   }
;
;
; Line 184:	  for(;;)
;
L_76:
L_77:
	JMP	L_75
L_78:
;
; Line 220:	 }
;
L_93:
	POP	EDI
	POP	ESI
	POP	EBX
	MOV	ESP,EBP
	POP	EBP
	RET
[GLOBAL	_GetCylFromCX]
;
; Line 225:	 {
;
_GetCylFromCX:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 04H
	PUSH	EBX
	MOVZX	EBX,WORD [EBP+08H]
;
; Line 228:	  t=CX;
;
	MOV	BYTE [EBP+0FFFFFFFFH],BL
;
; Line 229:	  return (CX >> 8)+256*(t >> 6) ;
;
	MOVZX	EAX,BX
	SAR	EAX,08H
	MOVZX	ECX,BYTE [EBP+0FFFFFFFFH]
	SAR	ECX,06H
	SAL	ECX,08H
	ADD	EAX,ECX
L_106:
	POP	EBX
	MOV	ESP,EBP
	POP	EBP
	RET
[GLOBAL	_GetSecFromCX]
;
; Line 235:	 {
;
_GetSecFromCX:
	PUSH	EBP
	MOV	EBP,ESP
;
; Line 236:	  return CX & 0x3F;
;
	MOV	AX,WORD [EBP+08H]
	AND	AX,BYTE 03FH
L_107:
	POP	EBP
	RET
[GLOBAL	_LoadBootSec]
;
; Line 242:	 {
;
_LoadBootSec:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 0CH
	PUSH	EBX
	PUSH	ESI
	PUSH	EDI
;
; Line 247:	  Drv=DevInfo[DevNum].Minor;
;
	MOVZX	EAX,BYTE [EBP+08H]
	IMUL	EAX,BYTE 033H
	MOV	AL,BYTE [EAX+03H+_DevInfo+00H]
	MOV	BYTE [EBP+0FFFFFFFCH],AL
;
; Line 248:	  if(DevInfo[DevNum].DevID==2)
;
	MOVZX	EAX,BYTE [EBP+08H]
	IMUL	EAX,BYTE 033H
	MOVZX	EAX,BYTE [EAX+_DevInfo+00H]
	CMP	EAX,BYTE 02H
	JNE	NEAR	L_108
;
; Line 253:	    if((t=DevInfo[DevNum].Extended)!=0)
;
	MOVZX	EAX,BYTE [EBP+08H]
	IMUL	EAX,BYTE 033H
	MOVZX	EBX,WORD [EAX+06H+_DevInfo+00H]
	TEST	EBX,EBX
	JE	NEAR	L_110
;
; Line 255:	      MBRptr=&ExtMBRs[(t>>8)-1];
;
	MOVZX	EAX,BX
	SAR	EAX,08H
	DEC	EAX
	IMUL	EAX,0202H
	LEA	ECX,[_ExtMBRs]
	ADD	ECX,EAX
	MOV	DWORD [EBP+0FFFFFFF4H],ECX
;
; Line 256:	      Part=(t & 0x3F)-1;
;
	MOV	EAX,EBX
	AND	AX,BYTE 03FH
	DEC	AX
	MOV	ESI,EAX
;
; Line 257:	     }
;
	JMP	L_111
L_110:
;
; Line 260:	      MBRptr=&MainMBRs[Drv];
;
	LEA	EAX,[_MainMBRs]
	MOVZX	ECX,BYTE [EBP+0FFFFFFFCH]
	IMUL	ECX,0202H
	ADD	EAX,ECX
	MOV	DWORD [EBP+0FFFFFFF4H],EAX
;
; Line 261:	      Part=DevInfo[DevNum].SubMinor-1;
;
	MOVZX	EAX,BYTE [EBP+08H]
	IMUL	EAX,BYTE 033H
	MOVZX	AX,BYTE [EAX+04H+_DevInfo+00H]
	DEC	AX
	MOV	ESI,EAX
;
; Line 262:	     }
;
L_111:
;
; Line 263:	    H=MBRptr->PartEntries[Part].BeginHead;
;
	MOV	EAX,DWORD [EBP+0FFFFFFF4H]
	MOVZX	ECX,SI
	SHL	ECX,04H
	MOV	AL,BYTE [EAX+ECX+01C1H+00H]
	MOV	BYTE [EBP+0FFFFFFFEH],AL
;
; Line 264:	    C=GetCylFromCX(t=MBRptr->PartEntries[Part].BeginSecCyl);
;
	MOV	EAX,DWORD [EBP+0FFFFFFF4H]
	MOVZX	ECX,SI
	SHL	ECX,04H
	MOV	BX,WORD [EAX+ECX+01C2H+00H]
	MOVZX	EBX,WORD [EAX+ECX+01C2H+00H]
	PUSH	EBX
	CALL	_GetCylFromCX
	POP	ECX
	MOV	EDI,EAX
;
; Line 265:	    S=GetSecFromCX(t);
;
	MOVZX	EBX,BX
	PUSH	EBX
	CALL	_GetSecFromCX
	POP	ECX
	MOV	BYTE [EBP+0FFFFFFFFH],AL
;
; Line 267:	    Drv+=0x80;
;
	ADD	BYTE [EBP+0FFFFFFFCH],080H
;
; Line 268:	   }
;
	JMP	L_109
L_108:
;
; Line 271:	    C=H=0;
;
	MOV	BYTE [EBP+0FFFFFFFEH],00H
	MOV	DI,00H
;
; Line 272:	    S=1;
;
	MOV	BYTE [EBP+0FFFFFFFFH],01H
;
; Line 273:	    t=1;
;
	MOV	BX,01H
;
; Line 274:	   }
;
L_109:
;
; Line 276:	  if(DiskOperation(Drv,C,H,S,1,Buffer,2)) error(1);
;
	PUSH	BYTE 02H
	PUSH	DWORD [EBP+0CH]
	PUSH	BYTE 01H
	MOVZX	EAX,BYTE [EBP+0FFFFFFFFH]
	PUSH	EAX
	MOVZX	EAX,BYTE [EBP+0FFFFFFFEH]
	PUSH	EAX
	MOVZX	EDI,DI
	PUSH	EDI
	MOVZX	EAX,BYTE [EBP+0FFFFFFFCH]
	PUSH	EAX
	CALL	_DiskOperation
	ADD	ESP,BYTE 01CH
	TEST	EAX,EAX
	JE	SHORT	L_112
	PUSH	BYTE 01H
	CALL	_error
	POP	ECX
	JMP	L_113
L_112:
;
; Line 277:	  else ErrorCode=0;
;
	MOV	DWORD [_ErrorCode],00H
L_113:
;
; Line 279:	  return ErrorCode;
;
	MOV	EAX,DWORD [_ErrorCode]
L_114:
	POP	EDI
	POP	ESI
	POP	EBX
	MOV	ESP,EBP
	POP	EBP
	RET
;
; Line 289:	 {
;
_FillDevInfo:
	PUSH	EBP
	MOV	EBP,ESP
	PUSH	EBX
	PUSH	ESI
	PUSH	EDI
	MOVZX	EBX,BYTE [EBP+08H]
	MOVZX	EDI,WORD [EBP+020H]
;
; Line 292:	  DevInfo[Num].DevID=DevID;
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOV	CL,BYTE [EBP+0CH]
	MOV	BYTE [EAX+_DevInfo+00H],CL
;
; Line 293:	  DevInfo[Num].TypeID=TypeID;
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOV	CL,BYTE [EBP+010H]
	MOV	BYTE [EAX+01H+_DevInfo+00H],CL
;
; Line 294:	  DevInfo[Num].ProtID=ProtID;
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOV	CL,BYTE [EBP+014H]
	MOV	BYTE [EAX+02H+_DevInfo+00H],CL
;
; Line 295:	  DevInfo[Num].Minor=Minor;
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOV	CL,BYTE [EBP+018H]
	MOV	BYTE [EAX+03H+_DevInfo+00H],CL
;
; Line 296:	  DevInfo[Num].SubMinor=SubMinor;
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOV	CL,BYTE [EBP+01CH]
	MOV	BYTE [EAX+04H+_DevInfo+00H],CL
;
; Line 297:	  DevInfo[Num].Extended=Extended;
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOV	WORD [EAX+06H+_DevInfo+00H],DI
;
; Line 298:	  t=StrEnd(StrCopy(DevInfo[Num].Name,Name));
;
	PUSH	DWORD [EBP+024H]
	LEA	EAX,[_DevInfo]
	MOVZX	EBX,BL
	MOV	ECX,EBX
	IMUL	ECX,BYTE 033H
	ADD	EAX,ECX
	ADD	EAX,BYTE 08H
	PUSH	EAX
	CALL	_StrCopy
	ADD	ESP,BYTE 08H
	PUSH	EAX
	CALL	_StrEnd
	POP	ECX
	MOV	ESI,EAX
;
; Line 299:	  t[0]=Minor+'1';
;
	MOV	AL,BYTE [EBP+018H]
	ADD	AL,BYTE 031H
	MOV	BYTE [ESI+00H],AL
;
; Line 300:	  if(SubMinor)
;
	CMP	BYTE [EBP+01CH],BYTE 00H
	JE	NEAR	L_115
;
; Line 302:	    t[1]='.';
;
	MOV	BYTE [ESI+01H],02EH
;
; Line 303:	    if(Extended)
;
	TEST	DI,DI
	JE	NEAR	L_117
;
; Line 305:	      if((t[2]=(Extended >> 8)+'4')>'9') t[2]+='a'-':';
;
	MOVZX	EAX,DI
	SAR	EAX,08H
	ADD	EAX,BYTE 034H
	MOV	BYTE [ESI+02H],AL
	MOVSX	EAX,AL
	CMP	EAX,BYTE 039H
	JLE	SHORT	L_119
	ADD	BYTE [ESI+02H],BYTE 027H
L_119:
;
; Line 306:	     }
;
	JMP	L_118
L_117:
;
; Line 307:	    else t[2]=SubMinor+'0';
;
	MOV	AL,BYTE [EBP+01CH]
	ADD	AL,BYTE 030H
	MOV	BYTE [ESI+02H],AL
L_118:
;
; Line 308:	    t[3]=0;
;
	MOV	BYTE [ESI+03H],00H
;
; Line 309:	   }
;
	JMP	L_116
L_115:
;
; Line 310:	  else t[1]=0;
;
	MOV	BYTE [ESI+01H],00H
L_116:
;
; Line 311:	  StrCopy(DevInfo[Num].Parms,Parms);
;
	PUSH	DWORD [EBP+028H]
	LEA	EAX,[_DevInfo]
	MOVZX	EBX,BL
	MOV	ECX,EBX
	IMUL	ECX,BYTE 033H
	ADD	EAX,ECX
	ADD	EAX,BYTE 01CH
	PUSH	EAX
	CALL	_StrCopy
	ADD	ESP,BYTE 08H
;
; Line 312:	 }
;
	POP	EDI
	POP	ESI
	POP	EBX
	POP	EBP
	RET
[GLOBAL	_FindFSname]
;
; Line 317:	 {
;
_FindFSname:
	PUSH	EBP
	MOV	EBP,ESP
	PUSH	EBX
	MOV	BL,00H
	JMP	L_124
L_122:
;
; Line 321:	   if(FStypesList[k].SysID==ID) return FStypesList[k].Type;
;
	MOVZX	EBX,BL
	MOV	AL,BYTE [EBX*8+_FStypesList+00H]
	CMP	AL,BYTE [EBP+08H]
	JNE	SHORT	L_126
	MOVZX	EBX,BL
	MOV	EAX,DWORD [EBX*8+04H+_FStypesList+00H]
	JMP	L_128
L_126:
;
; Line 320:	  for(k=0;k<31;k++)
;
L_123:
	INC	BL
L_124:
	MOVZX	EBX,BL
	CMP	EBX,BYTE 01FH
	JB	NEAR	L_122
L_125:
;
; Line 322:	  return Unknown;
;
	LEA	EAX,[L_121]
L_128:
	POP	EBX
	POP	EBP
	RET
;
; Line 337:	 {
;
_SearchHDpartitions:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 0CH
	PUSH	EBX
	PUSH	ESI
	PUSH	EDI
;
; Line 339:	  const PChar NameHD="%hd";
;
	LEA	EAX,[L_129]
	MOV	DWORD [EBP+0FFFFFFFCH],EAX
;
; Line 341:	  if(GetDiskDriveParms(Drive+0x80,&HDDparms[Drive])) return 0;
;
	LEA	EAX,[_HDDparms]
	MOVZX	ECX,BYTE [EBP+08H]
	IMUL	ECX,BYTE 0CH
	ADD	EAX,ECX
	PUSH	EAX
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,080H
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_GetDiskDriveParms
	ADD	ESP,BYTE 08H
	TEST	EAX,EAX
	JE	SHORT	L_130
	MOV	AL,00H
	JMP	L_132
L_130:
;
; Line 343:	  DiskOperation(Drive+0x80,0,0,1,1,&MainMBRs[Drive],2);
;
	PUSH	BYTE 02H
	LEA	EAX,[_MainMBRs]
	MOVZX	ECX,BYTE [EBP+08H]
	IMUL	ECX,0202H
	ADD	EAX,ECX
	PUSH	EAX
	PUSH	BYTE 01H
	PUSH	BYTE 01H
	PUSH	BYTE 00H
	PUSH	BYTE 00H
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,080H
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_DiskOperation
	ADD	ESP,BYTE 01CH
;
; Line 344:	  if(MainMBRs[Drive].Signature==0xAA55)
;
	MOVZX	EAX,BYTE [EBP+08H]
	IMUL	EAX,0202H
	MOVZX	EAX,WORD [EAX+0200H+_MainMBRs+00H]
	CMP	EAX,0AA55H
	JNE	NEAR	L_133
	MOV	BL,00H
	JMP	L_137
L_135:
;
; Line 347:	     if((c=MainMBRs[Drive].PartEntries[k].SystemCode)!=0)
;
	MOVZX	EAX,BYTE [EBP+08H]
	IMUL	EAX,0202H
	MOVZX	ECX,BL
	SHL	ECX,04H
	MOV	AL,BYTE [EAX+ECX+01C4H+_MainMBRs+00H+00H]
	MOV	BYTE [EBP+0FFFFFFFBH],AL
	MOVZX	EAX,AL
	TEST	EAX,EAX
	JE	NEAR	L_139
;
; Line 349:	       FillDevInfo(*DevCount,2,c,0, Drive,k+1,0, NameHD,FindFSname(c));
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	PUSH	EAX
	CALL	_FindFSname
	POP	ECX
	PUSH	EAX
	PUSH	DWORD [EBP+0FFFFFFFCH]
	PUSH	BYTE 00H
	LEA	EAX,[EBX+01H]
	MOVZX	EAX,AL
	PUSH	EAX
	MOVZX	EAX,BYTE [EBP+08H]
	PUSH	EAX
	PUSH	BYTE 00H
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	PUSH	EAX
	PUSH	BYTE 02H
	MOV	EAX,DWORD [EBP+0CH]
	MOVZX	EAX,BYTE [EAX+00H]
	PUSH	EAX
	CALL	_FillDevInfo
	ADD	ESP,BYTE 024H
;
; Line 350:	       (*DevCount)++;
;
	MOV	EAX,DWORD [EBP+0CH]
	INC	BYTE [EAX+00H]
;
; Line 351:	      }
;
L_139:
;
; Line 352:	     if(c==5)
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	CMP	EAX,BYTE 05H
	JNE	NEAR	L_141
;
; Line 354:	       byte keepk=k, k1, EMBRcount=0, Sec;
;
	MOV	BYTE [EBP+0FFFFFFF7H],BL
	MOV	BYTE [EBP+0FFFFFFF9H],00H
;
; Line 356:	       tMBR *EMBR=&MainMBRs[Drive];
;
	LEA	EAX,[_MainMBRs]
	MOVZX	ECX,BYTE [EBP+08H]
	IMUL	ECX,0202H
	ADD	EAX,ECX
	MOV	EDI,EAX
;
; Line 358:	       do {
;
L_143:
;
; Line 359:		   Cyl=GetCylFromCX(EMBR->PartEntries[k].BeginSecCyl);
;
	MOVZX	EAX,BL
	SHL	EAX,04H
	MOVZX	EAX,WORD [EDI+EAX+01C2H+00H]
	PUSH	EAX
	CALL	_GetCylFromCX
	POP	ECX
	MOV	ESI,EAX
;
; Line 360:		   Sec=GetSecFromCX(EMBR->PartEntries[k].BeginSecCyl);
;
	MOVZX	EAX,BL
	SHL	EAX,04H
	MOVZX	EAX,WORD [EDI+EAX+01C2H+00H]
	PUSH	EAX
	CALL	_GetSecFromCX
	POP	ECX
	MOV	BYTE [EBP+0FFFFFFFAH],AL
;
; Line 362:		   DiskOperation(Drive+0x80,Cyl,EMBR->PartEntries[k].BeginHead,			 Sec,1,&ExtMBRs[EMBRcount],2);
;
	PUSH	BYTE 02H
	LEA	EAX,[_ExtMBRs]
	MOVZX	ECX,BYTE [EBP+0FFFFFFF9H]
	IMUL	ECX,0202H
	ADD	EAX,ECX
	PUSH	EAX
	PUSH	BYTE 01H
	MOVZX	EAX,BYTE [EBP+0FFFFFFFAH]
	PUSH	EAX
	MOVZX	EAX,BL
	SHL	EAX,04H
	MOVZX	EAX,BYTE [EDI+EAX+01C1H+00H]
	PUSH	EAX
	MOVZX	ESI,SI
	PUSH	ESI
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,080H
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_DiskOperation
	ADD	ESP,BYTE 01CH
;
; Line 363:		   k=5;
;
	MOV	BL,05H
;
; Line 364:		   if(ExtMBRs[EMBRcount].Signature==0xAA55)
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFF9H]
	IMUL	EAX,0202H
	MOVZX	EAX,WORD [EAX+0200H+_ExtMBRs+00H]
	CMP	EAX,0AA55H
	JNE	NEAR	L_145
	MOV	BYTE [EBP+0FFFFFFF8H],00H
	JMP	L_149
L_147:
;
; Line 368:		       if((c=ExtMBRs[EMBRcount].PartEntries[k1].SystemCode)==0) break;
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFF9H]
	IMUL	EAX,0202H
	MOVZX	ECX,BYTE [EBP+0FFFFFFF8H]
	SHL	ECX,04H
	MOV	AL,BYTE [EAX+ECX+01C4H+_ExtMBRs+00H+00H]
	MOV	BYTE [EBP+0FFFFFFFBH],AL
	MOVZX	EAX,AL
	TEST	EAX,EAX
	JE	NEAR	L_150
L_151:
;
; Line 369:		       if(c==5) k=k1;
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	CMP	EAX,BYTE 05H
	JNE	SHORT	L_153
	MOV	BL,BYTE [EBP+0FFFFFFF8H]
	JMP	L_154
L_153:
;
; Line 374:			 FillDevInfo(*DevCount,2,c,0,Drive,			     keepk+1,256*(EMBRcount+1)+k1+1,			     NameHD,FindFSname(c));
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	PUSH	EAX
	CALL	_FindFSname
	POP	ECX
	PUSH	EAX
	PUSH	DWORD [EBP+0FFFFFFFCH]
	MOVZX	AX,BYTE [EBP+0FFFFFFF9H]
	INC	AX
	MOVZX	EAX,AX
	SAL	EAX,08H
	MOVZX	ECX,BYTE [EBP+0FFFFFFF8H]
	ADD	EAX,ECX
	INC	EAX
	PUSH	EAX
	MOV	AL,BYTE [EBP+0FFFFFFF7H]
	INC	AL
	MOVZX	EAX,AL
	PUSH	EAX
	MOVZX	EAX,BYTE [EBP+08H]
	PUSH	EAX
	PUSH	BYTE 00H
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	PUSH	EAX
	PUSH	BYTE 02H
	MOV	EAX,DWORD [EBP+0CH]
	MOVZX	EAX,BYTE [EAX+00H]
	PUSH	EAX
	CALL	_FillDevInfo
	ADD	ESP,BYTE 024H
;
; Line 375:			 (*DevCount)++;
;
	MOV	EAX,DWORD [EBP+0CH]
	INC	BYTE [EAX+00H]
;
; Line 376:			}
;
L_154:
;
; Line 377:		      }
;
;
; Line 366:		     for(k1=0;k1<4;k1++)
;
L_148:
	INC	BYTE [EBP+0FFFFFFF8H]
L_149:
	MOVZX	EAX,BYTE [EBP+0FFFFFFF8H]
	CMP	EAX,BYTE 04H
	JB	NEAR	L_147
L_150:
;
; Line 378:		     if(k<4) EMBR=&ExtMBRs[EMBRcount++];
;
	MOVZX	EBX,BL
	CMP	EBX,BYTE 04H
	JNC	SHORT	L_155
	MOV	AL,BYTE [EBP+0FFFFFFF9H]
	INC	BYTE [EBP+0FFFFFFF9H]
	MOVZX	EAX,AL
	IMUL	EAX,0202H
	LEA	EDI,[_ExtMBRs]
	ADD	EDI,EAX
L_155:
;
; Line 379:		    }
;
	JMP	L_146
L_145:
;
; Line 380:		   else break;
;
	JMP	L_144
L_146:
;
; Line 381:		  } while(k<4);
;
	MOVZX	EBX,BL
	CMP	EBX,BYTE 04H
	JB	NEAR	L_143
L_144:
;
; Line 382:	       k=keepk;
;
	MOV	BL,BYTE [EBP+0FFFFFFF7H]
;
; Line 383:	      }
;
L_141:
;
; Line 384:	    }
;
;
; Line 345:	   for(k=0;k<4;k++)
;
L_136:
	INC	BL
L_137:
	MOVZX	EBX,BL
	CMP	EBX,BYTE 04H
	JB	NEAR	L_135
L_138:
L_133:
;
; Line 385:	  return 1;
;
	MOV	AL,01H
L_132:
	POP	EDI
	POP	ESI
	POP	EBX
	MOV	ESP,EBP
	POP	EBP
	RET
;
; Line 391:	 {
;
_SearchDevices:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 010H
	PUSH	EBX
	PUSH	ESI
;
; Line 393:	  byte DevCount=0,h;
;
	MOV	BYTE [EBP+0FFFFFFFFH],00H
;
; Line 394:	  const PChar NameFD="%fd";
;
	LEA	ESI,[L_157]
;
; Line 397:	  if(!GetDiskDriveParms(0,&FDDparms[0]))
;
	LEA	EAX,[_FDDparms]
	PUSH	EAX
	PUSH	BYTE 00H
	CALL	_GetDiskDriveParms
	ADD	ESP,BYTE 08H
	TEST	EAX,EAX
	JNE	NEAR	L_158
;
; Line 400:	    FillDevInfo(DevCount,1,FDDparms[0].DriveType,		0,0,0,0,NameFD,"");
;
	LEA	EAX,[L_1]
	PUSH	EAX
	PUSH	ESI
	PUSH	BYTE 00H
	PUSH	BYTE 00H
	PUSH	BYTE 00H
	PUSH	BYTE 00H
	MOVSX	EAX,WORD [06H+_FDDparms]
	PUSH	EAX
	PUSH	BYTE 01H
	MOVZX	EAX,BYTE [EBP+0FFFFFFFFH]
	PUSH	EAX
	CALL	_FillDevInfo
	ADD	ESP,BYTE 024H
;
; Line 401:	    DevCount++;
;
	INC	BYTE [EBP+0FFFFFFFFH]
;
; Line 402:	    if(FDDparms[0].NumDrives>1)
;
	MOVZX	EAX,BYTE [04H+_FDDparms]
	CMP	EAX,BYTE 01H
	JBE	NEAR	L_160
;
; Line 403:	     if(!GetDiskDriveParms(1,&FDDparms[1]))
;
	LEA	EAX,[_FDDparms]
	ADD	EAX,BYTE 0CH
	PUSH	EAX
	PUSH	BYTE 01H
	CALL	_GetDiskDriveParms
	ADD	ESP,BYTE 08H
	TEST	EAX,EAX
	JNE	NEAR	L_162
;
; Line 406:		FillDevInfo(DevCount,1,FDDparms[1].DriveType,		    0,1,0,0,NameFD,"");
;
	LEA	EAX,[L_1]
	PUSH	EAX
	PUSH	ESI
	PUSH	BYTE 00H
	PUSH	BYTE 00H
	PUSH	BYTE 01H
	PUSH	BYTE 00H
	MOVSX	EAX,WORD [012H+_FDDparms]
	PUSH	EAX
	PUSH	BYTE 01H
	MOVZX	EAX,BYTE [EBP+0FFFFFFFFH]
	PUSH	EAX
	CALL	_FillDevInfo
	ADD	ESP,BYTE 024H
;
; Line 407:		DevCount++;
;
	INC	BYTE [EBP+0FFFFFFFFH]
;
; Line 408:	       }
;
	JMP	L_163
L_162:
;
; Line 409:	     else FDDparms[1].DriveType=-1;
;
	MOV	WORD [012H+_FDDparms],0FFFFFFFFH
L_163:
L_160:
;
; Line 410:	   }
;
	JMP	L_159
L_158:
;
; Line 411:	  else FDDparms[0].NumDrives=0;
;
	MOV	BYTE [04H+_FDDparms],00H
L_159:
;
; Line 414:	  if(SearchHDpartitions(0,&DevCount))
;
	LEA	EAX,[EBP+0FFFFFFFFH]
	PUSH	EAX
	PUSH	BYTE 00H
	CALL	_SearchHDpartitions
	ADD	ESP,BYTE 08H
	TEST	AL,AL
	JE	NEAR	L_164
	MOV	BL,01H
	JMP	L_168
L_166:
;
; Line 417:	     if(!SearchHDpartitions(h,&DevCount))
;
	LEA	EAX,[EBP+0FFFFFFFFH]
	PUSH	EAX
	MOVZX	EBX,BL
	PUSH	EBX
	CALL	_SearchHDpartitions
	ADD	ESP,BYTE 08H
	TEST	AL,AL
	JNE	SHORT	L_170
;
; Line 419:	       HDDparms[h].DriveType=-1;
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 0CH
	MOV	WORD [EAX+06H+_HDDparms+00H],0FFFFFFFFH
;
; Line 420:	       break;
;
	JMP	L_169
L_170:
;
; Line 416:	    for(h=1;h<HDDparms[0].NumDrives;h++)
;
L_167:
	INC	BL
L_168:
	CMP	BL,BYTE [04H+_HDDparms]
	JB	NEAR	L_166
L_169:
;
; Line 422:	   }
;
	JMP	L_165
L_164:
;
; Line 423:	  else HDDparms[0].NumDrives=0;
;
	MOV	BYTE [04H+_HDDparms],00H
L_165:
;
; Line 425:	  return DevCount;
;
	MOVZX	AX,BYTE [EBP+0FFFFFFFFH]
L_172:
	POP	ESI
	POP	EBX
	MOV	ESP,EBP
	POP	EBP
	RET
;
; Line 431:	 {
;
_LoadFromDisk:
	PUSH	EBP
	MOV	EBP,ESP
;
; Line 438:	  LoadBootSec(DevNum,(char *)0x7C00);
;
	PUSH	DWORD 07C00H
	MOVZX	EAX,BYTE [EBP+08H]
	PUSH	EAX
	CALL	_LoadBootSec
	ADD	ESP,BYTE 08H
;
; Line 439:	 }
;
	POP	EBP
	RET
;
; Line 444:	 {
;
_LoadFromRmvDisk:
	PUSH	EBP
	MOV	EBP,ESP
	POP	EBP
	RET
;
; Line 450:	 {
;
_LoadFromTape:
	PUSH	EBP
	MOV	EBP,ESP
	POP	EBP
	RET
;
; Line 456:	 {
;
_LoadFromPort:
	PUSH	EBP
	MOV	EBP,ESP
	POP	EBP
	RET
;
; Line 462:	 {
;
_LoadFromNet:
	PUSH	EBP
	MOV	EBP,ESP
	POP	EBP
	RET
	TIMES $$-$ & 3 NOP
;
; Line 467:	 {
;
_LoadFromDevice:
	PUSH	EBP
	MOV	EBP,ESP
	PUSH	EBX
	MOVZX	EBX,BYTE [EBP+08H]
;
; Line 468:	  switch(DevInfo[DevNum].DevID)
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOVZX	EAX,BYTE [EAX+_DevInfo+00H]
	CMP	EAX,DWORD 07H
	JNC	NEAR	L_173
	JMP	DWORD [EAX*4+L_175]
L_175:
	DD	L_176
	DD	L_177
	DD	L_178
	DD	L_179
	DD	L_180
	DD	L_181
	DD	L_182
L_176:
;
; Line 470:	    case 0:         break;
;
	JMP	L_174
L_177:
L_178:
;
; Line 473:	    case 2:	   LoadFromDisk(DevNum);
;
	MOVZX	EBX,BL
	PUSH	EBX
	CALL	_LoadFromDisk
	POP	ECX
;
; Line 475:	    break;case 3:	   LoadFromRmvDisk(DevNum);
;
	JMP	L_174
L_179:
	MOVZX	EBX,BL
	PUSH	EBX
	CALL	_LoadFromRmvDisk
	POP	ECX
;
; Line 476:	    break;case 4:	   LoadFromTape(DevNum);
;
	JMP	L_174
L_180:
	MOVZX	EBX,BL
	PUSH	EBX
	CALL	_LoadFromTape
	POP	ECX
;
; Line 477:	    break;case 5:	   LoadFromPort(DevNum);
;
	JMP	L_174
L_181:
	MOVZX	EBX,BL
	PUSH	EBX
	CALL	_LoadFromPort
	POP	ECX
;
; Line 478:	    break;case 6:	   LoadFromNet(DevNum);
;
	JMP	L_174
L_182:
	MOVZX	EBX,BL
	PUSH	EBX
	CALL	_LoadFromNet
	POP	ECX
L_173:
L_174:
;
; Line 480:	 }
;
	POP	EBX
	POP	EBP
	RET
;
; Line 485:	 {
;
_LoadOS_RFS:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,020CH
;
; Line 486:	  char RFSsig[]="RFS 01.00";
;
	MOV	EAX,DWORD [L_183]
	MOV	DWORD [EBP+0FFFFFDF4H],EAX
	MOV	EAX,DWORD [L_183+04H]
	MOV	DWORD [EBP+0FFFFFDF4H+04H],EAX
	MOV	AX,WORD [L_183+04H+04H]
	MOV	WORD [EBP+0FFFFFDF4H+04H+04H],AX
;
; Line 489:	  if(!LoadBootSec(DevNum,BootSec)) return;
;
	LEA	EAX,[EBP+0FFFFFE00H]
	PUSH	EAX
	MOVZX	EAX,BYTE [EBP+08H]
	PUSH	EAX
	CALL	_LoadBootSec
	ADD	ESP,BYTE 08H
L_184:
;
; Line 490:	 }
;
L_186:
	MOV	ESP,EBP
	POP	EBP
	RET
;
; Line 496:	 {
;
_LoadStartupConfig:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 08H
;
; Line 500:	  if(DevNum==255)
;
	MOVZX	EAX,BYTE [EBP+08H]
	CMP	EAX,0FFH
	JNE	NEAR	L_188
;
; Line 502:	    WrString("Default startup configuration loaded. Press any key...");
;
	LEA	EAX,[L_187]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 503:	    WaitKey();
;
	CALL	_WaitKey
;
; Line 504:	    WrChar('\r'); WrCharA(' ',7,80);			
;
	PUSH	BYTE 0DH
	CALL	_WrChar
	POP	ECX
	PUSH	BYTE 050H
	PUSH	BYTE 07H
	PUSH	BYTE 020H
	CALL	_WrCharA
	ADD	ESP,BYTE 0CH
;
; Line 505:	   }
;
L_188:
;
; Line 508:	 }
;
	MOV	ESP,EBP
	POP	EBP
	RET
;
; Line 511:	 {
;
_SaveStartupConfig:
	PUSH	EBP
	MOV	EBP,ESP
	POP	EBP
	RET
;
; Line 515:	 {
;
_EditStartupConfig:
;
; Line 516:	  WrChar(7);
;
	PUSH	BYTE 07H
	CALL	_WrChar
	POP	ECX
;
; Line 517:	 }
;
	RET
;
; Line 523:	 {
;
_Select:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 020H
	PUSH	EBX
	PUSH	ESI
	PUSH	EDI
;
; Line 524:	  const PChar ProgVer="       Radiant System Loader, version 1.0  (c) 1998 RET & COM Research";
;
	LEA	EAX,[L_190]
	MOV	DWORD [EBP+0FFFFFFE0H],EAX
;
; Line 525:	  const PChar ColNames[]={"Device","Type","Subtype/parameters","Protocol(s)"};
;
	PUSH	ESI
	PUSH	EDI
	LEA	ESI,[L_191]
	LEA	EDI,[EBP+0FFFFFFE4H]
	CLD
	MOV	ECX,04H
	REP	MOVSD
	POP	EDI
	POP	ESI
;
; Line 526:	  const PChar Sym="ÍÄÇ¶º³";
;
	LEA	ESI,[L_196]
;
; Line 527:	  byte ColWidth[4]={16,20,24,15};
;
	MOV	EAX,DWORD [L_197]
	MOV	DWORD [EBP+0FFFFFFF4H],EAX
;
; Line 528:	  byte i,j,k,Sel=0,Time=30;
;
	MOV	BYTE [EBP+0FFFFFFFCH],00H
	MOV	BYTE [EBP+0FFFFFFFDH],01EH
;
; Line 531:	  bool CountDown=1;
;
	MOV	BYTE [EBP+0FFFFFFFFH],01H
;
; Line 533:	  WrChar('É');
;
	PUSH	DWORD 0C9H
	CALL	_WrChar
	POP	ECX
;
; Line 534:	  WrCharA(Sym[0],LIGHTGRAY,78);
;
	PUSH	BYTE 04EH
	PUSH	BYTE 07H
	MOVSX	EAX,BYTE [ESI+00H]
	PUSH	EAX
	CALL	_WrCharA
	ADD	ESP,BYTE 0CH
;
; Line 535:	  MoveCur(79,0);
;
	PUSH	BYTE 00H
	PUSH	BYTE 04FH
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 536:	  WrChar('»'); WrChar(Sym[4]);
;
	PUSH	DWORD 0BBH
	CALL	_WrChar
	POP	ECX
	MOVSX	EAX,BYTE [ESI+04H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
;
; Line 537:	  WrString(ProgVer);
;
	PUSH	DWORD [EBP+0FFFFFFE0H]
	CALL	_WrString
	POP	ECX
;
; Line 538:	  MoveCur(79,1);
;
	PUSH	BYTE 01H
	PUSH	BYTE 04FH
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 539:	  WrChar(Sym[4]); WrChar(Sym[2]);
;
	MOVSX	EAX,BYTE [ESI+04H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	MOVSX	EAX,BYTE [ESI+02H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	MOV	BL,00H
	JMP	L_202
L_200:
;
; Line 542:	    WrCharA(Sym[1],LIGHTGRAY,ColWidth[i]);
;
	MOVZX	EBX,BL
	MOVZX	EAX,BYTE [EBP+EBX+0FFFFFFF4H]
	PUSH	EAX
	PUSH	BYTE 07H
	MOVSX	EAX,BYTE [ESI+01H]
	PUSH	EAX
	CALL	_WrCharA
	ADD	ESP,BYTE 0CH
;
; Line 543:	    MoveCur(WhereX+ColWidth[i],WhereY);
;
	MOVZX	EAX,BYTE [_WhereY]
	PUSH	EAX
	MOVZX	EBX,BL
	MOV	AL,BYTE [_WhereX]
	ADD	AL,BYTE [EBP+EBX+0FFFFFFF4H]
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 544:	    if(i!=3) WrChar('Â');
;
	MOVZX	EBX,BL
	CMP	EBX,BYTE 03H
	JE	SHORT	L_204
	PUSH	DWORD 0C2H
	CALL	_WrChar
	POP	ECX
L_204:
;
; Line 545:	   }
;
;
; Line 540:	  for(i=0;i<4;i++)
;
L_201:
	INC	BL
L_202:
	MOVZX	EBX,BL
	CMP	EBX,BYTE 04H
	JB	NEAR	L_200
L_203:
;
; Line 546:	  WrChar(Sym[3]); WrChar(Sym[4]);
;
	MOVSX	EAX,BYTE [ESI+03H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	MOVSX	EAX,BYTE [ESI+04H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	MOV	BL,00H
	JMP	L_208
L_206:
;
; Line 549:	    k=(ColWidth[i]-StrLen(ColNames[i]))/2;
;
	MOVZX	EBX,BL
	MOV	AL,BYTE [EBP+EBX+0FFFFFFF4H]
	PUSH	EAX
	MOVZX	EBX,BL
	PUSH	DWORD [EBP+EBX*4+0FFFFFFE4H]
	CALL	_StrLen
	POP	ECX
	MOV	ECX,EAX
	POP	EAX
	MOVZX	EAX,AL
	SUB	EAX,ECX
	SHR	EAX,01H
	MOV	BYTE [EBP+0FFFFFFFBH],AL
;
; Line 550:	    MoveCur(WhereX+k,3);
;
	PUSH	BYTE 03H
	MOV	AL,BYTE [_WhereX]
	ADD	AL,BYTE [EBP+0FFFFFFFBH]
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 551:	    WrString(ColNames[i]);
;
	MOVZX	EBX,BL
	PUSH	DWORD [EBP+EBX*4+0FFFFFFE4H]
	CALL	_WrString
	POP	ECX
;
; Line 552:	    MoveCur(WhereX+k,3);
;
	PUSH	BYTE 03H
	MOV	AL,BYTE [_WhereX]
	ADD	AL,BYTE [EBP+0FFFFFFFBH]
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 553:	    if(i!=3) WrChar(Sym[5]);
;
	MOVZX	EBX,BL
	CMP	EBX,BYTE 03H
	JE	SHORT	L_210
	MOVSX	EAX,BYTE [ESI+05H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
L_210:
;
; Line 554:	   }
;
;
; Line 547:	  for(i=0;i<4;i++)
;
L_207:
	INC	BL
L_208:
	MOVZX	EBX,BL
	CMP	EBX,BYTE 04H
	JB	NEAR	L_206
L_209:
;
; Line 555:	  WrChar(Sym[4]); WrChar(Sym[2]);
;
	MOVSX	EAX,BYTE [ESI+04H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	MOVSX	EAX,BYTE [ESI+02H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	MOV	BL,00H
	JMP	L_214
L_212:
;
; Line 558:	    WrCharA('Ä',LIGHTGRAY,ColWidth[i]);
;
	MOVZX	EBX,BL
	MOVZX	EAX,BYTE [EBP+EBX+0FFFFFFF4H]
	PUSH	EAX
	PUSH	BYTE 07H
	PUSH	DWORD 0C4H
	CALL	_WrCharA
	ADD	ESP,BYTE 0CH
;
; Line 559:	    MoveCur(WhereX+ColWidth[i],WhereY);
;
	MOVZX	EAX,BYTE [_WhereY]
	PUSH	EAX
	MOVZX	EBX,BL
	MOV	AL,BYTE [_WhereX]
	ADD	AL,BYTE [EBP+EBX+0FFFFFFF4H]
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 560:	    if(i!=3) WrChar('Å');
;
	MOVZX	EBX,BL
	CMP	EBX,BYTE 03H
	JE	SHORT	L_216
	PUSH	DWORD 0C5H
	CALL	_WrChar
	POP	ECX
L_216:
;
; Line 561:	   }
;
;
; Line 556:	  for(i=0;i<4;i++)
;
L_213:
	INC	BL
L_214:
	MOVZX	EBX,BL
	CMP	EBX,BYTE 04H
	JB	NEAR	L_212
L_215:
;
; Line 562:	  WrChar(Sym[3]);
;
	MOVSX	EAX,BYTE [ESI+03H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	MOV	BL,00H
	JMP	L_220
L_218:
;
; Line 565:	    WrChar(Sym[4]); WrChar(' '); WrString(DevInfo[i].Name);
;
	MOVSX	EAX,BYTE [ESI+04H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	PUSH	BYTE 020H
	CALL	_WrChar
	POP	ECX
	LEA	EAX,[_DevInfo]
	MOVZX	EBX,BL
	MOV	ECX,EBX
	IMUL	ECX,BYTE 033H
	ADD	EAX,ECX
	ADD	EAX,BYTE 08H
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 566:	    MoveCur(ColWidth[0]+1,i+5);
;
	LEA	EAX,[EBX+05H]
	MOVZX	EAX,AL
	PUSH	EAX
	MOV	AL,BYTE [EBP+0FFFFFFF4H]
	INC	AL
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 567:	    WrChar(Sym[5]); WrChar(' '); WrString(DevTypesList[DevInfo[i].DevID]);
;
	MOVSX	EAX,BYTE [ESI+05H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	PUSH	BYTE 020H
	CALL	_WrChar
	POP	ECX
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOVZX	EAX,BYTE [EAX+_DevInfo+00H]
	PUSH	DWORD [EAX*4+_DevTypesList+00H]
	CALL	_WrString
	POP	ECX
;
; Line 568:	    MoveCur(ColWidth[0]+ColWidth[1]+2,i+5);
;
	LEA	EAX,[EBX+05H]
	MOVZX	EAX,AL
	PUSH	EAX
	MOV	AL,BYTE [EBP+0FFFFFFF4H]
	ADD	AL,BYTE [EBP+0FFFFFFF5H]
	ADD	AL,BYTE 02H
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 569:	    WrChar(Sym[5]); WrChar(' '); WrString(DevInfo[i].Parms);
;
	MOVSX	EAX,BYTE [ESI+05H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	PUSH	BYTE 020H
	CALL	_WrChar
	POP	ECX
	LEA	EAX,[_DevInfo]
	MOVZX	EBX,BL
	MOV	ECX,EBX
	IMUL	ECX,BYTE 033H
	ADD	EAX,ECX
	ADD	EAX,BYTE 01CH
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 570:	    MoveCur(ColWidth[0]+ColWidth[1]+ColWidth[2]+3,i+5);
;
	LEA	EAX,[EBX+05H]
	MOVZX	EAX,AL
	PUSH	EAX
	MOV	AL,BYTE [EBP+0FFFFFFF4H]
	ADD	AL,BYTE [EBP+0FFFFFFF5H]
	ADD	AL,BYTE [EBP+0FFFFFFF6H]
	ADD	AL,BYTE 03H
	MOVZX	EAX,AL
	PUSH	EAX
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 571:	    WrChar(Sym[5]); WrChar(' '); WrString(ProtTypesList[DevInfo[i].ProtID]);
;
	MOVSX	EAX,BYTE [ESI+05H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	PUSH	BYTE 020H
	CALL	_WrChar
	POP	ECX
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOVZX	EAX,BYTE [EAX+02H+_DevInfo+00H]
	PUSH	DWORD [EAX*4+_ProtTypesList+00H]
	CALL	_WrString
	POP	ECX
;
; Line 572:	    MoveCur(79,i+5); WrChar(Sym[4]);
;
	LEA	EAX,[EBX+05H]
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 04FH
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
	MOVSX	EAX,BYTE [ESI+04H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
;
; Line 573:	   }
;
;
; Line 563:	  for(i=0;i<NumDevices;i++)
;
L_219:
	INC	BL
L_220:
	CMP	BL,BYTE [EBP+08H]
	JB	NEAR	L_218
L_221:
;
; Line 575:	  WrChar(Sym[2]);
;
	MOVSX	EAX,BYTE [ESI+02H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
	MOV	BYTE [EBP+0FFFFFFFBH],00H
	JMP	L_224
L_222:
;
; Line 578:	    WrCharA(Sym[1],LIGHTGRAY,ColWidth[k]);
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	MOVZX	EAX,BYTE [EBP+EAX+0FFFFFFF4H]
	PUSH	EAX
	PUSH	BYTE 07H
	MOVSX	EAX,BYTE [ESI+01H]
	PUSH	EAX
	CALL	_WrCharA
	ADD	ESP,BYTE 0CH
;
; Line 579:	    MoveCur(WhereX+ColWidth[k],WhereY);
;
	MOVZX	EAX,BYTE [_WhereY]
	PUSH	EAX
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	MOV	CL,BYTE [_WhereX]
	ADD	CL,BYTE [EBP+EAX+0FFFFFFF4H]
	MOVZX	ECX,CL
	PUSH	ECX
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 580:	    if(k!=3) WrChar('Á');
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	CMP	EAX,BYTE 03H
	JE	SHORT	L_226
	PUSH	DWORD 0C1H
	CALL	_WrChar
	POP	ECX
L_226:
;
; Line 581:	   }
;
;
; Line 576:	  for(k=0;k<4;k++)
;
L_223:
	INC	BYTE [EBP+0FFFFFFFBH]
L_224:
	MOVZX	EAX,BYTE [EBP+0FFFFFFFBH]
	CMP	EAX,BYTE 04H
	JB	NEAR	L_222
L_225:
;
; Line 582:	  WrChar(Sym[3]);
;
	MOVSX	EAX,BYTE [ESI+03H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
;
; Line 584:	  WrChar(Sym[4]);
;
	MOVSX	EAX,BYTE [ESI+04H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
;
; Line 585:	  MoveCur(79,i+6); WrChar(Sym[4]);
;
	LEA	EAX,[EBX+06H]
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 04FH
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
	MOVSX	EAX,BYTE [ESI+04H]
	PUSH	EAX
	CALL	_WrChar
	POP	ECX
;
; Line 586:	  WrChar('È'); WrCharA(Sym[0],LIGHTGRAY,78);
;
	PUSH	DWORD 0C8H
	CALL	_WrChar
	POP	ECX
	PUSH	BYTE 04EH
	PUSH	BYTE 07H
	MOVSX	EAX,BYTE [ESI+00H]
	PUSH	EAX
	CALL	_WrCharA
	ADD	ESP,BYTE 0CH
;
; Line 587:	  MoveCur(79,i+7); WrChar('¼');
;
	LEA	EAX,[EBX+07H]
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 04FH
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
	PUSH	DWORD 0BCH
	CALL	_WrChar
	POP	ECX
	MOV	BL,00H
	JMP	L_230
L_228:
;
; Line 590:	   if(DevInfo[i].DevID==2)
;
	MOVZX	EBX,BL
	MOV	EAX,EBX
	IMUL	EAX,BYTE 033H
	MOVZX	EAX,BYTE [EAX+_DevInfo+00H]
	CMP	EAX,BYTE 02H
	JNE	SHORT	L_232
;
; Line 592:	     Sel=i;
;
	MOV	BYTE [EBP+0FFFFFFFCH],BL
;
; Line 593:	     break;
;
	JMP	L_231
L_232:
;
; Line 589:	  for(i=0;i<NumDevices;i++)
;
L_229:
	INC	BL
L_230:
	CMP	BL,BYTE [EBP+08H]
	JB	NEAR	L_228
L_231:
;
; Line 596:	  MoveCur(9,NumDevices+6);
;
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 06H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 09H
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 597:	  WrString("Selected: ");
;
	LEA	EAX,[L_198]
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 598:	  WrString(DevInfo[i].Name);
;
	LEA	EAX,[_DevInfo]
	MOVZX	EBX,BL
	MOV	ECX,EBX
	IMUL	ECX,BYTE 033H
	ADD	EAX,ECX
	ADD	EAX,BYTE 08H
	PUSH	EAX
	CALL	_WrString
	POP	ECX
;
; Line 599:	  WrStringXY(49,NumDevices+6,"Time remaining: ");
;
	LEA	EAX,[L_199]
	PUSH	EAX
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 06H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 031H
	CALL	_WrStringXY
	ADD	ESP,BYTE 0CH
;
; Line 600:	  MoveCur(0,NumDevices+8);
;
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 08H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 00H
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 601:	  LightLine(Sel);
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFCH]
	PUSH	EAX
	CALL	_LightLine
	POP	ECX
	JMP	L_236
L_234:
;
; Line 604:	    if(KeyPressed())
;
	CALL	_KeyPressed
	TEST	AL,AL
	JE	NEAR	L_238
;
; Line 606:	      if(CountDown)
;
	CMP	BYTE [EBP+0FFFFFFFFH],BYTE 00H
	JE	NEAR	L_240
;
; Line 608:		CountDown=0;
;
	MOV	BYTE [EBP+0FFFFFFFFH],00H
;
; Line 609:		MoveCur(49,NumDevices+6);
;
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 06H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 031H
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 610:		WrCharA(' ',LIGHTGRAY,24);
;
	PUSH	BYTE 018H
	PUSH	BYTE 07H
	PUSH	BYTE 020H
	CALL	_WrCharA
	ADD	ESP,BYTE 0CH
;
; Line 611:		MoveCur(0,NumDevices+8);
;
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 08H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 00H
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 612:	       }
;
L_240:
;
; Line 613:	      switch(ch=BKey=WaitKey())
;
	CALL	_WaitKey
	MOV	EDI,EAX
	MOV	BYTE [EBP+0FFFFFFFEH],AL
	CMP	AL,BYTE 00H
	JE	SHORT	L_244
	CMP	AL,BYTE 0DH
	JE	NEAR	L_245
	JMP	L_242
L_244:
;
; Line 615:		case '\0': switch(BKey >> 8)
;
	MOVZX	EAX,DI
	SAR	EAX,08H
	CMP	EAX,DWORD 048H
	JE	NEAR	L_249
	JA	SHORT	L_253
	CMP	EAX,DWORD 041H
	JE	NEAR	L_251
	JA	NEAR	L_246
	CMP	EAX,DWORD 03BH
	JE	SHORT	L_248
	JMP	L_246
L_253:
	CMP	EAX,DWORD 05AH
	JE	NEAR	L_252
	JA	NEAR	L_246
	CMP	EAX,DWORD 050H
	JE	NEAR	L_250
	JMP	L_246
L_248:
;
; Line 617:			     case 59: Help();
;
	CALL	_Help
;
; Line 618:			     break;case 72: if(Sel>0)
;
	JMP	L_247
L_249:
	MOVZX	EAX,BYTE [EBP+0FFFFFFFCH]
	TEST	EAX,EAX
	JBE	NEAR	L_254
;
; Line 620:					    BlankLine(Sel);
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFCH]
	PUSH	EAX
	CALL	_BlankLine
	POP	ECX
;
; Line 621:					    LightLine(--Sel);
;
	DEC	BYTE [EBP+0FFFFFFFCH]
	MOVZX	EAX,BYTE [EBP+0FFFFFFFCH]
	PUSH	EAX
	CALL	_LightLine
	POP	ECX
;
; Line 622:					   }
;
L_254:
;
; Line 623:			     break;case 80: if(Sel<NumDevices-1)
;
	JMP	L_247
L_250:
	MOVZX	EAX,BYTE [EBP+08H]
	DEC	EAX
	MOVZX	ECX,BYTE [EBP+0FFFFFFFCH]
	CMP	ECX,EAX
	JNC	NEAR	L_256
;
; Line 625:					      BlankLine(Sel);
;
	MOVZX	EAX,BYTE [EBP+0FFFFFFFCH]
	PUSH	EAX
	CALL	_BlankLine
	POP	ECX
;
; Line 626:					      LightLine(++Sel);
;
	INC	BYTE [EBP+0FFFFFFFCH]
	MOVZX	EAX,BYTE [EBP+0FFFFFFFCH]
	PUSH	EAX
	CALL	_LightLine
	POP	ECX
;
; Line 627:					     }
;
L_256:
;
; Line 628:			     break;case 65: LoadStartupConfig(Sel);
;
	JMP	L_247
L_251:
	MOVZX	EAX,BYTE [EBP+0FFFFFFFCH]
	PUSH	EAX
	CALL	_LoadStartupConfig
	POP	ECX
;
; Line 629:					  if(!ErrorCode) EditStartupConfig();
;
	CMP	DWORD [_ErrorCode],BYTE 00H
	JNE	SHORT	L_258
	CALL	_EditStartupConfig
	JMP	L_259
L_258:
;
; Line 630:					  else ErrorCode=0;
;
	MOV	DWORD [_ErrorCode],00H
L_259:
;
; Line 631:			     break;case 90: LoadStartupConfig(255); 
;
	JMP	L_247
L_252:
	PUSH	DWORD 0FFH
	CALL	_LoadStartupConfig
	POP	ECX
L_246:
L_247:
;
; Line 634:			   MoveCur(19,NumDevices+6);
;
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 06H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 013H
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 635:			   WrString(DevInfo[Sel].Name); WrCharA(' ',LIGHTGRAY,5);
;
	LEA	EAX,[_DevInfo]
	MOVZX	ECX,BYTE [EBP+0FFFFFFFCH]
	IMUL	ECX,BYTE 033H
	ADD	EAX,ECX
	ADD	EAX,BYTE 08H
	PUSH	EAX
	CALL	_WrString
	POP	ECX
	PUSH	BYTE 05H
	PUSH	BYTE 07H
	PUSH	BYTE 020H
	CALL	_WrCharA
	ADD	ESP,BYTE 0CH
;
; Line 636:			   MoveCur(0,NumDevices+8);
;
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 08H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 00H
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 637:			   continue;
;
	JMP	L_235
L_245:
;
; Line 639:		case '\r': return Sel;
;
	MOV	AL,BYTE [EBP+0FFFFFFFCH]
	JMP	L_260
L_242:
L_243:
;
; Line 641:	     }
;
	JMP	L_239
L_238:
;
; Line 642:	    else if(CountDown)
;
	CMP	BYTE [EBP+0FFFFFFFFH],BYTE 00H
	JE	NEAR	L_261
;
; Line 644:		   MoveCur(65,NumDevices+6);
;
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 06H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 041H
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 645:		   wDecOut(--Time); WrChar(' ');
;
	DEC	BYTE [EBP+0FFFFFFFDH]
	MOVZX	EAX,BYTE [EBP+0FFFFFFFDH]
	PUSH	EAX
	CALL	_wDecOut
	POP	ECX
	PUSH	BYTE 020H
	CALL	_WrChar
	POP	ECX
;
; Line 646:		   MoveCur(0,NumDevices+8);
;
	MOV	AL,BYTE [EBP+08H]
	ADD	AL,BYTE 08H
	MOVZX	EAX,AL
	PUSH	EAX
	PUSH	BYTE 00H
	CALL	_MoveCur
	ADD	ESP,BYTE 08H
;
; Line 647:		   Delay1WithKB();
;
	CALL	_Delay1WithKB
;
; Line 648:		   if(!Time) return Sel;
;
	CMP	BYTE [EBP+0FFFFFFFDH],BYTE 00H
	JNE	SHORT	L_263
	MOV	AL,BYTE [EBP+0FFFFFFFCH]
	JMP	L_260
L_263:
;
; Line 649:		  }
;
L_261:
L_239:
;
; Line 650:	   }
;
;
; Line 602:	  for(;;)
;
L_235:
L_236:
	JMP	L_234
L_237:
;
; Line 651:	 }
;
L_260:
	POP	EDI
	POP	ESI
	POP	EBX
	MOV	ESP,EBP
	POP	EBP
	RET
[GLOBAL	_main]
;
; Line 656:	 {
;
_main:
	PUSH	EBP
	MOV	EBP,ESP
	SUB	ESP,BYTE 018H
	PUSH	EBX
;
; Line 657:	  char k,*Name,Buf[16					+1]="%fd1";
;
	PUSH	ESI
	PUSH	EDI
	LEA	ESI,[L_265]
	LEA	EDI,[EBP+0FFFFFFECH]
	CLD
	MOV	ECX,04H
	REP	MOVSD
	MOVSB
	POP	EDI
	POP	ESI
;
; Line 661:	  SetVidPg(7);
;
	PUSH	BYTE 07H
	CALL	_SetVidPg
	POP	ECX
;
; Line 662:	  ClrScr();
;
	CALL	_ClrScr
;
; Line 663:	  Window(0,0,79,24);
;
	PUSH	BYTE 018H
	PUSH	BYTE 04FH
	PUSH	BYTE 00H
	PUSH	BYTE 00H
	CALL	_Window
	ADD	ESP,BYTE 010H
;
; Line 666:	  if((NumDevs=SearchDevices())==0) error(8);
;
	CALL	_SearchDevices
	MOV	WORD [EBP+0FFFFFFFEH],AX
	MOVZX	EAX,AX
	TEST	EAX,EAX
	JNE	SHORT	L_266
	PUSH	BYTE 08H
	CALL	_error
	POP	ECX
L_266:
;
; Line 669:	  k=Select(NumDevs);
;
	MOVZX	EAX,WORD [EBP+0FFFFFFFEH]
	PUSH	EAX
	CALL	_Select
	POP	ECX
	MOV	BL,AL
;
; Line 670:	  LoadOS_RFS(k);
;
	MOVSX	EBX,BL
	PUSH	EBX
	CALL	_LoadOS_RFS
	POP	ECX
;
; Line 671:	  LoadFromDevice(k);
;
	MOVSX	EBX,BL
	PUSH	EBX
	CALL	_LoadFromDevice
	POP	ECX
;
; Line 673:	  return ErrorCode;
;
	MOV	EAX,DWORD [_ErrorCode]
L_268:
	POP	EBX
	MOV	ESP,EBP
	POP	EBP
	RET

L_199:
	DB	054H,069H,06DH,065H,020H,072H,065H,06DH,061H,069H,06EH,069H
	DB	06EH,067H,03AH,020H,00H
L_198:
	DB	053H,065H,06CH,065H,063H,074H,065H,064H,03AH,020H,00H
L_196:
	DB	0CDH,0C4H,0C7H,0B6H,0BAH,0B3H,00H
L_195:
	DB	050H,072H,06FH,074H,06FH,063H,06FH,06CH,028H,073H,029H,00H
L_194:
	DB	053H,075H,062H,074H,079H,070H,065H,02FH,070H,061H,072H,061H
	DB	06DH,065H,074H,065H,072H,073H,00H
L_193:
	DB	054H,079H,070H,065H,00H
L_192:
	DB	044H,065H,076H,069H,063H,065H,00H
L_190:
	DB	020H,020H,020H,020H,020H,020H,020H,052H,061H,064H,069H,061H
	DB	06EH,074H,020H,053H,079H,073H,074H,065H,06DH,020H,04CH,06FH
	DB	061H,064H,065H,072H,02CH,020H,076H,065H,072H,073H,069H,06FH
	DB	06EH,020H,031H,02EH,030H,020H,020H,028H,063H,029H,020H,031H
	DB	039H,039H,038H,020H,052H,045H,054H,020H,026H,020H,043H,04FH
	DB	04DH,020H,052H,065H,073H,065H,061H,072H,063H,068H,00H
L_187:
	DB	044H,065H,066H,061H,075H,06CH,074H,020H,073H,074H,061H,072H
	DB	074H,075H,070H,020H,063H,06FH,06EH,066H,069H,067H,075H,072H
	DB	061H,074H,069H,06FH,06EH,020H,06CH,06FH,061H,064H,065H,064H
	DB	02EH,020H,050H,072H,065H,073H,073H,020H,061H,06EH,079H,020H
	DB	06BH,065H,079H,02EH,02EH,02EH,00H
L_157:
	DB	025H,066H,064H,00H
L_129:
	DB	025H,068H,064H,00H
L_72:
	DB	08H,020H,08H,00H
L_51:
	DB	02EH,020H,050H,072H,065H,073H,073H,020H,061H,06EH,079H,020H
	DB	06BH,065H,079H,02EH,02EH,02EH,0AH,00H
L_50:
	DB	050H,072H,06FH,067H,072H,061H,06DH,020H,074H,065H,072H,06DH
	DB	069H,06EH,061H,074H,065H,064H,020H,06EH,06FH,072H,06DH,061H
	DB	06CH,06CH,079H,00H
L_49:
	DB	06EH,06FH,020H,06CH,06FH,061H,064H,061H,062H,06CH,065H,020H
	DB	064H,065H,076H,069H,063H,065H,073H,00H
L_48:
	DB	062H,06FH,06FH,074H,020H,073H,065H,063H,074H,06FH,072H,020H
	DB	073H,069H,067H,06EH,061H,074H,075H,072H,065H,020H,06EH,06FH
	DB	074H,020H,066H,06FH,075H,06EH,064H,00H
L_47:
	DB	073H,074H,061H,072H,074H,075H,070H,020H,063H,06FH,06EH,066H
	DB	069H,067H,075H,072H,061H,074H,069H,06FH,06EH,020H,064H,061H
	DB	074H,061H,020H,06EH,06FH,074H,020H,066H,06FH,075H,06EH,064H
	DB	00H
L_46:
	DB	064H,069H,073H,06BH,020H,06FH,070H,065H,072H,061H,074H,069H
	DB	06FH,06EH,020H,066H,061H,069H,06CH,075H,072H,065H,00H
L_45:
	DB	045H,052H,052H,04FH,052H,03AH,020H,00H
L_44:
	DB	046H,041H,054H,041H,04CH,020H,00H
L_43:
	DB	052H,06FH,06FH,074H,020H,06CH,069H,06EH,06BH,069H,06EH,067H
	DB	020H,070H,06FH,069H,06EH,074H,03DH,041H,03AH,00H
L_42:
	DB	052H,06FH,06FH,074H,020H,064H,065H,076H,069H,063H,065H,03DH
	DB	025H,066H,064H,031H,00H
L_41:
	DB	041H,058H,02EH,032H,035H,00H
L_40:
	DB	04EH,045H,054H,042H,045H,055H,049H,00H
L_39:
	DB	049H,050H,058H,00H
L_38:
	DB	054H,043H,050H,02FH,049H,050H,00H
L_37:
	DB	02DH,00H
L_36:
	DB	04EH,065H,074H,077H,06FH,072H,06BH,020H,063H,06FH,06EH,074H
	DB	072H,06FH,06CH,06CH,065H,072H,00H
L_35:
	DB	050H,06FH,072H,074H,00H
L_34:
	DB	054H,061H,070H,065H,00H
L_33:
	DB	052H,065H,06DH,06FH,076H,061H,062H,06CH,065H,020H,064H,069H
	DB	073H,06BH,00H
L_32:
	DB	048H,061H,072H,064H,020H,064H,069H,073H,06BH,00H
L_31:
	DB	046H,06CH,06FH,070H,070H,079H,020H,064H,069H,073H,06BH,00H
L_30:
	DB	045H,06DH,070H,074H,079H,00H
L_29:
	DB	052H,046H,053H,020H,073H,077H,061H,070H,00H
L_28:
	DB	052H,046H,053H,020H,06EH,061H,074H,069H,076H,065H,00H
L_27:
	DB	042H,042H,054H,00H
L_26:
	DB	044H,04FH,053H,020H,073H,065H,063H,06FH,06EH,064H,061H,072H
	DB	079H,00H
L_25:
	DB	044H,04FH,053H,020H,052H,02FH,04FH,00H
L_24:
	DB	044H,04FH,053H,020H,061H,063H,063H,065H,073H,073H,00H
L_23:
	DB	043H,050H,02FH,04DH,00H
L_22:
	DB	042H,053H,044H,049H,020H,073H,077H,061H,070H,00H
L_21:
	DB	042H,053H,044H,049H,020H,046H,053H,00H
L_20:
	DB	042H,053H,044H,020H,033H,038H,036H,00H
L_19:
	DB	04CH,069H,06EH,075H,078H,020H,06EH,061H,074H,069H,076H,065H
	DB	00H
L_18:
	DB	04CH,069H,06EH,075H,078H,020H,073H,077H,061H,070H,00H
L_17:
	DB	04DH,069H,06EH,069H,078H,00H
L_16:
	DB	04FH,06CH,064H,020H,04DH,069H,06EH,069H,078H,00H
L_15:
	DB	050H,043H,02FH,049H,058H,00H
L_14:
	DB	04EH,06FH,076H,065H,06CH,06CH,00H
L_13:
	DB	04DH,069H,063H,072H,06FH,070H,06FH,072H,074H,00H
L_12:
	DB	056H,065H,06EH,069H,078H,020H,032H,038H,036H,00H
L_11:
	DB	04FH,053H,02FH,032H,020H,062H,06FH,06FH,074H,020H,06DH,061H
	DB	06EH,061H,067H,065H,072H,00H
L_10:
	DB	041H,049H,058H,020H,062H,06FH,06FH,074H,061H,062H,06CH,065H
	DB	00H
L_9:
	DB	041H,049H,058H,00H
L_8:
	DB	04FH,053H,02FH,032H,020H,048H,050H,046H,053H,00H
L_7:
	DB	044H,04FH,053H,020H,046H,041H,054H,031H,036H,020H,03EH,03DH
	DB	033H,032H,04DH,00H
L_6:
	DB	044H,04FH,053H,020H,065H,078H,074H,065H,06EH,064H,065H,064H
	DB	00H
L_5:
	DB	044H,04FH,053H,020H,046H,041H,054H,031H,036H,020H,03CH,033H
	DB	032H,04DH,00H
L_4:
	DB	058H,045H,04EH,049H,058H,020H,075H,073H,072H,00H
L_3:
	DB	058H,045H,04EH,049H,058H,020H,072H,06FH,06FH,074H,00H
L_2:
	DB	044H,04FH,053H,020H,046H,041H,054H,031H,032H,00H
L_1:
	DB	00H
SECTION .data
[GLOBAL	_ErrorCode]

_ErrorCode	DD	00H
[GLOBAL	_FStypesList]

_FStypesList	DB	00H
	RESB	03H
	DD	L_1
	DB	01H
	RESB	03H
	DD	L_2
	DB	02H
	RESB	03H
	DD	L_3
	DB	03H
	RESB	03H
	DD	L_4
	DB	04H
	RESB	03H
	DD	L_5
	DB	05H
	RESB	03H
	DD	L_6
	DB	06H
	RESB	03H
	DD	L_7
	DB	07H
	RESB	03H
	DD	L_8
	DB	08H
	RESB	03H
	DD	L_9
	DB	09H
	RESB	03H
	DD	L_10
	DB	0AH
	RESB	03H
	DD	L_11
	DB	040H
	RESB	03H
	DD	L_12
	DB	052H
	RESB	03H
	DD	L_13
	DB	064H
	RESB	03H
	DD	L_14
	DB	075H
	RESB	03H
	DD	L_15
	DB	080H
	RESB	03H
	DD	L_16
	DB	081H
	RESB	03H
	DD	L_17
	DB	082H
	RESB	03H
	DD	L_18
	DB	083H
	RESB	03H
	DD	L_19
	DB	0A5H
	RESB	03H
	DD	L_20
	DB	0B7H
	RESB	03H
	DD	L_21
	DB	0B8H
	RESB	03H
	DD	L_22
	DB	0DBH
	RESB	03H
	DD	L_23
	DB	0E1H
	RESB	03H
	DD	L_24
	DB	0E3H
	RESB	03H
	DD	L_25
	DB	0F2H
	RESB	03H
	DD	L_26
	DB	0FFH
	RESB	03H
	DD	L_27
	DB	032H
	RESB	03H
	DD	L_28
	DB	033H
	RESB	03H
	DD	L_29
	RESB	010H
[GLOBAL	_DevTypesList]

_DevTypesList	DD	L_30,L_31,L_32,L_33,L_34,L_35,L_36
[GLOBAL	_ProtTypesList]

_ProtTypesList	DD	L_37,L_38,L_39,L_40,L_41
[GLOBAL	_DefaultConfig]

_DefaultConfig	DD	L_42,L_43

L_121	DB	055H,06EH,06BH,06EH,06FH,077H,06EH,00H

L_183	DB	052H,046H,053H,020H,030H,031H,02EH,030H,030H,00H
	RESB	02H

L_191	DD	L_192,L_193,L_194,L_195

L_197	DB	010H,014H,018H,0FH

L_265	DB	025H,066H,064H,031H,00H
	RESB	0CH
SECTION .bss

_RSC_Area	RESB	0200H

_StartupCSHD	RESB	04H
[GLOBAL	_FDDparms]

_FDDparms	RESB	018H
[GLOBAL	_HDDparms]

_HDDparms	RESB	018H
[GLOBAL	_MainMBRs]

_MainMBRs	RESB	0404H
[GLOBAL	_ExtMBRs]

_ExtMBRs	RESB	01010H
[GLOBAL	_DevInfo]

_DevInfo	RESB	0CC0H

SECTION .text
[BITS 32]
[EXTERN	_ClrScr]
[EXTERN	_StrEnd]
[EXTERN	_Window]
[EXTERN	_DiskOperation]
[EXTERN	_Delay1WithKB]
[EXTERN	_WaitKey]
[EXTERN	_wDecOut]
[EXTERN	_StrCopy]
[EXTERN	_GetDiskDriveParms]
[EXTERN	_WrCharA]
[EXTERN	_MoveCur]
[EXTERN	_KeyPressed]
[EXTERN	_WrVidMem]
[EXTERN	_StrLen]
[EXTERN	_WrChar]
[EXTERN	_WrString]
[EXTERN	_WrStringXY]
[EXTERN	_SetVidPg]

SECTION .data
[EXTERN	_WhereY]
[EXTERN	_WhereX]
[EXTERN	_CurrVidMode]
