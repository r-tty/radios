################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# Change variables here
OBJS = monitor.$(O) opcodes.$(O) operands.$(O)
TARGET_LIB = monitor.$(L)
modnamesfile = .monitor-modules

# This part shouldn't be changed
include ../build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
