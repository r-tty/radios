################################################################################
# Makefile for libc.
# Copyright (c) 2002 RET & COM Research.
################################################################################

include ../../build/header.mk

# Variables
staticlib = libc.rdl
SUBDIRS = misc signal stdio stdlib string termios unistd
BLM = libc.rdo
OBJS = libcinit.rdm

# Individual rules

srcfiles = $(patsubst %.rdm,%.nasm,$(OBJS))
depfile = .depend

all-make: $(SUBDIRS) $(BLM)

$(BLM): $(OBJS) $(staticlib)
	$(LD) $(LDFLAGS) -o $(LIBPATH)/$(BLM) $(OBJS) -l$(staticlib)

$(srcfiles): $(depfile)

-include $(depfile)

# Generate dependencies file
dep:
	@echo "Generating makefile dependencies..."
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) $(srcfiles) >>$(depfile)

ifdef TARGET_LIB
all: $(TARGET_LIB)
$(TARGET_LIB): $(BLM) $(LIB_UPDATE)
	@if [ -f $(LIBPATH)/$(TARGET_LIB) ] ; then \
	  echo "Updating library $(TARGET_LIB)" ; \
	 else \
	  echo "Creating library $(TARGET_LIB)" ; \
	  $(AR) c $(LIBPATH)/$(TARGET_LIB) ; fi
	@cd $(OBJPATH); $(AR) r $(LIBPATH)/$(TARGET_LIB) libc $(BLM)

lib-update:
else
all:
endif

clean:
	@echo "Cleaning up..."
	@cd $(OBJPATH) && rm -f $(OBJS)
	@cd $(LIBPATH) && rm -f $(BLM)

# Common standard rules
include ../../build/subdirs.mk
