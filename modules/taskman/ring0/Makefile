################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# This must be defined first
group = taskman
subgroup = _ring0

# Global definitions
include ../../../Build/header.mk

# Change variables here
OBJS = ring0init.$(O) thread.$(O) timers.$(O) signal.$(O)

# This part shouldn't be changed
include ../../../Build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
