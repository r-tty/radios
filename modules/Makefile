################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../Build/header.mk

# Change variables here
SUBDIRS = monitor libc libm librm taskman dev #x-ray

# Build in subdirs
include ../Build/subdirs.mk

# Install modules
install: all-make
	@echo "Installing modules... "
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir install ; done

# Just stubs
all:
dep:
clean:
