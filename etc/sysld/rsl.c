/*******************************************************************************
  rsl.c - Radiant System Loader, version 1.0.
  Copyright (c) 1998 RET & COM research. All rights reserved.
*******************************************************************************/

#define DEBUG					// Uncomment for debugging

#include <utypes.h>
#include <env.h>
#include <bioslib.h>
#include <strings.h>
#include <digout.h>
#include <misc.h>

#include "H/mbr.h"
#include "H/fstypes.h"
#include "H/fkeys.h"

#include "H/rsl.h"
#include "H/rsconfig.h"
#include "H/rfs.h"

#pragma warn -aus
#pragma warn -par

//--- Definitions --------------------------------------------------------------

#define Case break;case
#define ESC 27
#define TAB 9

#define MAXNAMELEN 16					// Without NULL
#define NUMDEVICES 64

#define MAXFDD 2
#define MAXHDD 2
#define MAXEXTMBRS 8

#define TIME_INTERVAL 30

// Device information structure
typedef struct {
		byte DevID;			// Device ID (major number)
		byte TypeID;			// Device type ID
		byte ProtID;			// Protocol ID (char dev. only)
		byte Minor,SubMinor;		// Minor & subminor number
		word Extended;			// Extended MBR and partition
		char Name[MAXNAMELEN+1];
		char Parms[23];
	       }tDevInfo;

//--- Data ---------------------------------------------------------------------

#ifdef DEBUG
static byte RSC_Area[SECTORSIZE];
static ulong StartupCSHD;
#else
extern ulong StartupCSHD;
#endif

int ErrorCode=0;				// Global error code

tDiskDriveParam FDDparms[MAXFDD];
tDiskDriveParam HDDparms[MAXHDD];

tMBR MainMBRs[MAXHDD];
tMBR ExtMBRs[MAXEXTMBRS];

tDevInfo DevInfo[NUMDEVICES];

tFS FStypesList[NUMKNOWNFS]=
      { {FS_EMPTY,         ""},
	{FS_DOSFAT12,      "DOS FAT12"},
	{FS_XENIXROOT,     "XENIX root"},
	{FS_XENIXUSR,      "XENIX usr"},
	{FS_DOSFAT16SMALL, "DOS FAT16 <32M"},
	{FS_DOSEXTENDED,   "DOS extended"},
	{FS_DOSFAT16LARGE, "DOS FAT16 >=32M"},
	{FS_OS2HPFS,       "OS/2 HPFS"},
	{FS_AIX,           "AIX"},
	{FS_AIXBOOT,       "AIX bootable"},
	{FS_OS2BM,	   "OS/2 boot manager"},
	{FS_VENIX286,      "Venix 286"},
	{FS_MICROPORT,	   "Microport"},
	{FS_NOVELL,        "Novell"},
	{FS_PCIX,	   "PC/IX"},
	{FS_OLDMINIX,	   "Old Minix"},
	{FS_MINIX,	   "Minix"},
	{FS_LINUXSWAP,	   "Linux swap"},
	{FS_LINUXNATIVE,   "Linux native"},
	{FS_BSD386,        "BSD 386"},
	{FS_BSDIFS,	   "BSDI FS"},
	{FS_BSDISWAP,	   "BSDI swap"},
	{FS_CPM,	   "CP/M"},
	{FS_DOSACCES,	   "DOS access"},
	{FS_DOSRDONLY,	   "DOS R/O"},
	{FS_DOSSECONDARY,  "DOS secondary"},
	{FS_BBT,	   "BBT"},

	{FS_RFSNATIVE,	   "RFS native"},
	{FS_RFSSWAP,       "RFS swap"}
      };

PChar DevTypesList[7]=
       { "Empty",
	 "Floppy disk",
	 "Hard disk",
	 "Removable disk",
	 "Tape",
	 "Port",
	 "Network controller" };

PChar ProtTypesList[5]=
       { "-",
	 "TCP/IP",
	 "IPX",
	 "NETBEUI",
	 "AX.25" };

PChar DefaultConfig[RSC_NumDfltItems]=
	  { "Root device=%fd1",
	    "Root linking point=A:" };


//--- Functions ----------------------------------------------------------------

//--- Common functions ---//

// Print error message and exit
static void error(int ErrCode)
 {
  if(ErrCode)
   {
    if(ErrCode>=8) WrString("FATAL ");
    WrString("ERROR: ");
    switch(ErrCode)
     {
      case 1: WrString("disk operation failure");
      Case 2: WrString("startup configuration data not found");
      Case 3: WrString("boot sector signature not found");
      Case 8: WrString("no loadable devices");
     }
   }
  else WrString("Program terminated normally");
  WrString(". Press any key...\n");
  WaitKey();
  ErrorCode=ErrCode;
 }


// Print short help message
static void Help(void)
 {
 }


// Light up selected line
static void LightLine(const byte Row)
 {
  byte HLattr=127,k;

  if(*CurrVidMode==7) HLattr=112;
  for(k=5;k<78*2;k+=2) WrVidMem((Row+5)*160+k,HLattr);
 }


// Blank line
static void BlankLine(const byte Row)
 {
  byte k;

  for(k=5;k<79*2;k+=2) WrVidMem((Row+5)*160+k,7);
 }


// Get string
static char *GetString(char *Prompt, char *edstr)
 {
  char k,m,ch,TmpBuf[MAXNAMELEN+1];
  unsigned BKey;

  WrString(Prompt);
  if((k=m=StrLen(edstr))!=0) WrString(StrCopy(TmpBuf,edstr));
  for(;;)
   {
    switch(ch=BKey=WaitKey())
     {
       case '\0': switch(BKey >> 8)
		   {
		    case KEY_F1: Help();
				 WrString(Prompt);
				 TmpBuf[k]='\0';
				 WrString(TmpBuf);
				 break;
		   }
		  continue;
       case '\b': if(k)
		   { k--;
		     WrString("\b \b");
		   }
		  continue;
       case '\r': TmpBuf[k]='\0';
		  StrCopy(edstr,TmpBuf);
		  WrChar('\n');
		  return edstr;
       case ESC:  StrCopy(TmpBuf,edstr);
		  while(k--) WrChar('\b');
		  WrString(TmpBuf);
		  for(k=0;k<=MAXNAMELEN;k++) WrChar(' ');
		  while(k--) WrChar('\b');
		  k=m;
       Case TAB:  //ShowList();
		  WrString(Prompt);
		  TmpBuf[k]='\0';
		  WrString(TmpBuf);
		  break;
       default:   if(k!=MAXNAMELEN) WrChar(TmpBuf[k++]=ch);
     }
   }
 }


// Get cylinder number from BIOS-packed CylSec
word GetCylFromCX(const word CX)
 {
  byte t;

  t=CX;
  return (CX >> 8)+256*(t >> 6) ;
 }


// Get sector number from BIOS-packed CylSec
byte GetSecFromCX(const word CX)
 {
  return CX & 0x3F;
 }


// Load boot sector from device
byte LoadBootSec(const byte DevNum, char *Buffer)
 {
  pointer P;
  byte Drv,Part,H,S;
  word C,t;

  Drv=DevInfo[DevNum].Minor;
  if(DevInfo[DevNum].DevID==ID_HARDDISK)
   {
    tMBR *MBRptr;
    word Part;

    if((t=DevInfo[DevNum].Extended)!=0)
     {
      MBRptr=&ExtMBRs[(t>>8)-1];
      Part=(t & 0x3F)-1;
     }
    else
     {
      MBRptr=&MainMBRs[Drv];
      Part=DevInfo[DevNum].SubMinor-1;
     }
    H=MBRptr->PartEntries[Part].BeginHead;
    C=GetCylFromCX(t=MBRptr->PartEntries[Part].BeginSecCyl);
    S=GetSecFromCX(t);

    Drv+=0x80;
   }
  else
   {
    C=H=0;
    S=1;
    t=1;
   }

  if(DiskOperation(Drv,C,H,S,1,Buffer,DISKOP_READSEC)) error(1);
  else ErrorCode=0;

  return ErrorCode;
 }


//--- Device information structure functions ---//

// Fill device information structure
static void FillDevInfo(byte Num, byte DevID, byte TypeID, byte ProtID,\
		 byte Minor, byte SubMinor, word Extended,\
		 const PChar Name, const PChar Parms)
 {
  PChar t;

  DevInfo[Num].DevID=DevID;
  DevInfo[Num].TypeID=TypeID;
  DevInfo[Num].ProtID=ProtID;
  DevInfo[Num].Minor=Minor;
  DevInfo[Num].SubMinor=SubMinor;
  DevInfo[Num].Extended=Extended;
  t=StrEnd(StrCopy(DevInfo[Num].Name,Name));
  t[0]=Minor+'1';
  if(SubMinor)
   {
    t[1]='.';
    if(Extended)
     {
      if((t[2]=(Extended >> 8)+'4')>'9') t[2]+='a'-':';
     }
    else t[2]=SubMinor+'0';
    t[3]=0;
   }
  else t[1]=0;
  StrCopy(DevInfo[Num].Parms,Parms);
 }


// Search FS name in table by number
PChar FindFSname(byte ID)
 {
  static char Unknown[]="Unknown";
  byte k;
  for(k=0;k<NUMKNOWNFS;k++)
   if(FStypesList[k].SysID==ID) return FStypesList[k].Type;
  return Unknown;
 }


//--- Device searching and loading functions ---//

/*
  Search primary and extended partitions on hard disk and fill apropriate
  device information.
  Parameters: Drive - drive number (0,1,2,...);
	      *DevCount - current device counter.
  Returns: 1 - OK;
	   0 - error.
 */
static bool SearchHDpartitions(byte Drive, byte *DevCount)
 {
  byte k,c;
  const PChar NameHD="%hd";

  if(GetDiskDriveParms(Drive+0x80,&HDDparms[Drive])) return 0;

  DiskOperation(Drive+0x80,0,0,1,1,&MainMBRs[Drive],DISKOP_READSEC);
  if(MainMBRs[Drive].Signature==MBR_SIGNATURE)
   for(k=0;k<4;k++)
    {
     if((c=MainMBRs[Drive].PartEntries[k].SystemCode)!=0)
      {
       FillDevInfo(*DevCount,ID_HARDDISK,c,0, Drive,k+1,0, NameHD,FindFSname(c));
       (*DevCount)++;
      }
     if(c==FS_DOSEXTENDED)
      {
       byte keepk=k, k1, EMBRcount=0, Sec;
       word Cyl;
       tMBR *EMBR=&MainMBRs[Drive];

       do {
	   Cyl=GetCylFromCX(EMBR->PartEntries[k].BeginSecCyl);
	   Sec=GetSecFromCX(EMBR->PartEntries[k].BeginSecCyl);
	   DiskOperation(Drive+0x80,Cyl,EMBR->PartEntries[k].BeginHead,\
			 Sec,1,&ExtMBRs[EMBRcount],DISKOP_READSEC);
	   k=5;
	   if(ExtMBRs[EMBRcount].Signature==MBR_SIGNATURE)
	    {
	     for(k1=0;k1<4;k1++)
	      {
	       if((c=ExtMBRs[EMBRcount].PartEntries[k1].SystemCode)==0) break;
	       if(c==FS_DOSEXTENDED) k=k1;
	       else
		{
		 FillDevInfo(*DevCount,ID_HARDDISK,c,0,Drive,\
			     keepk+1,256*(EMBRcount+1)+k1+1,\
			     NameHD,FindFSname(c));
		 (*DevCount)++;
		}
	      }
	     if(k<4) EMBR=&ExtMBRs[EMBRcount++];
	    }
	   else break;
	  } while(k<4);
       k=keepk;
      }
    }
  return 1;
 }


// Search loadable devices
static word SearchDevices(void)
 {
  tDiskDriveParam DiskParms;
  byte DevCount=0,h;
  const PChar NameFD="%fd";

  // Search FDs
  if(!GetDiskDriveParms(0,&FDDparms[0]))
   {
    FillDevInfo(DevCount,ID_FLOPPYDISK,FDDparms[0].DriveType,\
		0,0,0,0,NameFD,"");
    DevCount++;
    if(FDDparms[0].NumDrives>1)
     if(!GetDiskDriveParms(1,&FDDparms[1]))
       {
	FillDevInfo(DevCount,ID_FLOPPYDISK,FDDparms[1].DriveType,\
		    0,1,0,0,NameFD,"");
	DevCount++;
       }
     else FDDparms[1].DriveType=-1;
   }
  else FDDparms[0].NumDrives=0;

  // Search HDs and read MBRs
  if(SearchHDpartitions(0,&DevCount))
   {
    for(h=1;h<HDDparms[0].NumDrives;h++)
     if(!SearchHDpartitions(h,&DevCount))
      {
       HDDparms[h].DriveType=-1;
       break;
      }
   }
  else HDDparms[0].NumDrives=0;

  return DevCount;
 }


// Load from floppy or hard disk
static void LoadFromDisk(const byte DevNum)
 {
  /*
  (word)StartupCSHD=t;
  t<<=16;
  (word)StartupCSHD=Drv+256*H;
  */

  LoadBootSec(DevNum,(char *)0x7C00);
 }


// Load from removable disk
static void LoadFromRmvDisk(const byte DevNum)
 {
 }


// Load from tape
static void LoadFromTape(const byte DevNum)
 {
 }


// Load from port
static void LoadFromPort(const byte DevNum)
 {
 }


// Load from network
static void LoadFromNet(const byte DevNum)
 {
 }

// Load OS from specified device
static void LoadFromDevice(const byte DevNum)
 {
  switch(DevInfo[DevNum].DevID)
   {
    case ID_EMPTY:         break;

    case ID_FLOPPYDISK:
    case ID_HARDDISK:	   LoadFromDisk(DevNum);

    Case ID_RMVDISK:	   LoadFromRmvDisk(DevNum);
    Case ID_TAPE:	   LoadFromTape(DevNum);
    Case ID_PORT:	   LoadFromPort(DevNum);
    Case ID_NETBOARD:	   LoadFromNet(DevNum);
   }
 }


// Load OS from RFS partition
static void LoadOS_RFS(const byte DevNum)
 {
  char RFSsig[]="RFS 01.00";
  char BootSec[512];

  if(!LoadBootSec(DevNum,BootSec)) return;
 }


//--- Load, save and edit startup configuration functions ---//

static void LoadStartupConfig(const byte DevNum)
 {
  byte Drv,Part,H,S;
  word C,t;

  if(DevNum==255)
   {
    WrString("Default startup configuration loaded. Press any key...");
    WaitKey();
    WrChar('\r'); WrCharA(' ',7,80);			// Clear line
   }

  //DiskOperation(DISKOP_READSEC);
 }

static void SaveStartupConfig(byte DevNum)
 {
 }

static void EditStartupConfig(void)
 {
  WrChar(7);
 }

//--- Dialog functions ---//

// Select loadable device
static byte Select(byte NumDevices)
 {
  const PChar ProgVer="       Radiant System Loader, version 1.0  (c) 1998 RET & COM Research";
  const PChar ColNames[]={"Device","Type","Subtype/parameters","Protocol(s)"};
  const PChar Sym=" €°´¡";
  byte ColWidth[4]={16,20,24,15};
  byte i,j,k,Sel=0,Time=TIME_INTERVAL;
  char ch;
  word BKey;
  bool CountDown=1;

  WrChar('¥');
  WrCharA(Sym[0],LIGHTGRAY,78);
  MoveCur(79,0);
  WrChar('¨'); WrChar(Sym[4]);
  WrString(ProgVer);
  MoveCur(79,1);
  WrChar(Sym[4]); WrChar(Sym[2]);
  for(i=0;i<4;i++)
   {
    WrCharA(Sym[1],LIGHTGRAY,ColWidth[i]);
    MoveCur(WhereX+ColWidth[i],WhereY);
    if(i!=3) WrChar('ˆ');
   }
  WrChar(Sym[3]); WrChar(Sym[4]);
  for(i=0;i<4;i++)
   {
    k=(ColWidth[i]-StrLen(ColNames[i]))/2;
    MoveCur(WhereX+k,3);
    WrString(ColNames[i]);
    MoveCur(WhereX+k,3);
    if(i!=3) WrChar(Sym[5]);
   }
  WrChar(Sym[4]); WrChar(Sym[2]);
  for(i=0;i<4;i++)
   {
    WrCharA('€',LIGHTGRAY,ColWidth[i]);
    MoveCur(WhereX+ColWidth[i],WhereY);
    if(i!=3) WrChar('Š');
   }
  WrChar(Sym[3]);
  for(i=0;i<NumDevices;i++)
   {
    WrChar(Sym[4]); WrChar(' '); WrString(DevInfo[i].Name);
    MoveCur(ColWidth[0]+1,i+5);
    WrChar(Sym[5]); WrChar(' '); WrString(DevTypesList[DevInfo[i].DevID]);
    MoveCur(ColWidth[0]+ColWidth[1]+2,i+5);
    WrChar(Sym[5]); WrChar(' '); WrString(DevInfo[i].Parms);
    MoveCur(ColWidth[0]+ColWidth[1]+ColWidth[2]+3,i+5);
    WrChar(Sym[5]); WrChar(' '); WrString(ProtTypesList[DevInfo[i].ProtID]);
    MoveCur(79,i+5); WrChar(Sym[4]);
   }

  WrChar(Sym[2]);
  for(k=0;k<4;k++)
   {
    WrCharA(Sym[1],LIGHTGRAY,ColWidth[k]);
    MoveCur(WhereX+ColWidth[k],WhereY);
    if(k!=3) WrChar('‰');
   }
  WrChar(Sym[3]);

  WrChar(Sym[4]);
  MoveCur(79,i+6); WrChar(Sym[4]);
  WrChar('«'); WrCharA(Sym[0],LIGHTGRAY,78);
  MoveCur(79,i+7); WrChar('®');

  for(i=0;i<NumDevices;i++)
   if(DevInfo[i].DevID==ID_HARDDISK)
    {
     Sel=i;
     break;
    }

  MoveCur(9,NumDevices+6);
  WrString("Selected: ");
  WrString(DevInfo[i].Name);
  WrStringXY(49,NumDevices+6,"Time remaining: ");
  MoveCur(0,NumDevices+8);
  LightLine(Sel);
  for(;;)
   {
    if(KeyPressed())
     {
      if(CountDown)
       {
	CountDown=0;
	MoveCur(49,NumDevices+6);
	WrCharA(' ',LIGHTGRAY,24);
	MoveCur(0,NumDevices+8);
       }
      switch(ch=BKey=WaitKey())
       {
	case '\0': switch(BKey >> 8)
		    {
		     case KEY_F1: Help();
		     Case KEY_UP: if(Sel>0)
				   {
				    BlankLine(Sel);
				    LightLine(--Sel);
				   }
		     Case KEY_DOWN: if(Sel<NumDevices-1)
				     {
				      BlankLine(Sel);
				      LightLine(++Sel);
				     }
		     Case KEY_F7: LoadStartupConfig(Sel);
				  if(!ErrorCode) EditStartupConfig();
				  else ErrorCode=0;
		     Case KEY_Shift_F7: LoadStartupConfig(255); // Load defaults

		    }
		   MoveCur(19,NumDevices+6);
		   WrString(DevInfo[Sel].Name); WrCharA(' ',LIGHTGRAY,5);
		   MoveCur(0,NumDevices+8);
		   continue;

	case '\r': return Sel;
       }
     }
    else if(CountDown)
	  {
	   MoveCur(65,NumDevices+6);
	   wDecOut(--Time); WrChar(' ');
	   MoveCur(0,NumDevices+8);
	   Delay1WithKB();
	   if(!Time) return Sel;
	  }
   }
 }

//--- Main ---------------------------------------------------------------------

int main(void)
 {
  char k,*Name,Buf[MAXNAMELEN+1]="%fd1";
  word NumDevs;

  // Prepare screen
  SetVidPg(7);
  ClrScr();
  Window(0,0,79,24);

  // Search loadable devices
  if((NumDevs=SearchDevices())==0) error(8);

  // Select device and load from it
  k=Select(NumDevs);
  LoadOS_RFS(k);
  LoadFromDevice(k);

  return ErrorCode;
 }
