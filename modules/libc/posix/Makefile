################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2003 RET & COM Research.
################################################################################

# This must be defined first
group = libc
subgroup = _posix

# Standard header
include ../../../Build/header.mk

# Change variables here
OBJS = 1.$(O) 1_proc.$(O) 1_signal.$(O) 1_termios.$(O) 1_iodir.$(O) \
       1a.$(O) 1b.$(O) 1c.$(O) 1j.$(O)

# This part shouldn't be changed
include ../../../Build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
