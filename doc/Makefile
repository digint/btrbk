DOCS       = FAQ.md \
             upgrade_to_v0.23.0.md
MAN_MAN1   = btrbk.1 \
             ssh_filter_btrbk.1
MAN_MAN5   = btrbk.conf.5

PN         = btrbk
PREFIX    ?= /usr
DOCDIR     = $(PREFIX)/share/doc/$(PN)
MAN1DIR    = $(PREFIX)/share/man/man1
MAN5DIR    = $(PREFIX)/share/man/man5

GZ_MAN1 = $(addsuffix .gz,$(MAN_MAN1))
GZ_MAN5 = $(addsuffix .gz,$(MAN_MAN5))

all: man
man: man1 man5
man1: $(GZ_MAN1)
man5: $(GZ_MAN5)

install: install-man install-doc

install-man: man
	install -d -m 755 "$(DESTDIR)$(MAN1DIR)"
	install -d -m 755 "$(DESTDIR)$(MAN5DIR)"
	install -p -m 644 $(GZ_MAN1) "$(DESTDIR)$(MAN1DIR)"
	install -p -m 644 $(GZ_MAN5) "$(DESTDIR)$(MAN5DIR)"

install-doc:
	install -d -m 755 "$(DESTDIR)$(DOCDIR)"
	install -p -m 644 $(DOCS) "$(DESTDIR)$(DOCDIR)"
	gzip -9f $(addprefix "$(DESTDIR)$(DOCDIR)"/, $(DOCS))

clean:
	rm -f $(GZ_MAN1) $(GZ_MAN5)

%.gz : %
	gzip -9f $<

# convert using a2x from asciidoc package: http://asciidoc.org

# NOTE: we are using -L (--no-xmllint), as this xmllint is a separate
# package on many distros.

%.1 : %.1.asciidoc
	a2x -L -d manpage -f manpage $<

%.5 : %.5.asciidoc
	a2x -L -d manpage -f manpage $<

%.html : %.asciidoc
	asciidoc -b html -d article -o $@ $<
