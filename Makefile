VERSION := $(shell cat VERSION)
BINARY_NAME := OpenWin
INSTALL_PATH := /usr/local/bin/openwin

.PHONY: build app install uninstall clean

build:
	swift build -c release

app: build
	./build-app.sh

install: build
	@echo "Installing OpenWin $(VERSION) to $(INSTALL_PATH)..."
	cp .build/release/$(BINARY_NAME) $(INSTALL_PATH)
	@echo ""
	@echo "Installed! Run with: openwin &"
	@echo ""
	@echo "NOTE: Grant Accessibility permission in System Settings"
	@echo "      > Privacy & Security > Accessibility"

uninstall:
	rm -f $(INSTALL_PATH)
	@echo "OpenWin uninstalled."

clean:
	swift package clean
	rm -rf .build OpenWin.app
