################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# This must be defined first
group = kernel

# Standard header
include ../Build/header.mk

# File containing a multiboot header and "trampoline" code
TRAMPOLINE = $(OBJPATH)/mb_tramp.bin
extraclean = $(TRAMPOLINE)

# Definitions
export TARGET_LIB = kernel.$(L)
OBJS = startup.$(O) initmem.$(O) misc.$(O) pages.$(O) pool.$(O) sync.$(O) \
       setjmp.$(O) time.$(O) syscall.$(O) tmif.$(O) strutil.$(O) version.$(O)
LIBS = $(TARGET_LIB)
TARGET_RDM = kernel.$(M)
SUBDIRS = mt ipc x86dev

# Make in subdirs
LINK = $(TRAMPOLINE) all
include ../Build/subdirs.mk

# To embed a multiboot header into the kernel
LDFLAGS += -g $(TRAMPOLINE)
ifdef LINKMONITOR
 EXTRAOBJS += $(OBJTOP)/monitor/monitor.$(M)
endif

# For building the objects and linking target module
include ../Build/module.mk

# Rule to build trampoline
$(TRAMPOLINE): mb_tramp.nasm
	@echo "Assembling $<"
	@nasm -f bin $(ASFLAGS) -o $@ $<
