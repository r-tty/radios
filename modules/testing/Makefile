################################################################################
# Makefile for x-ray.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# This must be defined first
group = tester

# Global definitions
include ../../Build/header.mk

# Variables
TARGET_RDM = tester.$(X)
OBJS = tester.$(O)

# Build module
include ../../Build/module.mk

# Individual rules
install:
	install $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/sys

all-dep: dep
all-clean: clean
