
// --- Kernel errors ---

// Common errors
#define ERR_BadFunNum			0x0100
#define ERR_UnknEv			0x0101
#define ERR_NoGlobDesc			0x0102
#define ERR_InvGlobDesc			0x0103

// Kernel heap errors
#define ERR_KH_Empty			0x0300
#define ERR_KH_Destroyed		0x0301
#define ERR_KH_BlNotFound		0x0302
#define ERR_KH_NoHandles		0x0303

// Drivers control errors
#define ERR_DRV_NoIDs			0x0320
#define ERR_DRV_BadID			0x0321
#define ERR_DRV_NotInitialized		0x0322
#define ERR_DRV_NoMinor			0x0333
#define ERR_DRV_BadMinor		0x0334
#define ERR_DRV_NotOpened		0x0335
#define ERR_DRV_AlreadyOpened		0x0336

// Memory errors
#define ERR_MEM_InvBaseSz		0x0340
#define ERR_MEM_ExtTestErr		0x0341
#define ERR_MEM_InvCMOSExtMemSz		0x0342

// Task manager errors
#define ERR_MT_PrTblFull		0x0360
#define ERR_MT_BadPID			0x0361

// Filesystem errors
#define ERR_FS_InitTooManyLP		0x0380
#define ERR_FS_BadLP			0x0381
#define ERR_FS_NoFSdriver		0x0382
#define ERR_FS_NoBlockDev		0x0383
#define ERR_FS_NotLinked		0x0384

#define ERR_FS_FileNotFound		0x0390
#define ERR_FS_FileExists		0x0391
#define ERR_FS_DiskFull			0x0392

// === Internal hardware drivers errors ===

// --- On-board devices ---

// KBC errors
#define ERR_KBC_NotRDY			0x0800

// Counter/timer and RTC errors
#define ERR_TMR_BadCNBR			0x0820

// DMA controllers errors
#define ERR_DMA_BadChNum		0x0840
#define ERR_DMA_BadAddr			0x0841
#define ERR_DMA_PageOut			0x0842
#define ERR_DMA_AddrOdd			0x0843

// BIOS32 errors
#define ERR_BIOS32_NotFound		0x0860


// --- External devices ---

// Keyboard errors
#define ERR_KB_DetFail			0x1100

// Video text device errors
#define ERR_VTX_DetFail			0x1120
#define ERR_VTX_BadVPage		0x1121
#define ERR_VTX_BadCurPos		0x1122

// FDC errors
#define ERR_FDC_BadDrNum		0x1140
#define ERR_FDC_Timeout			0x1141
#define ERR_FDC_Seek			0x1142
#define ERR_FDC_Status			0x1143

// Common disk routines errors
#define ERR_DISK_MediaChgd		0x1160
#define ERR_DISK_NoMedia		0x1161
#define ERR_DISK_BadNumOfSectors	0x1168

// DIHD errors
#define ERR_HD_InitTooManyDrv		0x1170
#define ERR_HD_NoDiskOp			0x1171
#define ERR_HD_NoDescriptors		0x1172
#define ERR_HD_BadMBRsig		0x1173

// IDE errors
#define ERR_IDE_InitTooManyDrv		0x1190
#define ERR_IDE_General			0x1191
#define ERR_IDE_BadSector		0x1192
#define ERR_IDE_ResFailed		0x1193
#define ERR_IDE_BadDriveNum		0x1194
#define ERR_IDE_BadLBA			0x1195
#define ERR_IDE_TooManySectors		0x1196
#define ERR_IDE_NoBlockMode		0x1197


// === Internal software drivers errors ===

// --- Consoles driver error ---
#define ERR_CON_BadConNum		0x1800


// === File system drivers errors ===

// --- RFS ---

#define ERR_RFS_NoSATs			0x1C00
#define ERR_RFS_NoRoot			0x1C01


// --- MDOSFS ---
