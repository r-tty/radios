################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../../etc/header.mk

# Change variables here
export TARGET_LIB = hardware.rdl
OBJS = onboard.rdm vtx.rdm keyboard.rdm \
       hd.rdm ide.rdm fd.rdm \
       serport.rdm parport.rdm bios32.rdm vgagr.rdm mouse.rdm
modnamesfile = $(OUTPATH)/.hardware-modules
SUBDIRS = bus net audio

# Make in subdirs
include ../../etc/subdirs.mk

# This part shouldn't be changed
include ../../etc/common.mk
