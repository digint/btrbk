PN         = btrbk

PREFIX    ?= /usr
CONFDIR    = /etc
CRONDIR    = /etc/cron.daily
BINDIR     = $(PREFIX)/sbin
DOCDIR     = $(PREFIX)/share/doc/$(PN)
SCRIPTDIR  = $(PREFIX)/share/$(PN)/scripts
SYSTEMDDIR = $(PREFIX)/lib/systemd/system
MAN1DIR    = $(PREFIX)/share/man/man1
MAN5DIR    = $(PREFIX)/share/man/man5

process = sed \
	-e "s|@PN@|$(PN)|g" \
	-e "s|@CONFDIR@|$(CONFDIR)|g" \
	-e "s|@CRONDIR@|$(CRONDIR)|g" \
	-e "s|@BINDIR@|$(BINDIR)|g" \
	-e "s|@DOCDIR@|$(DOCDIR)|g" \
	-e "s|@SCRIPTDIR@|$(SCRIPTDIR)|g" \
	-e "s|@SYSTEMDDIR@|$(SYSTEMDDIR)|g" \
	-e "s|@MAN1DIR@|$(MAN1DIR)|g" \
	-e "s|@MAN5DIR@|$(MAN5DIR)|g"

all:
	@echo 'nothing to do for "all"'

install-bin:
	@echo 'installing main script and config...'
	install -pDm644 btrbk.conf.example "$(DESTDIR)$(CONFDIR)/btrbk/btrbk.conf.example"
	install -pDm755 $(PN) "$(DESTDIR)$(BINDIR)/$(PN)"

install-systemd:
	@echo 'installing systemd service units...'
	$(process) contrib/systemd/btrbk.service.in > contrib/systemd/btrbk.service.tmp
	$(process) contrib/systemd/btrbk.timer.in > contrib/systemd/btrbk.timer.tmp
	install -pDm644 contrib/systemd/btrbk.service.tmp "$(DESTDIR)$(SYSTEMDDIR)/btrbk.service"
	install -pDm644 contrib/systemd/btrbk.timer.tmp "$(DESTDIR)$(SYSTEMDDIR)/btrbk.timer"
	rm contrib/systemd/btrbk.service.tmp
	rm contrib/systemd/btrbk.timer.tmp

install-share:
	@echo 'installing auxiliary scripts...'
	install -pDm755 ssh_filter_btrbk.sh "$(DESTDIR)$(SCRIPTDIR)/ssh_filter_btrbk.sh"
	install -pDm755 contrib/cron/btrbk-mail "$(DESTDIR)$(SCRIPTDIR)/btrbk-mail"

install-man:
	@echo 'installing manpages...'
	install -pDm644 doc/btrbk.1 "$(DESTDIR)$(MAN1DIR)/btrbk.1"
	install -pDm644 doc/ssh_filter_btrbk.1 "$(DESTDIR)$(MAN1DIR)/ssh_filter_btrbk.1"
	install -pDm644 doc/btrbk.conf.5 "$(DESTDIR)$(MAN5DIR)/btrbk.conf.5"
	gzip -9f "$(DESTDIR)$(MAN1DIR)/btrbk.1"
	gzip -9f "$(DESTDIR)$(MAN1DIR)/ssh_filter_btrbk.1"
	gzip -9f "$(DESTDIR)$(MAN5DIR)/btrbk.conf.5"

install-doc:
	@echo 'installing documentation...'
	install -pDm644 ChangeLog "$(DESTDIR)$(DOCDIR)/ChangeLog"
	install -pDm644 README.md "$(DESTDIR)$(DOCDIR)/README.md"
	install -pDm644 doc/FAQ.md "$(DESTDIR)$(DOCDIR)/FAQ.md"
	install -pDm644 doc/upgrade_to_v0.23.0.md "$(DESTDIR)$(DOCDIR)/upgrade_to_v0.23.0.md"
	gzip -9f "$(DESTDIR)$(DOCDIR)/ChangeLog"
	gzip -9f "$(DESTDIR)$(DOCDIR)/README.md"
	gzip -9f "$(DESTDIR)$(DOCDIR)/FAQ.md"
	gzip -9f "$(DESTDIR)$(DOCDIR)/upgrade_to_v0.23.0.md"

install: install-bin install-systemd install-share install-man install-doc
