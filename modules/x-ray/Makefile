################################################################################
# Makefile for x-ray.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# This must be defined first
group = xray

# Global definitions
include ../../Build/header.mk

# Variables
TARGET = x-ray.$(X)
OBJS = x-ray.$(O) hash.$(O) util.$(O)
C_SOURCE = 1

# Build program
include ../../Build/prog.mk

# Individual rules
install:
	install $(OBJPATH)/$(TARGET) $(INSTALLPATH)/sys

all-dep: dep
all-clean: clean
