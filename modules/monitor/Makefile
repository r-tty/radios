################################################################################
# Makefile for taskman.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# This must be defined first
group = monitor

# Global definitions
include ../../Build/header.mk

# Variables
TARGET_RDM = monitor.$(M)
OBJS = monitor.$(O) cons.$(O) opcodes.$(O) operands.$(O)

# Build module
include ../../Build/module.mk

# Individual rules
install:
	cp $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/boot

all-dep: dep
all-clean: clean
