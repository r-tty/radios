################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../etc/header.mk

# Change variables here
export TARGET_LIB = softdrivers.rdl
OBJS = console.rdm ramdisk.rdm
modnamesfile = $(OUTPATH)/.softdrivers-modules
SUBDIRS = binfmt

# Make in subdirs
include ../etc/subdirs.mk

# This part shouldn't be changed
include ../etc/common.mk
