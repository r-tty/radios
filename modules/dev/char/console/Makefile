################################################################################
# Makefile for console server.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# This must be defined first
group = dev
subgroup = _char_console

# Global definitions
include ../../../../Build/header.mk

# Variables
TARGET_RDM = console.$(X)
OBJS = console.$(O) vtx.$(O) kbc.$(O) keyboard.$(O)

# Build module
LINK = all
include ../../../../Build/module.mk

# Individual rules
install:
	install $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/sys

all-dep: dep
all-clean: clean
