################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../etc/header.mk

# Change variables here
export TARGET_LIB = fs.rdl
OBJS = buffer.rdm inode.rdm open.rdm rw.rdm path.rdm cfs_init.rdm
modnamesfile = .fs-modules
SUBDIRS = vstafs tarfs

# Make in subdirs
include ../etc/subdirs.mk

# This part shouldn't be changed
include ../etc/common.mk
