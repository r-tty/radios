
# Rules for subdirectories

.PHONY : all-make all-dep all-clean $(SUBDIRS)

all-make: all $(SUBDIRS)

$(SUBDIRS):
	@$(MAKE) -C $@ TARGET_LIB=$(staticlib) LIB_UPDATE=lib-update

all-dep: dep
	@for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir all-dep ; done
	
all-clean: clean
	@for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir all-clean ; done
