################################################################################
# Makefile for x-ray.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# This must be defined first
group = xray

# Global definitions
include ../../Build/header.mk

# Variables
TARGET_RDM = x-ray.$(X)
OBJS = x-ray.$(O) cons.$(O)

# Build module
include ../../Build/module.mk

# Individual rules
install:
	install $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/sys

all-dep: dep
all-clean: clean
