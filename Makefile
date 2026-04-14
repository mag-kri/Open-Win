VERSION := $(shell cat VERSION)
BINARY_NAME := BetterMac
INSTALL_PATH := /usr/local/bin/bettermac

.PHONY: build app pkg install uninstall clean

build:
	swift build -c release

app: build
	./build-app.sh

pkg:
	./build-pkg.sh

install: build
	@echo "Installing BetterMac $(VERSION) to $(INSTALL_PATH)..."
	cp .build/release/$(BINARY_NAME) $(INSTALL_PATH)
	@echo ""
	@echo "Installed! Run with: bettermac &"
	@echo ""
	@echo "NOTE: Grant Accessibility permission in System Settings"
	@echo "      > Privacy & Security > Accessibility"

uninstall:
	rm -f $(INSTALL_PATH)
	@echo "BetterMac uninstalled."

clean:
	swift package clean
	rm -rf .build BetterMac.app build-release
