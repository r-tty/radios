################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2003 RET & COM Research.
################################################################################

# This must be defined first
group = taskman
subgroup = _path

# Global definitions
include ../../../Build/header.mk

# Change variables here
OBJS = pathman.$(O) ramdisk.$(O) bam.$(O) btree.$(O) \
       rfs_super.$(O) rfs_dirops.$(O) rfs_fileops.$(O)

# This part shouldn't be changed
include ../../../Build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean