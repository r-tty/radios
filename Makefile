#*******************************************************************************
# Makefile for building everything.
#*******************************************************************************

include Build/header.mk

# Some boolean definitions
# To turn various debugging messages on
export DEBUG = 1
# To link monitor with a kernel
#export LINKMONITOR = 1

# Subdirs
SUBDIRS = kernel btl

# Kernel file name
RMK =  rmk586.$(M)

#--- Targets -------------------------------------------------------------------

all: $(RMK)

$(RMK): subdirs
	@echo "Appending BTL..."
	@cat $(OBJTOP)/kernel/kernel.$(M) $(OBJTOP)/btl/btl.$(B) >$(RMK)

.PHONY: modules subdirs $(SUBDIRS)

modules:
	@$(MAKE) -s -C modules

subdirs: $(SUBDIRS) 

$(SUBDIRS):
	@$(MAKE) -s -C $@


#--- Install kernel and modules -------------------------------------------------

install: install_kernel install_modules
	@Misc/boot/install_to_hdimg.sh $(INSTALLPATH)

install_kernel: $(RMK)
	@echo "Installing kernel..."
	@gzip -c $(RMK) >$(INSTALLPATH)/boot/$(RMK).gz

install_modules:
	@$(MAKE) -s -C modules install


#--- Recursive depends ---------------------------------------------------------

dep:
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir all-dep ; done
	@$(MAKE) -s -C modules all-dep


#--- Clean ---------------------------------------------------------------------
.PHONY: clean distclean release
clean:
	@rm -f $(RMK)
	@find $(OBJTOP) -name *.$(O) -exec rm '{}' \;
	@rm -f $(LIBPATH)/*.$(L)

distclean: clean
	@echo "Cleaning up..."
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir all-clean ; done
	@$(MAKE) -s -C modules all-clean

#--- Snapshot and release ------------------------------------------------------

snapshot: distclean
	@snap="radios-`date +%Y%m%d_%k%M`.tar"; tar cf $$snap * && bzip2 $$snap

release: distclean
	@rm -f Build/header.mk
	@echo -n "Making release file: "
	@release_file=radios-`grep ^RadiOS_Version kernel/version.nasm | awk '{ print $$3 }' | sed 's/\"//g'`.tar.gz ; \
	   echo $$release_file; tar -czf $$release_file *

#-------------------------------------------------------------------------------
