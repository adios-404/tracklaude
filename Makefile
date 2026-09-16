# tracklaude — build, bundle, sign and install from SwiftPM alone (no Xcode needed).

APP_NAME    := tracklaude
BUNDLE_ID   := com.adios404.tracklaude
VERSION     := $(strip $(shell cat VERSION))
BUILD_DIR   := .build/release
DIST_DIR    := dist
APP         := $(DIST_DIR)/$(APP_NAME).app
CONTENTS    := $(APP)/Contents
INSTALL_DIR := /Applications
ENTITLEMENTS := Packaging/$(APP_NAME).entitlements

# Why: with only Command Line Tools installed, SwiftPM never searches the directory that
# holds Testing.framework (`xcrun --show-sdk-platform-path` fails there), so `swift test`
# builds a runner whose `canImport(Testing)` is false and silently runs zero tests.
# Passing the search path globally fixes it. On an Xcode toolchain the platform path
# resolves and no extra flags are needed. Verified 2026-09-16, Swift 6.2.3 CLT.
CLT_FRAMEWORKS := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
HAS_PLATFORM_PATH := $(shell xcrun --show-sdk-platform-path >/dev/null 2>&1 && echo yes)
ifeq ($(HAS_PLATFORM_PATH),yes)
  TEST_FLAGS :=
else
  TEST_FLAGS := -Xswiftc -F$(CLT_FRAMEWORKS) -Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS)
endif

.PHONY: all build test bundle sign install run clean

all: build

build:
	swift build -c release

test:
	swift test $(TEST_FLAGS)

bundle: build
	rm -rf "$(APP)"
	mkdir -p "$(CONTENTS)/MacOS" "$(CONTENTS)/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(CONTENTS)/MacOS/$(APP_NAME)"
	sed 's/@VERSION@/$(VERSION)/g' Packaging/Info.plist.in > "$(CONTENTS)/Info.plist"
	printf 'APPL????' > "$(CONTENTS)/PkgInfo"
	@echo "Assembled $(APP) (v$(VERSION))"

sign: bundle
	codesign --force --sign - --entitlements "$(ENTITLEMENTS)" --identifier "$(BUNDLE_ID)" "$(APP)"
	codesign --verify --verbose=2 "$(APP)"

install: sign
	-pkill -x "$(APP_NAME)" 2>/dev/null
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed $(INSTALL_DIR)/$(APP_NAME).app — launch it with: open $(INSTALL_DIR)/$(APP_NAME).app"

run: install
	open "$(INSTALL_DIR)/$(APP_NAME).app"

clean:
	rm -rf .build "$(DIST_DIR)"
