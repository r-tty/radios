################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# This must be defined first
group = dev
subgroup = _block

# Standard header
include ../../../Build/header.mk

# Change variables here
TARGET_RDM = eide.$(X)
OBJS = ide.$(O) hd.$(O)


# Build module
LINK = all
include ../../../Build/module.mk

# Individual rules
install:
	install $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/sys

all-dep: dep
all-clean: clean
