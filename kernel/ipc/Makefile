################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# This must be defined first
group = kernel
subgroup = _ipc

# Standard header
include ../../Build/header.mk

# Change variables here
OBJS = ipc.$(O) msg.$(O) channel.$(O) event.$(O)

# This part shouldn't be changed
include ../../Build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
