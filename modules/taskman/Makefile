################################################################################
# Makefile for taskman.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# This must be defined first
group = taskman

# Global definitions
include ../../Build/header.mk

# Variables
SUBDIRS = ring0 main mem path proc module
export TARGET_LIB = taskman.$(L)
TARGET_RDM = taskman.$(M)
OBJS = tm_head.$(O)
LIBS = $(TARGET_LIB)

# Rules for subdirectories
LINK = all
include ../../Build/subdirs.mk

# Build module
include ../../Build/module.mk

# Individual rules
install:
	cp $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/boot
