################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../../build/header.mk

# Change variables here
OBJS = coff.$(O) elf.$(O)
modnamesfile = .binfmt-modules
BLMS = binfmt_coff.rdd binfmt_elf.rdd

all-make: $(SUBDIRS) $(BLMS)

binfmt_coff.rdd: coff.$(O)
	@echo "Linking $@"
	@$(LD) $(LDFLAGS) -g $(OBJPATH)/bmtagdrv.bin -o $(LIBPATH)/$@ $(<F)

binfmt_elf.rdd: elf.$(O)
	@echo "Linking $@"
	@$(LD) $(LDFLAGS) -g $(OBJPATH)/bmtagdrv.bin -o $(LIBPATH)/$@ $(<F)

# This part shouldn't be changed
include ../../build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
