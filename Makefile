#*******************************************************************************
#  Makefile - RadiOS makefile (GNU make, Unix)
#*******************************************************************************

include build/header.mk

# Some boolean definitions
export DEBUG = 1

# Subdirs
SUBDIRS = kernel init loader
ifdef DEBUG
    SUBDIRS += monitor
endif

# Kernel objects and libraries
TARGET_DEP = syscall.rdm init.rdm kernel.rdl
ifdef DEBUG
    TARGET_DEP += monitor.rdl
endif

# Boot-time modules
BOOTMODULES = startup.rdl

# Kernel file name
KERNEL_RDX = rmk386.rdx

# Dependency file
depfile = .depend

# "Response" file for linker
response_file = .link

#--- Target kernel module ------------------------------------------------------

all: $(depfile) $(KERNEL_RDX)

-include $(depfile)

ifdef deps_generated

$(KERNEL_RDX): subdirs $(response_file) mb_tramp.bin
	@echo -n "Linking kernel..."
	@$(LD) $(LDFLAGS) -o $(KERNEL_RDX) -g $(OUTPATH)/mb_tramp.bin -@ $(response_file)
	@cat $(OUTPATH)/loader.bin >>$(KERNEL_RDX)
	@echo "done."

modules: $(BOOTMODULES)

$(BOOTMODULES):
	@$(MAKE) -C modules

.PHONY: subdirs $(SUBDIRS)

subdirs: $(SUBDIRS) 

$(SUBDIRS):
	@$(MAKE) -C $@
	

endif



#--- Install kernel and modules -------------------------------------------------

install: $(KERNEL_RDX)
	@echo "Installing kernel..."
	@gzip -c $(KERNEL_RDX) >$(INSTALLPATH)/radios.rdz

modules_install: $(BOOTMODULES)
	@echo -n "Installing modules: "
	@for m in $(BOOTMODULES) ; do \
		gzip -c $(OUTPATH)/$$m >$(INSTALLPATH)/$$m.gz ; \
		echo -n $$m " " ; \
	 done
	@echo

#--- Individual dependencies ---------------------------------------------------

mb_tramp.bin: etc/mb_tramp.nasm
	@echo "Assembling $<"
	@nasm -f bin $(ASFLAGS) $(OUTPATH)/mb_tramp.bin etc/mb_tramp.nasm

#--- Recursive depends ---------------------------------------------------------

dep:
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) kernel/version.nasm >>$(depfile)
	@for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir all-dep ; done
	@$(MAKE) -C modules all-dep

	
#--- Response file -------------------------------------------------------------

$(response_file): Makefile
	@rm -f $(response_file)
	@for m in $(TARGET_DEP) ; do echo $$m | sed 's/^.*\.rdl/-l&/' >>$(response_file) ; done


#--- Clean ---------------------------------------------------------------------
.PHONY: clean distclean release
clean:
	@rm -f $(KERNEL_RDX)
	@cd $(OUTPATH) && rm -f *.rdm *.rdl *.bin

distclean: clean
	@rm -f $(response_file) $(depfile)
	@for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir all-clean ; done
	@$(MAKE) -C modules all-clean

#--- Release -------------------------------------------------------------------

release:
	@rm -f etc/header.mk
	@echo -n "Making release file: "
	@release_file=radios-`grep ^RadiOS_Version kernel/version.nasm | awk '{ print $$3 }' | sed 's/\"//g'`.tar.gz ; \
	   echo $$release_file; tar -czf $$release_file *

#-------------------------------------------------------------------------------
