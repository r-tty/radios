#include <stdio.h>
#include <alloc.h>

typedef unsigned char byte;
typedef unsigned int  word;

void pout(word port_addr,byte value);
byte pin(word port_addr);
void PnP_wait(void);
void PnP_reset(void);

void PnP_init(void) {
 PnP_reset();
 pout(0x279,2);
 PnP_wait();
 pout(0xA79,6);
 PnP_wait();
 PnP_reset();
 }

void PnP_firstset(void) {
 pout(0x279,3);
 PnP_wait();
 pout(0xA79,0);
 PnP_wait();
 pout(0x279,0);
 PnP_wait();
 pout(0xA79,0x80);
 PnP_wait();
 }

void PnP_num(byte num) {
 pout(0x279,6);
 PnP_wait();
 pout(0xA79,num);
 };

char PnP_signature(char* buffer) {

byte BitCount;
byte ByteCount;
byte Byte1,Byte2;
byte Mask;
byte FOUND;

 FOUND=0;
 pout(0x279,3);
 PnP_wait();
 pout(0xA79,0);
 PnP_wait();
 pout(0x279,1);
 PnP_wait();

 for(ByteCount=0;ByteCount<9;ByteCount++) {
  Mask=1;
  *(buffer+ByteCount)=0;
  for(BitCount=0;BitCount<8;BitCount++) {
   Byte1=pin(0x203);
   PnP_wait();
   Byte2=pin(0x203);
   if(Byte1==0x55 && Byte2==0xAA) {
    *(buffer+ByteCount)=*(buffer+ByteCount) | Mask;
    FOUND=1;
    }
   Mask=Mask<<1;
   }
  }
 return(FOUND);
 }

void PnP_info(byte num, char* buffer) {
 word count;

 pout(0x279,3);
 PnP_wait();
 pout(0xA79,num);
 PnP_wait();

 for(count=0;count<0x1000;count++) {
  pout(0x279,5);
  PnP_wait();
  pin(0x203);
  pout(0x279,4);
  *(buffer+count)=pin(0x203);
  }
 }

void PnP_param(byte num) {
 byte value;
 byte count;
 word wvalue;

 pout(0x279,3);
 PnP_wait();
 pout(0xA79,num);
 PnP_wait();
 pout(0x279,7);
 PnP_wait();
 pout(0xA79,1);
 PnP_wait();

/*for(count=0x40;count<0x76;count++) {
  pout(0x279,count);
  PnP_wait();
  value=pin(0x203);
  }*/

 pout(0x279,0x60);
 PnP_wait();
 value=pin(0x203);
 pout(0x279,0x61);
 PnP_wait();
 wvalue=value*0x100+pin(0x203);
 printf("Base IO Addres (HEX) : %x\n",wvalue);

 /*pout(0x279,0x62);
 PnP_wait();
 value=pin(0x203);
 pout(0x279,0x63);
 PnP_wait();
 wvalue=value*0x100+pin(0x203);
 printf("Adlib port     (HEX) : %x\n",wvalue);

 pout(0x279,0x64);
 PnP_wait();
 value=pin(0x203);
 pout(0x279,0x65);
 PnP_wait();
 wvalue=value*0x100+pin(0x203);
 printf("MPU-401 port   (HEX) : %x\n",wvalue); */

 PnP_wait();
 pout(0x279,0x70);
 wvalue=pin(0x203);
 printf("Interrupt IRQ  (HEX) : %x\n",wvalue);

 PnP_wait();
 pout(0x279,0x74);
 value=pin(0x203);
 if(value!=4) printf("DMA Channel    (HEX) : %x\n",value);
 }

char* BUFFER;
char* AREA;
char FOUND;
char DevCount;
char SelDev;
word temp;

int main()
 {

  puts("\n");

  DevCount=0;

  PnP_init();
  PnP_firstset();

  do {
      if((FOUND=PnP_signature(BUFFER))!=0)
	PnP_num(++DevCount);
     } while(FOUND);
  printf("Found Plug & Play devices : %d\n",DevCount);
  puts("-----------------------------\n");

  if((AREA=malloc(32768))==0) return 1;
  for(SelDev=1;SelDev<=DevCount;SelDev++)
   {
    PnP_info(SelDev,AREA);
    for(temp=33;*(AREA+temp)!=0x15;temp++);
    *(AREA+temp)=0;
    printf("%s\n\n",AREA+15);
    PnP_param(SelDev);
    printf("\n\n");
   }
  free(AREA);
 }
