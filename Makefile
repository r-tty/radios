#*******************************************************************************
#  Makefile - RadiOS makefile (GNU make, Unix)
#*******************************************************************************

include etc/header.mk

# Some boolean definitions
export DEBUG = 1

# Subdirs
SUBDIRS = kernel init loader
ifdef DEBUG
    SUBDIRS += monitor
endif

# Kernel objects and libraries
TARGET_DEP = syscall.rdm version.rdm init.rdm kernel.rdl
ifdef DEBUG
    TARGET_DEP += monitor.rdl
endif

# Boot-time modules
BOOTMODULES = devices.rdl syslibs.rdl

# Kernel file name
KERNEL_RDX = main.rdx

# Dependency file
depfile = .depend

# "Response" file for linker
response_file = .link

#--- Target kernel module ------------------------------------------------------

all: $(depfile) $(KERNEL_RDX)

-include $(depfile)

ifdef deps_generated

$(KERNEL_RDX): subdirs $(response_file) version.rdm
	@echo "Linking kernel..."
	@$(LD) $(LDFLAGS) -@ $(response_file)
	@echo -n "Building multiboot kernel..."
	@cat $(OUTPATH)/loader.bin >>$(KERNEL_RDX)
	@gzip -c $(KERNEL_RDX) >$(INSTALLPATH)/radios.rdz
	@echo "done."

.PHONY: subdirs $(SUBDIRS)

subdirs: $(SUBDIRS) 

$(SUBDIRS):
	@$(MAKE) -C $@

endif



#--- Boot-time modules ---------------------------------------------------------

modules-install: $(BOOTMODULES)
	@echo -n "Installing modules: "
	@for m in $(BOOTMODULES) ; do \
		gzip -c $(OUTPATH)/$$m >$(INSTALLPATH)/sys/$$m.gz ; \
		echo $$m " " ; \
	 done

#--- Individual dependencies ---------------------------------------------------

version.rdm: kernel/version.nasm
	@echo "Assembling $<"
	@$(AS) $(ASFLAGS) $(OUTPATH)/version.rdm kernel/version.nasm
	

#--- Recursive depends ---------------------------------------------------------

dep:
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) kernel/version.nasm >>$(depfile)
	@for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir all-dep ; done

	
#--- Response file -------------------------------------------------------------

$(response_file): Makefile
	@rm -f $(response_file)
	@for m in $(TARGET_DEP) ; do echo $$m | sed 's/^.*\.rdl/-l&/' >>$(response_file) ; done


#--- Clean ---------------------------------------------------------------------
.PHONY: clean distclean release
clean:
	@rm -f $(KERNEL_RDX)
	@cd $(OUTPATH) && rm -f *.rdm *.rdl *.rdz

distclean: clean
	@rm -f $(response_file) $(depfile)
	@for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir all-clean ; done

#--- Release -------------------------------------------------------------------

release:
	@rm -f etc/header.mk
	@echo -n "Making release file: "
	@release_file=radios-`grep ^RadiOS_Version kernel/version.nasm | awk '{ print $$3 }' | sed 's/\"//g'`.tar.gz ; \
	   echo $$release_file; tar -czf $$release_file *

#-------------------------------------------------------------------------------
