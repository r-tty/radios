
# Rules for subdirectories
.PHONY : all-make all-depends all-clean

all-make: all
	@for dir in $(SUBDIRS) ; do \
	    (cd $$dir; $(MAKE) LIB_UPDATE=lib-update) ; \
	done

all-depends: dep
	@for dir in $(SUBDIRS) ; do \
	    (cd $$dir; $(MAKE) dep) ; \
	done
	
all-clean: clean
	@for dir in $(SUBDIRS) ; do \
	    (cd $$dir; $(MAKE) clean) ; \
	done
