################################################################################
# Makefile for x-ray.
# Copyright (c) 2002 RET & COM Research.
################################################################################

include ../../build/header.mk

# Variables
modnamesfile = .xray-modules
TARGET_RDM = x-ray.$(X)
OBJS = x-ray.$(O)

# Rules for subdirectories
LINK = all
include ../../build/subdirs.mk

# Build module
include ../../build/module.mk

# Individual rules
install:
	install $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/modules
