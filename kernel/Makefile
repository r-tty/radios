################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2003 RET & COM Research.
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
OBJS = startup.$(O) tssgdt.$(O) interrupt.$(O) exception.$(O) pages.$(O) \
       mem.$(O) hashtable.$(O) misc.$(O) pool.$(O) setjmp.$(O) \
       syscall.$(O) sync_kern.$(O) sync_user.$(O) tmif.$(O) \
       time.$(O) kcons.$(O) strutil.$(O)
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
