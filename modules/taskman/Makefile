################################################################################
# Makefile for taskman.
# Copyright (c) 2002 RET & COM Research.
################################################################################

include ../../build/header.mk

# Variables
modnamesfile = .taskman-modules
SUBDIRS = mem path proc
export TARGET_LIB = taskman.$(L)
TARGET_RDM = taskman.$(X)
OBJS = taskmaninit.$(O)
LIBS = $(TARGET_LIB)

# Rules for subdirectories
LINK = all
include ../../build/subdirs.mk

# Build module
include ../../build/module.mk

# Individual rules
install:
	install $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/modules
