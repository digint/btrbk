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

# convert using "a2x" from asciidoc package <http://asciidoc.org>,
# with fallback to "asciidoctor" <https://asciidoctor.org>
ifneq (, $(shell command -v a2x 2> /dev/null))
  # NOTE: using -L (--no-xmllint), as xmllint is a separate package on many distros.
  ASCIIDOC_MANPAGE = a2x -L -d manpage -f manpage
  ASCIIDOC_HTML    = asciidoc -b html -d article
else ifneq (, $(shell command -v asciidoctor 2> /dev/null))
  ASCIIDOC_MANPAGE = asciidoctor -d manpage -b manpage
  ASCIIDOC_HTML    = asciidoctor -b html5 -d article
else
  ASCIIDOC_ERR = $(error "please install either asciidoc or asciidoctor")
  ASCIIDOC_MANPAGE = $(ASCIIDOC_ERR)
  ASCIIDOC_HTML    = $(ASCIIDOC_ERR)
endif


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

%.1 : %.1.asciidoc
	$(ASCIIDOC_MANPAGE) $<

%.5 : %.5.asciidoc
	$(ASCIIDOC_MANPAGE) $<

%.html : %.asciidoc
	$(ASCIIDOC_HTML) -o $@ $<
