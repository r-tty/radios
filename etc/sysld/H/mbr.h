/*******************************************************************************
  mbr.h - HDD master boot record structure.
*******************************************************************************/

typedef struct
	{
	 byte BootFlag;
	 byte BeginHead;
	 word BeginSecCyl;
	 byte SystemCode;
	 byte EndHead;
	 word EndSecCyl;
	 ulong RelStartSecNum;
	 ulong NumSectors;
	}tPartitionEntry;

typedef struct
	{
	 byte LoadingCode[0x1BE];
	 tPartitionEntry PartEntries[4];
	 word Signature;
	}tMBR;

#define MBR_SIGNATURE 0xAA55