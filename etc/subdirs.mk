
# Rules for subdirectories
.PHONY : all-make all-dep all-clean $(SUBDIRS)

all-make: all $(SUBDIRS)

$(SUBDIRS):
	@$(MAKE) -C $@ LIB_UPDATE=lib-update

all-dep: dep
	@for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir dep ; done
	
all-clean: clean
	@for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir clean ; done
