################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# Change variables here
OBJS = kernel.$(O) initmem.$(O) pages.$(O) pool.$(O) sema.$(O) setjmp.$(O) \
       time.$(O) strutil.$(O) version.$(O)
export TARGET_LIB = kernel.rdl
modnamesfile = .kernel-modules
SUBDIRS = mt syscall ipc x86dev

# Make in subdirs
BUILD = all
include ../build/subdirs.mk

# This part shouldn't be changed
include ../build/common.mk
