/*******************************************************************************
   fileio.h - RadiOS file input/output routines.
   (c) 1999 RET & COM Research.
*******************************************************************************/

typedef struct
  {
   word level;
   word flags;
   ulong fd;
  } FILE;
