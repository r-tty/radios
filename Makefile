#*******************************************************************************
#  Makefile - RadiOS makefile (GNU make, Unix)
#*******************************************************************************

include etc/header.mk

# Some boolean definitions
export DEBUG = 1
MULTIBOOT = 1

# Subdirs
SUBDIRS = kernel drivers/hard drivers/soft fs monitor init loader

# Kernel objects and libraries
TARGET_DEP = version.rdm syscall.rdm kernel.rdl hardware.rdl softdrivers.rdl \
             monitor.rdl init.rdm
ifdef DEBUG
TARGET_DEP += rkdt.rdm
endif

# Boot-time modules
BOOTMODULES = mouse.rdm

# Kernel file name
KERNEL_RDX = main.rdx

# Dependency file
depfile = .depend

# "Response" file for linker
response_file = .link

#--- Target kernel module ------------------------------------------------------

all: .depend $(KERNEL_RDX)

-include $(depfile)

ifdef deps_generated

$(KERNEL_RDX): $(response_file) version.rdm rkdt.rdm dummy
	@for dir in $(SUBDIRS) ; do (cd $$dir; $(MAKE) || break) ; done
	@echo "Linking kernel..."
	@$(LD) $(LDFLAGS) -@ $(response_file)
ifdef MULTIBOOT
	@echo -n "Building multiboot kernel..."
	@cat $(OUTPATH)/loader.bin >>$(KERNEL_RDX)
	@gzip -c $(KERNEL_RDX) >$(INSTALLPATH)/sys/radios.rdz
	@echo "done."
endif

endif

dummy:

#--- Boot-time modules ---------------------------------------------------------

modules-install: $(BOOTMODULES)
	@echo -n "Installing modules: "
	@for m in $(BOOTMODULES) ; do \
		gzip -c $(OUTPATH)/$$m >$(INSTALLPATH)/sys/$$m.gz ; \
		echo $$m " " ; \
	 done

#--- Individual dependencies ---------------------------------------------------

version.rdm: etc/version.as
	$(AS) $(ASFLAGS) $(OUTPATH)/version.rdm etc/version.as
	
rkdt.rdm: etc/rkdt/rkdt.as
	$(AS) $(ASFLAGS) $(OUTPATH)/rkdt.rdm etc/rkdt/rkdt.as


#--- Recursive depends ---------------------------------------------------------

dep:
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) etc/version.as >>$(depfile)
	@$(GENDEPS) etc/rkdt/rkdt.as >>$(depfile)
	@for dir in $(SUBDIRS) ; do (cd $$dir; $(MAKE) all-depends) ; done

	
#--- Response file -------------------------------------------------------------
	
$(response_file): Makefile
	rm -f $(response_file)
	@for m in $(TARGET_DEP) ; do echo $$m | sed 's/^.*\.rdl/-l&/' >>$(response_file) ; done


#--- Clean ---------------------------------------------------------------------

clean:
	@for dir in $(SUBDIRS) ; do (cd $$dir; $(MAKE) all-clean) ; done
	@rm -f $(response_file) $(depfile) $(KERNEL_RDX)
	@cd $(OUTPATH) && rm -f version.rdm rkdt.rdm

	
#--- Release -------------------------------------------------------------------

release:
	@rm -f etc/header.mk
	@echo -n "Making release file: "
	@release_file=radios-`grep DB etc/version.as | awk '{ print $$3 }' | sed 's/\"//g'`.tar.gz ; \
	   echo $$release_file; tar -czf $$release_file *

#-------------------------------------------------------------------------------
