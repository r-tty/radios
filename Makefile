#*******************************************************************************
#  Makefile - RadiOS makefile (GNU make, Unix)
#*******************************************************************************

include build/header.mk

# Some boolean definitions
export DEBUG = 1

# Subdirs
SUBDIRS = kernel init btl monitor

# Kernel objects and libraries
OBJS = init.$(O)
LIBS = kernel.$(L) monitor.$(L)

LDLIBS = $(addprefix -l,$(LIBS))

# Kernel file name
KERNEL_RDM = rmk586.$(M)

# "Trampoline" file - will be embedded into a kernel header
TRAMPOLINE = $(OBJPATH)/mb_tramp.bin

# Dependency file
depfile = .depend

#--- Target kernel module ------------------------------------------------------

all: $(depfile) $(KERNEL_RDM)

-include $(depfile)

ifdef deps_generated

$(KERNEL_RDM): subdirs $(TRAMPOLINE)
	@echo "Linking kernel..."
	@$(LD) $(LDFLAGS) -xe -o $(KERNEL_RDM) -g $(TRAMPOLINE) $(OBJS) $(LDLIBS)
	@cat $(OBJPATH)/btl.bin >>$(KERNEL_RDM)

.PHONY: modules subdirs $(SUBDIRS)

modules:
	@$(MAKE) -s -C modules

subdirs: $(SUBDIRS) 

$(SUBDIRS):
	@$(MAKE) -s -C $@


endif



#--- Install kernel and modules -------------------------------------------------

install: $(KERNEL_RDM)
	@echo "Installing kernel..."
	@gzip -c $(KERNEL_RDM) >$(INSTALLPATH)/$(KERNEL_RDM).gz

modules_install:
	@$(MAKE) -s -C modules install


#--- Individual dependencies ---------------------------------------------------

$(TRAMPOLINE): etc/mb_tramp.nasm
	@echo "Assembling $<"
	@nasm -f bin $(ASFLAGS) -o $@ $<

#--- Recursive depends ---------------------------------------------------------

dep:
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) kernel/version.nasm >>$(depfile)
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir all-dep ; done
	@$(MAKE) -s -C modules all-dep


#--- Clean ---------------------------------------------------------------------
.PHONY: clean distclean release
clean:
	@rm -f $(KERNEL_RDM)
	@cd $(OBJPATH) && rm -f *.$(O) *.$(M) *.$(X) *.$(B)
	@rm -f $(LIBPATH)/*.$(L)

distclean: clean
	@rm -f $(response_file) $(depfile)
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir all-clean ; done
	@$(MAKE) -s -C modules all-clean

#--- Release -------------------------------------------------------------------

release:
	@rm -f build/header.mk
	@echo -n "Making release file: "
	@release_file=radios-`grep ^RadiOS_Version kernel/version.nasm | awk '{ print $$3 }' | sed 's/\"//g'`.tar.gz ; \
	   echo $$release_file; tar -czf $$release_file *

#-------------------------------------------------------------------------------
