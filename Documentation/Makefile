#
# Makefile for building PoscScript or PDF documentation.
#

### Commands
LATEX = latex
DVIPS = dvips
PDFELATEX = pdfelatex

### Command options
LATEXFLAGS =
DVIPSFLAGS =
PDFELATEXFLAGS =

### Source files
SOURCES = 01-overview.tex \
          02-rmk.tex \
          03-taskman.tex \
          04-libc.tex \
          05-resmgr.tex \
          06-modules.tex \
          07-cfs.tex \
          08-freexti.tex \
          09-radionix.tex \
          A1-monitor.tex \
          A2-bootstrap.tex \
          A3-build.tex \
          RadiOS.tex

### Implicit rules
# Cancel all built-in rules
% : %
# A rule to make dvi from tex using latex
%.dvi : %.tex
	$(LATEX) $(LATEXFLAGS) $<
	
# A rule to make ps from dvi using dvips
%.ps : %.dvi
	$(DVIPS) $(DVIPSFLAGS) $<

# A rule to make pdf from tex using pdfelatex
%.pdf : %.tex
	$(PDFELATEX) $(PDFELATEXFLAGS) $<


### Explicit rules
all: ps

ps:  RadiOS.ps
pdf: RadiOS.pdf

RadiOS.ps: $(SOURCES)
RadiOS.pdf: $(SOURCES)


### Additional commands (clean, etc.)
clean:
	rm -f *.dvi *.ps *.pdf *.log *.aux
