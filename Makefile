PREFIX ?= /usr/local
DESTDIR ?=

BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/lib
DATADIR ?= $(PREFIX)/share
CYBEROPS_DIR := $(LIBEXECDIR)/cyberops
APPLICATIONS_DIR := $(DATADIR)/applications
PIXMAPS_DIR := $(DATADIR)/pixmaps
DOC_DIR := $(DATADIR)/doc/cyberops
ICON_PATH := $(PIXMAPS_DIR)/cyberops.png
LEGACY_ICON_PATH := $(DATADIR)/icons/hicolor/1024x1024/apps/cyberops.png

INSTALL ?= install
SED ?= sed
VERSION ?=
SHELL_SOURCES := cyberops.sh $(wildcard lib/*.sh) $(wildcard plugins-available/*/*/plugin.sh) $(wildcard packaging/*.sh) \
	packaging/cyberops.in $(wildcard tests/*.sh)

.PHONY: check syntax quality test install install-deps full-install uninstall deb deb-inspect release-check release-preview release

syntax:
	bash -n $(SHELL_SOURCES)

quality:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck is required for 'make check'." >&2; exit 1; }
	shellcheck $(SHELL_SOURCES)
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt is required for 'make check'." >&2; exit 1; }
	shfmt -d -i 4 -ci $(SHELL_SOURCES)

test:
	@for test_script in tests/test_*.sh; do \
		env -u NO_COLOR -u CYBEROPS_NO_COLOR bash "$$test_script" || exit 1; \
	done

check: syntax quality test

deb:
	bash packaging/build-deb.sh

deb-inspect: deb
	dpkg-deb --info "dist/cyberops_$$(sed -n 's/^VERSION="\(.*\)"/\1/p' lib/runtime.sh)_all.deb"
	dpkg-deb --contents "dist/cyberops_$$(sed -n 's/^VERSION="\(.*\)"/\1/p' lib/runtime.sh)_all.deb"

release-check:
	@test -n "$(VERSION)" || { echo "VERSION is required (example: make release-check VERSION=2.9)" >&2; exit 2; }
	bash packaging/release.sh check "$(VERSION)"

release-preview:
	@test -n "$(VERSION)" || { echo "VERSION is required (example: make release-preview VERSION=2.9)" >&2; exit 2; }
	bash packaging/release.sh preview "$(VERSION)"

release:
	@test -n "$(VERSION)" || { echo "VERSION is required (example: make release VERSION=2.9)" >&2; exit 2; }
	bash packaging/release.sh publish "$(VERSION)"

install-deps:
	bash packaging/install-dependencies.sh

full-install: install-deps install

install:
	$(INSTALL) -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(CYBEROPS_DIR)/lib" "$(DESTDIR)$(CYBEROPS_DIR)/plugins" "$(DESTDIR)$(CYBEROPS_DIR)/plugins-available"
	$(INSTALL) -d "$(DESTDIR)$(APPLICATIONS_DIR)" "$(DESTDIR)$(PIXMAPS_DIR)" "$(DESTDIR)$(DOC_DIR)"
	$(INSTALL) -m 755 cyberops.sh "$(DESTDIR)$(CYBEROPS_DIR)/cyberops.sh"
	$(INSTALL) -m 644 lib/*.sh "$(DESTDIR)$(CYBEROPS_DIR)/lib/"
	cp -R plugins-available/. "$(DESTDIR)$(CYBEROPS_DIR)/plugins-available/"
	find "$(DESTDIR)$(CYBEROPS_DIR)/plugins-available" -type d -exec chmod 755 {} +
	find "$(DESTDIR)$(CYBEROPS_DIR)/plugins-available" -type f -exec chmod 644 {} +
	rm -f -- "$(DESTDIR)$(CYBEROPS_DIR)/lib/setup.sh"
	$(INSTALL) -m 755 packaging/cyberops.in "$(DESTDIR)$(BINDIR)/cyberops"
	$(SED) -i 's|@CYBEROPS_LAUNCHER@|$(CYBEROPS_DIR)/cyberops.sh|g' "$(DESTDIR)$(BINDIR)/cyberops"
	$(INSTALL) -m 644 cyberops.png "$(DESTDIR)$(ICON_PATH)"
	$(INSTALL) -m 644 LICENSE "$(DESTDIR)$(DOC_DIR)/LICENSE"
	$(INSTALL) -m 644 README.md "$(DESTDIR)$(DOC_DIR)/README.md"
	$(INSTALL) -m 644 docs/*.md "$(DESTDIR)$(DOC_DIR)/"
	$(INSTALL) -m 644 docs/cyberops.conf.example "$(DESTDIR)$(DOC_DIR)/cyberops.conf.example"
	$(INSTALL) -m 644 packaging/cyberops.desktop.in "$(DESTDIR)$(APPLICATIONS_DIR)/cyberops.desktop"
	$(SED) -i 's|@CYBEROPS_EXEC@|$(BINDIR)/cyberops|g' "$(DESTDIR)$(APPLICATIONS_DIR)/cyberops.desktop"
	$(SED) -i 's|@CYBEROPS_ICON@|$(ICON_PATH)|g' "$(DESTDIR)$(APPLICATIONS_DIR)/cyberops.desktop"
	rm -f -- "$(DESTDIR)$(LEGACY_ICON_PATH)"
	@if test -z "$(DESTDIR)" && command -v update-desktop-database >/dev/null 2>&1; then \
		update-desktop-database "$(DESTDIR)$(APPLICATIONS_DIR)" >/dev/null; \
	fi

uninstall:
	rm -f -- "$(DESTDIR)$(BINDIR)/cyberops"
	rm -f -- "$(DESTDIR)$(APPLICATIONS_DIR)/cyberops.desktop"
	rm -f -- "$(DESTDIR)$(ICON_PATH)" "$(DESTDIR)$(LEGACY_ICON_PATH)"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/LICENSE" "$(DESTDIR)$(DOC_DIR)/README.md"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/DEMO.md" "$(DESTDIR)$(DOC_DIR)/DOCKER.md"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/OPERATIONS.md" "$(DESTDIR)$(DOC_DIR)/USB.md"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/CONFIGURATION.md" "$(DESTDIR)$(DOC_DIR)/cyberops.conf.example"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/RELEASING.md" "$(DESTDIR)$(DOC_DIR)/PACKAGING.md"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/PLUGINS.md" "$(DESTDIR)$(DOC_DIR)/VPN-PLUGINS.md"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/NEON-OVERDRIVE.md" "$(DESTDIR)$(DOC_DIR)/V3-READINESS.md"
	rm -f -- "$(DESTDIR)$(CYBEROPS_DIR)/cyberops.sh" "$(DESTDIR)$(CYBEROPS_DIR)/lib/"*.sh
	rm -rf -- "$(DESTDIR)$(CYBEROPS_DIR)/plugins"
	rm -rf -- "$(DESTDIR)$(CYBEROPS_DIR)/plugins-available"
	rmdir --ignore-fail-on-non-empty -- "$(DESTDIR)$(CYBEROPS_DIR)/lib" "$(DESTDIR)$(CYBEROPS_DIR)"
	rmdir --ignore-fail-on-non-empty -- "$(DESTDIR)$(DOC_DIR)"
