################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# Converter to flat binary
CONV = rdf2bin -o 0x100000 -b 4096 -p 1

# Change variables here
LOADER_BIN = $(OBJPATH)/loader.bin
OBJS = loader.rdm

# Additional rule
loader.bin: .depend $(OBJS)
	@$(CONV) $(OBJPATH)/$(OBJS) $(LOADER_BIN)

# This part shouldn't be changed
include ../build/common.mk

# Individual dependencies
all-dep: dep

all-clean: clean
	@rm -f $(LOADER_BIN)
