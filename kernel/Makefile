################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# Change variables here
OBJS = kernel.rdm module.rdm rdoff.rdm initmem.rdm pages.rdm \
       pool.rdm sema.rdm setjmp.rdm time.rdm strutil.rdm version.rdm
modnamesfile = .kernel-modules
staticlib = kernel.rdl
SUBDIRS = mm mt syscall ipc x86dev

# Make in subdirs
include ../build/subdirs.mk

# This part shouldn't be changed
include ../build/common.mk
