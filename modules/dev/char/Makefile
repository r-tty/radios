################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2003 RET & COM Research.
################################################################################

# This must be defined first
group = dev
subgroup = _char

# Standard header
include ../../../Build/header.mk

# Change variables here
SUBDIRS = console
OBJS = parport.$(O)

# Build in subdirectories
BUILD = all
include ../../../Build/subdirs.mk

# Build objects
include ../../../Build/common.mk

# Install modules
install:
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir install ; done
