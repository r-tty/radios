################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# Verbose initialization
ASFLAGS += -DVERBOSE

# Change variables here
OBJS = init.$(O)
modnamesfile = .init-modules

# This part shouldn't be changed
include ../build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
