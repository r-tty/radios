################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../etc/header.mk

# Change variables here
export TARGET_LIB = kernel.rdl
OBJS = kernel.rdm module.rdm initmem.rdm pages.rdm \
       pool.rdm sema.rdm setjmp.rdm time.rdm
modnamesfile = $(OUTPATH)/.kernel-modules
SUBDIRS = mm mt syscall ipc x86dev

# Make in subdirs
include ../etc/subdirs.mk

# This part shouldn't be changed
include ../etc/common.mk
