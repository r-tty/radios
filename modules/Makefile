################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# Change variables here
SUBDIRS = libc taskman

# Build in subdirs
include ../build/subdirs.mk

# Install modules
install: all-make
	@echo "Installing modules... "
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir install ; done

# Just stubs
all:
dep:
clean:
