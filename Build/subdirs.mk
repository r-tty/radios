
# Rules for subdirectories

.PHONY : all-make all-dep all-clean $(BUILD) $(SUBDIRS) $(LINK)

all-make: $(BUILD) $(SUBDIRS) $(LINK)

$(SUBDIRS):
	@$(MAKE) -s -C $@ LIB_UPDATE=lib-update

all-dep: dep
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir all-dep ; done
	
all-clean: clean
	@for dir in $(SUBDIRS) ; do $(MAKE) -s -C $$dir all-clean ; done
