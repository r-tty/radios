################################################################################
# Makefile for device drivers.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# Standard header
include ../../Build/header.mk

# Change variables here
SUBDIRS = char

# Build in subdirs
include ../../Build/subdirs.mk

# Install modules
install:
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir install ; done

# Just stubs
all:
dep:
clean:
