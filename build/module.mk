#
# module.mk - should be included in the top-level module Makefile
#

ifndef TARGET_RDM
    error TARGET_RDM is not defined
endif

ifdef LIBS
    LDLIBS = $(addprefix -l,$(LIBS))
endif

ifndef SRCS
    srcfiles = $(patsubst %.$(O),%.nasm,$(OBJS))
else
    srcfiles = $(SRCS)
endif

depfile = .depend

#--- Target module -------------------------------------------------------------

all: $(depfile) $(TARGET_RDM)

-include $(depfile)

ifdef deps_generated

$(TARGET_RDM): $(OBJS) $(LIBS)
	@echo Linking $@
	@$(LD) $(LDFLAGS) -o $(OBJPATH)/$@ $(OBJS) $(LDLIBS)

endif # deps_generated


#--- Generate dependencies file ------------------------------------------------

dep:
	@echo "Generating dependencies in `pwd`"
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) $(srcfiles) >>$(depfile)

#--- Clean ---------------------------------------------------------------------

clean:
	@echo "Cleaning up in `pwd`"
	@rm -f $(depfile)
	@cd $(OBJPATH) && rm -f $(OBJS) $(TARGET_RDM)
	@cd $(LIBPATH) && rm -f $(LIBS)
