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
	@$(MAKE) -s -C Documentation clean

#--- Documentation -------------------------------------------------------------

doc:
	$(MAKE) -s -C Documentation all

#--- Snapshot, diff and release ------------------------------------------------

snapshot: distclean
	@echo -n "Snapshot file: "
	@snap="radios-`date +%Y%m%d_%H%M`.tar"; \
	   echo $${snap}.bz2; tar cf $$snap * && bzip2 $$snap

diff: distclean
	@echo -n "Diff file: "
	@dif="radios-`date +%Y%m%d_%H%M`.diff.bz2"; echo $$dif; \
	   diff -x "radios-`date +%Y`*" -x header.mk \
		-uNr ../radios-previous/ . | bzip2 -c > $$dif

release: distclean
	@rm -f Build/header.mk
	@echo -n "Release file: "
	@relf=radios-`awk '/RADIOS_VERSION/ { print $$3 }' include/parameters.ah | sed 's/\"//g'`.tar.gz ; \
	   echo $$relf; tar czf $$relf *

#-------------------------------------------------------------------------------
