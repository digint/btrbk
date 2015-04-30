PN        = btrbk
VERSION   = 0.17.0

PREFIX   ?= /usr
CONFDIR   = /etc
CRONDIR   = /etc/cron.daily
BINDIR    = $(PREFIX)/sbin
DOCDIR    = $(PREFIX)/share/doc/$(PN)-$(VERSION)
SCRIPTDIR = $(PREFIX)/share/$(PN)/scripts
MAN1DIR   = $(PREFIX)/share/man/man1
MAN5DIR   = $(PREFIX)/share/man/man5

all:
	@echo 'nothing to do for "all"'

install-bin:
	@echo 'installing main script and config...'
	install -Dm644 btrbk.conf.example "$(DESTDIR)$(CONFDIR)/btrbk/btrbk.conf.example"
	install -Dm755 $(PN) "$(DESTDIR)$(BINDIR)/$(PN)"

install-share:
	@echo 'installing auxiliary scripts...'
	install -Dm644 ssh_filter_btrbk.sh "$(DESTDIR)$(SCRIPTDIR)/ssh_filter_btrbk.sh"

install-man:
	@echo 'installing manpages...'
	install -Dm644 doc/btrbk.1 "$(DESTDIR)$(MAN1DIR)/btrbk.1"
	install -Dm644 doc/btrbk.conf.5 "$(DESTDIR)$(MAN5DIR)/btrbk.conf.5"
	gzip -9 "$(DESTDIR)$(MAN1DIR)/btrbk.1"
	gzip -9 "$(DESTDIR)$(MAN5DIR)/btrbk.conf.5"

install-doc:
	@echo 'installing documentation...'
	install -Dm644 README.md "$(DESTDIR)$(DOCDIR)/README.md"
	gzip -9 "$(DESTDIR)$(DOCDIR)/README.md"

install: install-bin install-share install-man install-doc
