/*******************************************************************************
   rfs.h - RadiOS File System (RFS) definitions.
*******************************************************************************/

#define RFS_FILENAMELEN 20

// Master block
typedef struct {
		word  JmpCode;
		byte  FSID[10];
		byte  BootProg[RFS_FILENAMELEN];
		ulong Ver;
		ulong NumBAMs;
		ulong KBperBAM;
		ulong RootDir;
		ulong LoaderOfs;
		ulong LoaderSz;
	       } tRFS_MB;

// Directory page
typedef struct {
		byte  Flags;
		byte  Items;
		word  Type;
		byte  Name[RFS_FILENAMELEN];
		byte  IAttr[24];
		word  AR;
		word  Reserved;
		ulong Owner;
		ulong UU;
		ulong PageLess;
	       } tRFS_DP;

// Directory entry
typedef struct {
		byte  Name[RFS_FILENAMELEN];
		byte  UU[3];
		byte  Flags;
		ulong Entry;
		ulong More;
	       } tRFS_DE;

// File page

#define FPSignature	0x5046
#define FPDirectEntries	175
#define FPInDirEntries	64

typedef struct {
		word  Signature;
		word  Type;
		byte  Name[RFS_FILENAMELEN];
		ulong Len;
		byte  IAttr[24];
		word  AR;
		ulong Owner;
		ulong Direct[FPDirectEntries];
		ulong Indirect[FPDirectEntries];
	       } tRFS_FP;
