################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# This must be defined first
group = binfmt

# Standard header
include ../../Build/header.mk

# Change variables here
OBJS = coff.$(O) elf.$(O)
BINFMTS = binfmt_coff.$(M) binfmt_elf.$(M)

all-make: $(SUBDIRS) $(BINFMTS)

binfmt_coff.$(M): coff.$(O)
	@echo "Linking $@"
	@$(LD) $(LDFLAGS) -o $(LIBPATH)/$@ $(<F)

binfmt_elf.$(M): elf.$(O)
	@echo "Linking $@"
	@$(LD) $(LDFLAGS) -o $(LIBPATH)/$@ $(<F)

# This part shouldn't be changed
include ../../Build/common.mk

# Individual dependencies
all-dep: dep
all-clean: clean
