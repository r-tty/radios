################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2003 RET & COM Research.
################################################################################

# This must be defined first
group = kernel
subgroup = _ipc

# Standard header
include ../../Build/header.mk

# Change variables here
OBJS = msg.$(O) channel.$(O) connection.$(O)

# This part shouldn't be changed
include ../../Build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
