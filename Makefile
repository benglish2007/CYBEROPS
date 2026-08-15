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

.PHONY: install uninstall

install:
	$(INSTALL) -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(CYBEROPS_DIR)/lib"
	$(INSTALL) -d "$(DESTDIR)$(APPLICATIONS_DIR)" "$(DESTDIR)$(PIXMAPS_DIR)" "$(DESTDIR)$(DOC_DIR)"
	$(INSTALL) -m 755 cyberops.sh "$(DESTDIR)$(CYBEROPS_DIR)/cyberops.sh"
	$(INSTALL) -m 644 lib/*.sh "$(DESTDIR)$(CYBEROPS_DIR)/lib/"
	$(INSTALL) -m 755 packaging/cyberops.in "$(DESTDIR)$(BINDIR)/cyberops"
	$(SED) -i 's|@CYBEROPS_LAUNCHER@|$(CYBEROPS_DIR)/cyberops.sh|g' "$(DESTDIR)$(BINDIR)/cyberops"
	$(INSTALL) -m 644 cyberops.png "$(DESTDIR)$(ICON_PATH)"
	$(INSTALL) -m 644 LICENSE "$(DESTDIR)$(DOC_DIR)/LICENSE"
	$(INSTALL) -m 644 README.md "$(DESTDIR)$(DOC_DIR)/README.md"
	$(INSTALL) -m 644 docs/*.md "$(DESTDIR)$(DOC_DIR)/"
	$(INSTALL) -m 644 packaging/cyberops.desktop.in "$(DESTDIR)$(APPLICATIONS_DIR)/cyberops.desktop"
	$(SED) -i 's|@CYBEROPS_EXEC@|$(BINDIR)/cyberops|g' "$(DESTDIR)$(APPLICATIONS_DIR)/cyberops.desktop"
	$(SED) -i 's|@CYBEROPS_ICON@|$(ICON_PATH)|g' "$(DESTDIR)$(APPLICATIONS_DIR)/cyberops.desktop"
	rm -f -- "$(DESTDIR)$(LEGACY_ICON_PATH)"
	@if command -v update-desktop-database >/dev/null 2>&1; then \
		update-desktop-database "$(DESTDIR)$(APPLICATIONS_DIR)" >/dev/null; \
	fi

uninstall:
	rm -f -- "$(DESTDIR)$(BINDIR)/cyberops"
	rm -f -- "$(DESTDIR)$(APPLICATIONS_DIR)/cyberops.desktop"
	rm -f -- "$(DESTDIR)$(ICON_PATH)" "$(DESTDIR)$(LEGACY_ICON_PATH)"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/LICENSE" "$(DESTDIR)$(DOC_DIR)/README.md"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/DEMO.md" "$(DESTDIR)$(DOC_DIR)/DOCKER.md"
	rm -f -- "$(DESTDIR)$(DOC_DIR)/OPERATIONS.md" "$(DESTDIR)$(DOC_DIR)/USB.md"
	rm -f -- "$(DESTDIR)$(CYBEROPS_DIR)/cyberops.sh" "$(DESTDIR)$(CYBEROPS_DIR)/lib/"*.sh
	rmdir --ignore-fail-on-non-empty -- "$(DESTDIR)$(CYBEROPS_DIR)/lib" "$(DESTDIR)$(CYBEROPS_DIR)"
	rmdir --ignore-fail-on-non-empty -- "$(DESTDIR)$(DOC_DIR)"
