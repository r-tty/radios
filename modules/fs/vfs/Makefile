################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2003 RET & COM Research.
################################################################################

# This must be defined first
group = vfs

# Standard header
include ../../Build/header.mk

# Change variables here
export TARGET_LIB = fs.$(L)
OBJS = buffer.$(O) inode.$(O) open.$(O) rw.$(O) path.$(O)
SUBDIRS = rfs

# Make in subdirs
include ../../Build/subdirs.mk

# This part shouldn't be changed
include ../../Build/common.mk
