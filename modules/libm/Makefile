################################################################################
# Makefile for x-ray.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# This must be defined first
group = libm

# Global definitions
include ../../Build/header.mk

# Variables
TARGET_RDM = libm.$(M)
OBJS = i387.$(O)

# Build module
include ../../Build/module.mk

# Individual rules
install:
	cp $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/lib

all-dep: dep
all-clean: clean
