
#--- Common part of all makefiles ----------------------------------------------

ifndef TARGET_LIB
TARGET_LIB = NONE
endif

srcfiles = $(patsubst %.rdm,%.as,$(OBJS))
depfile = .depend


#--- Individual dependencies ---------------------------------------------------

all: $(depfile) $(TARGET_LIB)

-include $(depfile)


#--- Target library ------------------------------------------------------------

ifdef deps_generated

ifneq ($(TARGET_LIB), NONE)

$(TARGET_LIB): $(OBJS) $(modnamesfile) $(LIB_UPDATE)
	@if [ -f $(OUTPATH)/$(TARGET_LIB) ] ; then \
	  echo "Updating library $(TARGET_LIB)" ; \
	 else \
	  echo "Creating library $(TARGET_LIB)" ; \
	  $(AR) c $(OUTPATH)/$(TARGET_LIB) ; fi
	
	@cd $(OUTPATH); grep '^[^#]' $(modnamesfile) | awk \
	         -v AR=$(AR) -v TARGET=$(TARGET_LIB) \
	          '{ printf("%s r %s %s %s\n", AR, TARGET, $$2, $$1) }' | sh

$(modnamesfile): $(srcfiles)
	@echo "# Each line is just a pair of filename and module name" >$(modnamesfile)
	@grep -H '^module' $(srcfiles) | sed 's/\.as:module/\.rdm/' >>$(modnamesfile)

else
$(TARGET_LIB): $(OBJS)
endif

endif

.PHONY : lib-update


#--- Generate dependencies file ------------------------------------------------

dep:
	@echo "Generating makefile dependencies..."
	@echo "deps_generated = TRUE" >$(depfile)
	@for file in $(srcfiles); do \
	    $(GENDEPS) $$file >>$(depfile); \
	 done
	 
	 
#--- Clean ---------------------------------------------------------------------

clean:
	@echo "Cleaning up..."
	@cd $(OUTPATH) && rm -f $(OBJS) $(TARGET_LIB) $(modnamesfile)
	@rm -f $(depfile) 
