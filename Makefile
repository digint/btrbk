# NOTE: systemd units are hardcoded in "install-systemd" for simplicity
# NOTE: documentation inside "doc/" folder is processed in "doc/Makefile"
BIN        = btrbk
CONFIGS    = btrbk.conf.example
DOCS       = ChangeLog \
             README.md
SCRIPTS    = ssh_filter_btrbk.sh \
             contrib/cron/btrbk-mail \
             contrib/migration/raw_suffix2sidecar \
             contrib/crypt/kdf_pbkdf2.py

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

# make variables accessible to `envsubst`
.EXPORT_ALL_VARIABLES:

all: man

install: install-bin install-etc install-systemd install-share install-man install-doc

install-bin:
	@echo 'installing binary...'
	install -d -m 755 "$(DESTDIR)$(BINDIR)"
	install -p -m 755 $(BIN) "$(DESTDIR)$(BINDIR)"

install-etc:
	@echo 'installing example configs...'
	install -d -m 755 "$(DESTDIR)$(CONFDIR)/btrbk"
	install -p -m 644 $(CONFIGS) "$(DESTDIR)$(CONFDIR)/btrbk"

install-systemd:
	@echo 'installing systemd service units...'
	install -d -m 755 "$(DESTDIR)$(SYSTEMDDIR)"
	envsubst < contrib/systemd/btrbk.service.in > contrib/systemd/btrbk.service.tmp
	envsubst < contrib/systemd/btrbk.timer.in > contrib/systemd/btrbk.timer.tmp
	install -p -m 644 contrib/systemd/btrbk.service.tmp "$(DESTDIR)$(SYSTEMDDIR)/btrbk.service"
	install -p -m 644 contrib/systemd/btrbk.timer.tmp "$(DESTDIR)$(SYSTEMDDIR)/btrbk.timer"
	rm contrib/systemd/btrbk.service.tmp
	rm contrib/systemd/btrbk.timer.tmp

install-share:
	@echo 'installing auxiliary scripts...'
	install -d -m 755 "$(DESTDIR)$(SCRIPTDIR)"
	install -p -m 755 $(SCRIPTS) "$(DESTDIR)$(SCRIPTDIR)"

install-man: man
	@echo 'installing man pages...'
	@$(MAKE) -C doc install-man

install-doc:
	@echo 'installing documentation...'
	install -d -m 755 "$(DESTDIR)$(DOCDIR)"
	install -p -m 644 $(DOCS) "$(DESTDIR)$(DOCDIR)"
	gzip -9f $(addprefix "$(DESTDIR)$(DOCDIR)"/, $(DOCS))
	@$(MAKE) -C doc install-doc

man:
	@echo 'generating manpages...'
	@$(MAKE) -C doc man

clean:
	@$(MAKE) -C doc clean
