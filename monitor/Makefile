################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../etc/header.mk

# Change variables here
TARGET_LIB = monitor.rdl
OBJS = monitor.rdm opcodes.rdm operands.rdm
modnamesfile = $(OUTPATH)/.monitor-modules

# This part shouldn't be changed
include ../etc/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
