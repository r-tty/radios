################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# Change variables here
export TARGET_LIB = kernel.rdl
OBJS = kernel.rdm module.rdm rdoff.rdm initmem.rdm pages.rdm \
       pool.rdm sema.rdm setjmp.rdm time.rdm version.rdm
modnamesfile = $(OUTPATH)/.kernel-modules
SUBDIRS = mm mt syscall ipc x86dev

# Make in subdirs
include ../build/subdirs.mk

# This part shouldn't be changed
include ../build/common.mk
