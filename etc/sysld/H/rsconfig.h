/*******************************************************************************
  rsconfig.h - RadiOS startup configuration structure.
*******************************************************************************/

#define RSC_Signature		0x435352
#define RSC_MaxNumItems		20
#define RSC_NumDfltItems	2

typedef struct {
		ulong  Signature;
		word   NumOfItems;
		word   ItemOffsets[RSC_MaxNumItems];	// size=var
	       } tRSC;

#ifndef DEBUG
#define RSC_Area	0x500
#endif