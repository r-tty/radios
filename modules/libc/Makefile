################################################################################
# Makefile for libc.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# This must be defined first
group = libc

include ../../Build/header.mk

# Variables
SUBDIRS = Posix_1j misc signal stdio stdlib string termios unistd xopen
export TARGET_LIB = libc.$(L)
TARGET_RDM = libc.$(M)
OBJS = libcinit.$(O)
LIBS = $(TARGET_LIB)
RTOBJS = rtinit.$(O) rtexit.$(O)

# Rules for subdirectories
LINK = all
include ../../Build/subdirs.mk

# For linking the module
include ../../Build/module.mk

# Individual rules
install: $(RTOBJS)
	cp $(OBJPATH)/$(TARGET_RDM) $(INSTALLPATH)/lib
	cd $(OBJPATH) && cp $(RTOBJS) $(INSTALLPATH)/usr/lib
