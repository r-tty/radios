
#--- Common part of all makefiles ----------------------------------------------

ifndef staticlib
staticlib = NONE
endif

ifndef TARGET_LIB
TARGET_LIB = $(staticlib)
endif

srcfiles = $(patsubst %.rdm,%.nasm,$(OBJS))
depfile = .depend


#--- Individual dependencies ---------------------------------------------------

all: $(depfile) $(TARGET_LIB)

-include $(depfile)


#--- Target library ------------------------------------------------------------

ifdef deps_generated

ifneq ($(TARGET_LIB), NONE)
ifdef modnamesfile

$(TARGET_LIB): $(OBJS) $(OBJPATH)/$(modnamesfile) $(LIB_UPDATE)
	@if [ -f $(LIBPATH)/$(TARGET_LIB) ] ; then \
	  echo "Updating library $(TARGET_LIB)" ; \
	 else \
	  echo "Creating library $(TARGET_LIB)" ; \
	  $(AR) c $(LIBPATH)/$(TARGET_LIB) ; fi
	@cd $(OBJPATH); awk '/^[^#]/ { printf("$(AR) r $(LIBPATH)/$(TARGET_LIB) %s %s\n", $$2, $$1) }' $(modnamesfile) | sh

$(OBJPATH)/$(modnamesfile): $(srcfiles)
	@echo "# Each line is just a pair of filename and module name" >$(OBJPATH)/$(modnamesfile)
	@grep -H '^module' $(srcfiles) | sed 's/\.nasm:module/\.rdm/' >>$(OBJPATH)/$(modnamesfile)

endif
else
$(TARGET_LIB): $(OBJS)
endif

endif

.PHONY: lib-update


#--- Generate dependencies file ------------------------------------------------

dep:
	@echo "Generating makefile dependencies..."
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) $(srcfiles) >>$(depfile)

#--- Clean ---------------------------------------------------------------------

clean:
	@echo "Cleaning up..."
	@cd $(OBJPATH) && rm -f $(OBJS) $(modnamesfile)
	@cd $(LIBPATH) && rm -f $(TARGET_LIB)
	@rm -f $(depfile) 
