################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../etc/header.mk

# Change variables here
export TARGET_LIB = kernel.rdl
OBJS = kernel.rdm kheap.rdm driver.rdm module.rdm paging.rdm \
       pool.rdm sema.rdm misc.rdm setjmp.rdm
modnamesfile = $(OUTPATH)/.kernel-modules
SUBDIRS = mm mt syscall

# Make in subdirs
include ../etc/subdirs.mk

# This part shouldn't be changed
include ../etc/common.mk
