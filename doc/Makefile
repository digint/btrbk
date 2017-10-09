DOCS       = FAQ.md \
             upgrade_to_v0.23.0.md
MAN_MAN1   = btrbk.1 \
             ssh_filter_btrbk.1
MAN_MAN5   = btrbk.conf.5

GZ_MAN1 = $(addsuffix .gz,$(MAN_MAN1))
GZ_MAN5 = $(addsuffix .gz,$(MAN_MAN5))

all: man
man: man1 man5
man1: $(GZ_MAN1)
man5: $(GZ_MAN5)

clean:
	rm -f $(GZ_MAN1) $(GZ_MAN5)

%.gz : %
	gzip -9f $<

# convert using a2x from asciidoc package: http://asciidoc.org
%.1 : %.1.asciidoc
	a2x -d manpage -f manpage $<

%.5 : %.5.asciidoc
	a2x -d manpage -f manpage $<

%.html : %.asciidoc
	asciidoc -b html -d article -o $@ $<
