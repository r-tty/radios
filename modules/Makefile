################################################################################
# Makefile - universal makefile for RadiOS.
# Copyright (c) 2000 RET & COM Research.
################################################################################

# Standard header
include ../build/header.mk

# File that contains command line arguments for boot modules
ARGSFILE = args.default

# Change variables here
staticlib = startup.rdl
SUBDIRS = libc taskman binfmt

# Common rules
include ../build/subdirs.mk

# Individual rules
all: $(staticlib)

$(staticlib): $(ARGSFILE)
	@rm -f $(LIBPATH)/$(staticlib)
	@echo "Creating boot-time modules library..."
	$(AR) c $(LIBPATH)/$(staticlib)
#	$(AR) a $(LIBPATH)/$(staticlib) $(ARGSFILE) .args

clean:
	@echo "Cleaning up..."
	@cd $(LIBPATH) && rm -f $(staticlib)

dep:

# Install modules
install: $(staticlib)
	@echo -n "Installing modules... "
	@gzip -c $(LIBPATH)/$(staticlib) >$(INSTALLPATH)/$(staticlib).gz
	@echo "done."
