################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# This must be defined first
group = librm

# Standard header
include ../../Build/header.mk

# Change variables here
TARGET_RDM = librm.$(M)
OBJS = head.$(O) rmhelper.$(O) iomh.$(O)

# This part shouldn't be changed
include ../../Build/module.mk

# Individual rules
install:
	cp $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/lib

# Individual dependencies
all-dep: dep
all-clean: clean
