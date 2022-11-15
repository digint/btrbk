DOCS       = FAQ.md \
             upgrade_to_v0.23.0.md
MAN_MAN1   = btrbk.1 \
             lsbtr.1 \
             ssh_filter_btrbk.1
MAN_MAN5   = btrbk.conf.5

PN         = btrbk
PREFIX    ?= /usr
DOCDIR     = $(PREFIX)/share/doc/$(PN)
MAN1DIR    = $(PREFIX)/share/man/man1
MAN5DIR    = $(PREFIX)/share/man/man5
SCRIPTDIR ?= $(PREFIX)/share/$(PN)/scripts

ifeq ($(COMPRESS), yes)
  DOCS     := $(addsuffix .gz,$(DOCS))
  MAN_MAN1 := $(addsuffix .gz,$(MAN_MAN1))
  MAN_MAN5 := $(addsuffix .gz,$(MAN_MAN5))
endif

replace_vars = sed \
	-e "s|@SCRIPTDIR@|$(SCRIPTDIR)|g"

# convert using "asciidoctor": <https://asciidoctor.org>
ASCIIDOCTOR_MANPAGE = asciidoctor -d manpage -b manpage
ASCIIDOCTOR_HTML    = asciidoctor -b html5 -d article

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
	SOURCE_DATE_EPOCH=$(call source_date_epoch,$<) $(ASCIIDOCTOR_MANPAGE) -o $@ $<

%.5 : %.5.asciidoc
	SOURCE_DATE_EPOCH=$(call source_date_epoch,$<) $(ASCIIDOCTOR_MANPAGE) -o $@ $<

%.html : %.asciidoc
	SOURCE_DATE_EPOCH=$(call source_date_epoch,$<) $(ASCIIDOCTOR_HTML) -o $@ $<

%.asciidoc : %.asciidoc.in
	$(replace_vars) ssh_filter_btrbk.1.asciidoc.in > ssh_filter_btrbk.1.asciidoc
