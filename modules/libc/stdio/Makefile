################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# This must be defined first
group = libc
subgroup = _stdio

# Standard header
include ../../../Build/header.mk

# Change variables here
C_SOURCE = 1
OBJS = fgets.$(O) flock.$(O)

# This part shouldn't be changed
include ../../../Build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
