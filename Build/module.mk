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
    ifdef C_SOURCE
	srcfiles = $(patsubst %.$(O),%.c,$(OBJS))
    else
	srcfiles = $(patsubst %.$(O),%.nasm,$(OBJS))
    endif
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
	@$(LD) $(LDFLAGS) -o $(OBJPATH)/$@ $(OBJS) $(EXTRAOBJS) $(LDLIBS)

else
$(TARGET_RDM):
	@echo "Run 'make dep' to generate dependencies."
endif

#--- Generate dependencies file ------------------------------------------------

dep:
	@echo "Generating dependencies in `pwd`"
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) $(srcfiles) >>$(depfile)

#--- Clean ---------------------------------------------------------------------

clean:
	@echo "$(group): $(OBJS) $(TARGET_RDM)"
	@rm -f $(depfile)
	@cd $(OBJPATH) && rm -f $(OBJS) $(TARGET_RDM) $(extraclean)
	@cd $(LIBPATH) && rm -f $(LIBS)
