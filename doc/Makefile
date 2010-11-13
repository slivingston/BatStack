# Build documentation
#
# Scott Livingston  <slivingston@caltech.edu>
# Aug 2010

OUTDIR=build


all: man

man: BatStack_man.tex
	pdflatex -output-directory $(OUTDIR) $<
	pdflatex -output-directory $(OUTDIR) $<

sync: build/BatStack_man.pdf
	scp build/BatStack_man.pdf slivings@cds.caltech.edu:/home/users/slivings/public_html/

clean:
	rm -rfv $(OUTDIR)/*
