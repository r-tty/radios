################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# Change variables here
export TARGET_LIB = startup.rdl
OBJS = ramdisk.rdm
modnamesfile = $(OUTPATH)/.startup-modules
SUBDIRS = binfmt

# Make in subdirs
include ../build/subdirs.mk

# This part shouldn't be changed
include ../build/common.mk
