################################################################################
# Makefile for device drivers.
# Copyright (c) 2002 RET & COM Research.
################################################################################

# Standard header
include ../../build/header.mk

# Change variables here
export TARGET_LIB = hardware.rdl
OBJS = vtx.$(O) keyboard.$(O) \
       hd.$(O) ide.$(O) fd.$(O) \
       serport.$(O) parport.$(O) bios32.$(O) vgagr.$(O) mouse.$(O)
modnamesfile = .hardware-modules
SUBDIRS = bus net audio

# Make in subdirs
LINK = all
include ../../build/subdirs.mk

# This part shouldn't be changed
include ../../build/common.mk
