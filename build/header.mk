
# Cancel all built-in rules
% : %

# Control variables
SUFFIXES = .nasm .rdm .rdx .bin

# Rule to make RDM from NASM source
%.rdm : %.nasm
	@echo Assembling $<
	@$(AS) $(ASFLAGS) $(OUTPATH)/$@ $<
	
# Rule to compile C source
%.rdm : %.c
	@echo Compiling $<
	@$(CC) -o $(OUPATH)/$@ $<
	
# Paths
RADIOSPATH = /home/yuriz/radios
INCLPATH = /home/yuriz/radios/include
OUTPATH = /home/yuriz/radios/build/obj
INSTALLPATH = /boot/RadiOS

vpath %.ah $(INCLPATH)
vpath %.rdm $(OUTPATH)
vpath %.rdl $(OUTPATH)
vpath %.bin $(OUTPATH)

# Commands
AS = nasm -w+orphan-labels -f rdf
CC = rncc
LD = ldrdf
AR = rdflib

# Command flags
ifdef DEBUG
 ASFLAGS = -DDEBUG -I$(INCLPATH)/ -Pmacros/sugar.ah -s -o
 CFLAGS = -N -I$(INCLPATH)/c -c -DDEBUG -g
else
 ASFLAGS = -I$(INCLPATH)/ -Pmacros/sugar.ah -s -o
 CFLAGS = -N -I$(INCLPATH)/c -c
endif
LDFLAGS = -2 -xe -s -j $(OUTPATH)/ -L $(OUTPATH)/

# Command to generate dependencies file
GENDEPS = ndepgen -M -pmacros/sugar.ah
