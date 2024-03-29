DOCS       = FAQ.md
MAN_MAN1   = btrbk.1 \
             lsbtr.1 \
             ssh_filter_btrbk.1
MAN_MAN5   = btrbk.conf.5

PN         = btrbk
PREFIX    ?= /usr
DOCDIR     = $(PREFIX)/share/doc/$(PN)
MAN1DIR    = $(PREFIX)/share/man/man1
MAN5DIR    = $(PREFIX)/share/man/man5

ifeq ($(COMPRESS), yes)
  DOCS     := $(addsuffix .gz,$(DOCS))
  MAN_MAN1 := $(addsuffix .gz,$(MAN_MAN1))
  MAN_MAN5 := $(addsuffix .gz,$(MAN_MAN5))
endif

# convert using "asciidoctor": <https://asciidoctor.org>
# fallback to "a2x" from asciidoc package: <http://asciidoc.org>
ifneq (, $(shell command -v asciidoctor 2> /dev/null))
  ASCIIDOC_MANPAGE = asciidoctor -d manpage -b manpage
  ASCIIDOC_HTML    = asciidoctor -b html5 -d article
else ifneq (, $(shell command -v a2x 2> /dev/null))
  # NOTE: using -L (--no-xmllint), as xmllint is a separate package on many distros.
  ASCIIDOC_MANPAGE = a2x -L -d manpage -f manpage
  ASCIIDOC_HTML    = asciidoc -b html -d article
else
  ASCIIDOC_ERR = $(error "please install either asciidoc or asciidoctor")
  ASCIIDOC_MANPAGE = $(ASCIIDOC_ERR)
  ASCIIDOC_HTML    = $(ASCIIDOC_ERR)
endif

# reproducible builds: reference date is ":date:" attribute from asciidoc source
date_attr = $(shell sed -rn 's/:date:\s*//p' $(1))
source_date_epoch = $(shell date +%s -u -d $(call date_attr,$(1)))


all: man
man: man1 man5
man1: $(MAN_MAN1)
man5: $(MAN_MAN5)

install: install-man install-doc

install-man: man
	install -d -m 755 "$(DESTDIR)$(MAN1DIR)"
	install -d -m 755 "$(DESTDIR)$(MAN5DIR)"
	install -p -m 644 $(MAN_MAN1) "$(DESTDIR)$(MAN1DIR)"
	install -p -m 644 $(MAN_MAN5) "$(DESTDIR)$(MAN5DIR)"

install-doc: $(DOCS)
	install -d -m 755 "$(DESTDIR)$(DOCDIR)"
	install -p -m 644 $(DOCS) "$(DESTDIR)$(DOCDIR)"

clean:
	rm -f *.md.gz *.[15] *.[15].{gz,html}

%.gz : %
	gzip -9 -n -c $< > $@

%.1 : %.1.asciidoc
	SOURCE_DATE_EPOCH=$(call source_date_epoch,$<) $(ASCIIDOC_MANPAGE) $<

%.5 : %.5.asciidoc
	SOURCE_DATE_EPOCH=$(call source_date_epoch,$<) $(ASCIIDOC_MANPAGE) $<

%.html : %.asciidoc
	SOURCE_DATE_EPOCH=$(call source_date_epoch,$<) $(ASCIIDOC_HTML) -o $@ $<
