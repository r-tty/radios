################################################################################
# Makefile for libc.
# Copyright (c) 2002 RET & COM Research.
################################################################################

include ../../build/header.mk

# Variables
modnamesfile = .libc-modules
SUBDIRS = misc signal stdio stdlib string termios unistd
export TARGET_LIB = libc.$(L)
TARGET_RDM = libc.$(M)
OBJS = libcinit.$(O)
LIBS = $(TARGET_LIB)

# Rules for subdirectories
LINK = all
include ../../build/subdirs.mk

# For linking the module
include ../../build/module.mk

# Individual rules
install:
	install $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/modules

all:
