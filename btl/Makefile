################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2003 RET & COM Research.
################################################################################

# This must be defined first
group = btl

# Standard header
include ../Build/header.mk

# Converter to flat binary
CONV = rdf2bin -o 0x100000 -p 1

# Change variables here
TARGET_RDM = btl.$(M)
BIN = btl.$(B)
OBJS = btlstartup.$(O) btlcons.$(O) btl.$(O) printf.$(O) string.$(O)
SRCS = btlstartup.nasm btlcons.nasm btl.c printf.c string.nasm

# Additional rules
$(BIN): $(TARGET_RDM)
	@$(CONV) $(OBJPATH)/$< $(OBJPATH)/$@

# Build module
include ../Build/module.mk

# Individual dependencies
all-dep: dep

all-clean: clean
	@cd $(OBJPATH) && rm -f $(TARGET_RDM) $(BIN)
