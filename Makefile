#*******************************************************************************
#  Makefile - RadiOS makefile (GNU make, Unix)
#*******************************************************************************

include etc/header.mk

# Some boolean definitions
DEBUG = 1
MULTIBOOT = 1

# Subdirs
SUBDIRS = kernel drivers/hard drivers/soft fs monitor init loader

# Modules
TARGET_DEP = version.rdm kernel.rdl hardware.rdl softdrivers.rdl \
             fs.rdl monitor.rdl init.rdm
ifdef DEBUG
TARGET_DEP += rkdt.rdm
endif

# "Response" file for linker
response_file = .link

#--- Target kernel module ------------------------------------------------------

-include .depend

ifdef deps_generated

main.rdx: $(response_file) version.rdm rkdt.rdm dummy
	@for dir in $(SUBDIRS) ; do (cd $$dir; $(MAKE)) ; done
	@echo "Linking kernel..."
	@$(LD) $(LDFLAGS) -@ $(response_file)
ifdef MULTIBOOT
	@echo -n "Building multiboot kernel..."
	@cat $(OUTPATH)/loader.bin >>main.rdx
	@gzip -c main.rdx >$(INSTALLPATH)/sys/radios.rdz
	@echo "done."
endif

else
nodeps:
	@echo 'No dependencies. Please run "gmake dep"'
endif

dummy:

#--- Individual dependencies ---------------------------------------------------

version.rdm: etc/version.as
	@$(AS) $(ASFLAGS) $(OUTPATH)/version.rdm etc/version.as
	
rkdt.rdm: etc/rkdt/rkdt.as
	@$(AS) $(ASFLAGS) $(OUTPATH)/rkdt.rdm etc/rkdt/rkdt.as


#--- Recursive depends ---------------------------------------------------------

dep:
	@echo "deps_generated = TRUE" >.depend
	@for dir in $(SUBDIRS) ; do (cd $$dir; $(MAKE) all-depends) ; done

	
#--- Response file -------------------------------------------------------------
	
$(response_file): Makefile
	rm -f $(response_file)
	@for m in $(TARGET_DEP) ; do echo $$m | sed 's/^.*\.rdl/-l&/' >>$(response_file) ; done


#--- Clean ---------------------------------------------------------------------

clean:
	@for dir in $(SUBDIRS) ; do (cd $$dir; $(MAKE) all-clean) ; done
	@rm -f $(response_file) .depend main.rdx
	@cd $(OUTPATH) && rm -f version.rdm rkdt.rdm

	
#--- Release -------------------------------------------------------------------

release:
	@rm -f etc/header.mk
	@echo -n "Making release file: "
	@release_file=radios-`grep DB etc/version.as | awk '{ print $$3 }' | sed 's/\"//g'`.tar.gz ; \
	   echo $$release_file; tar -czf $$release_file *

#-------------------------------------------------------------------------------
