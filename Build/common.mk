#
# common.mk - makefile for object and library builds.
#

ifndef TARGET_LIB
    TARGET_LIB = NONE
endif

ifndef SRCS
    srcfiles = $(patsubst %.$(O),%.nasm,$(OBJS))
else
    srcfiles = $(SRCS)
endif

depfile = .depend

ifndef modnamesfile
    modnamesfile = .$(group)$(subgroup)-modules
endif


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
	@cd $(OBJPATH); awk '/^[^#]/ { printf("$(AR) r $(LIBPATH)/$(TARGET_LIB) \\%s \\%s\n", $$2, $$1) }' $(modnamesfile) | sh

$(OBJPATH)/$(modnamesfile): $(srcfiles)
	@echo "# Each line is just a pair of filename and module name" >$(OBJPATH)/$(modnamesfile)
	@grep -H '^module' $(srcfiles) | sed 's/\.nasm:module/\.$(O)/' >>$(OBJPATH)/$(modnamesfile)

endif # modnamesfile

else # $(TARGET_LIB) == "NONE"
# Kluge: GNU make doesn't know anything about RDOFF libraries format :-/
$(TARGET_LIB): $(OBJS)
endif # $(TARGET_LIB) != "NONE"

else # !deps_generated
$(TARGET_LIB):
	@echo "Run 'make dep' to generate dependencies."
endif

.PHONY: lib-update

#--- Generate dependencies file ------------------------------------------------

dep:
	@echo "Generating dependencies in `pwd`"
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) $(srcfiles) >>$(depfile)

#--- Clean ---------------------------------------------------------------------

clean:
	@echo "$(group): $(OBJS)"
	@cd $(OBJPATH) && rm -f $(OBJS) $(modnamesfile) $(extraclean)
	@cd $(LIBPATH) && rm -f $(TARGET_LIB)
	@rm -f $(depfile) 
