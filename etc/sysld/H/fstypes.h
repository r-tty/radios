
typedef struct
        {
         byte SysID;
	 PChar Type;
	}tFS;

#define NUMKNOWNFS       31

#define FS_EMPTY	 0
#define FS_DOSFAT12	 1
#define FS_XENIXROOT	 2
#define FS_XENIXUSR	 3
#define FS_DOSFAT16SMALL 4
#define FS_DOSEXTENDED	 5
#define FS_DOSFAT16LARGE 6
#define FS_OS2HPFS	 7
#define FS_AIX		 8
#define FS_AIXBOOT	 9
#define FS_OS2BM	 0xA
#define FS_VENIX286	 0x40
#define FS_MICROPORT	 0x52
#define FS_NOVELL	 0x64
#define FS_PCIX		 0x75
#define FS_OLDMINIX	 0x80
#define FS_MINIX	 0x81
#define FS_LINUXSWAP	 0x82
#define FS_LINUXNATIVE	 0x83
#define FS_BSD386	 0xA5
#define FS_BSDIFS	 0xB7
#define FS_BSDISWAP	 0xB8
#define FS_CPM		 0xDB
#define FS_DOSACCES	 0xE1
#define FS_DOSRDONLY	 0xE3
#define FS_DOSSECONDARY	 0xF2
#define FS_BBT		 0xFF

#define FS_RFSNATIVE	 0x32
#define FS_RFSSWAP	 0x33
