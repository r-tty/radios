#
# prog.mk - makefile for building user applications.
#

# USRLIB specifies /usr/lib on RadiOS partition
USRLIB = $(INSTALLPATH)/usr/lib
RTINIT = $(USRLIB)/rtinit.$(O)
RTEXIT = $(USRLIB)/rtexit.$(O)

ifndef TARGET
    error TARGET is not defined
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

all: $(depfile) $(TARGET)

-include $(depfile)

ifdef deps_generated

$(TARGET): $(OBJS) $(LIBS)
	@echo Linking $@
	@$(LD) $(LDFLAGS) -dy -o $(OBJPATH)/$@ $(RTINIT) $(OBJS) $(RTEXIT) $(LDLIBS)

else
$(TARGET):
	@echo "Run 'make dep' to generate dependencies."
endif

#--- Generate dependencies file ------------------------------------------------

dep:
	@echo "Generating dependencies in `pwd`"
	@echo "deps_generated = TRUE" >$(depfile)
	@$(GENDEPS) $(srcfiles) >>$(depfile)

#--- Clean ---------------------------------------------------------------------

clean:
	@echo "$(group): $(OBJS) $(TARGET)"
	@rm -f $(depfile)
	@cd $(OBJPATH) && rm -f $(OBJS) $(TARGET) $(extraclean)
	@cd $(LIBPATH) && rm -f $(LIBS)
