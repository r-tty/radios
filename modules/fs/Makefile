################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../etc/header.mk

# Change variables here
export TARGET_LIB = fs.rdl
OBJS = buffer.$(O) inode.$(O) open.$(O) rw.$(O) path.$(O) cfs_init.$(O)
modnamesfile = .fs-modules
SUBDIRS = vstafs tarfs

# Make in subdirs
include ../etc/subdirs.mk

# This part shouldn't be changed
include ../etc/common.mk
