# Build-and-run shortcuts. `make` with no target lists them.
#
#   make mac               build and launch the Mac app
#   make ios               run in Xcode on the iOS Simulator (SIM="iPhone 17 Pro")
#   make device            build, install and launch on a connected iPhone (DEVICE=<id>)
#   add -demo to any of those for sample data in a throwaway store, e.g. `make ios-demo`

PROJECT   := prdctv.xcodeproj
DERIVED   := build
BUNDLE_ID := com.jonathanlee.prdctv
SIM       ?= iPhone 17 Pro
# First paired, available iPhone/iPad. Override with DEVICE=<identifier> (see `make devices`).
DEVICE    ?= $(shell xcrun devicectl list devices 2>/dev/null | grep 'available (paired)' | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)

MAC_APP     := $(DERIVED)/Build/Products/Debug/prdctv.app
LSREGISTER  := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
SIM_APP     := $(DERIVED)/Build/Products/Debug-iphonesimulator/prdctv.app
DEVICE_APP  := $(DERIVED)/Build/Products/Debug-iphoneos/prdctv.app
# A new build number each build so macOS rereads the widget after every install.
BUILD_NUMBER := $(shell date +%s)
XCODEBUILD  := xcodebuild -project $(PROJECT) -derivedDataPath $(DERIVED) -allowProvisioningUpdates -quiet \
               CURRENT_PROJECT_VERSION=$(BUILD_NUMBER)

# pipefail so a failing xcodebuild isn't masked by the output filter in `make test`.
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c

.DEFAULT_GOAL := help
.PHONY: icons help project widgets widgets-store restart-widgets mac mac-demo mac-build mac-dist ios-xcode screenshots store-art ios ios-demo ios-build device device-demo device-build \
        test sims devices clean

help:
	@echo "prdctv"
	@echo ""
	@echo "  make mac            Build and launch the Mac app"
	@echo "  make mac-demo       ...with sample data (in-memory, nothing saved)"
	@echo "  make ios            Run in Xcode on the $(SIM) simulator"
	@echo "  make ios-demo       ...with sample data"
	@echo "  make device         Build, install and launch on your iPhone"
	@echo "  make device-demo    ...with sample data"
	@echo "  make widgets        Make the Mac widget use the development build and restart it"
	@echo "  make widgets-store  Give the Mac widget back to the App Store copy"
	@echo "  make test           Run unit tests"
	@echo "  make mac-dist       Build the signed Mac App Store package for Transporter (build/dist)"
	@echo "  make ios-xcode      Open the project in Xcode to archive and upload the iOS app"
	@echo "  make screenshots    Capture App Store screenshots for iPhone, iPad and Mac (build/screenshots)"
	@echo "  make store-art      Make the App Store header and search results art (build/store-art)"
	@echo "  make sims           List simulators (use SIM=\"<name>\")"
	@echo "  make devices        List connected devices (use DEVICE=<identifier>)"
	@echo "  make project        Regenerate the Xcode project from project.yml"
	@echo "  make icons          Regenerate app icons and the logo mark (scripts/make_icons.py)"
	@echo "  make clean          Remove build output"

# --use-cache only regenerates when project.yml or the file list changed.
project:
	@xcodegen generate --use-cache --quiet

# MARK: Mac

mac-build: project
	$(XCODEBUILD) -scheme prdctv -destination 'platform=macOS,arch=arm64' build

mac: mac-build
	@pkill -x prdctv || true
	open $(MAC_APP)
	@$(MAKE) --no-print-directory widgets

mac-demo: mac-build
	@pkill -x prdctv || true
	open $(MAC_APP) --args --demo
	@$(MAKE) --no-print-directory widgets

# A running widget process keeps its old code, so restart it and chronod, which launchd brings back.
STORE_APP := /Applications/prdctv.app

# Makes the development build own the Mac widget. Every other copy with the same app ID is set aside,
# including the App Store copy in /Applications. `make widgets-store` switches back.
widgets:
	@for app in $$(find $(CURDIR)/$(DERIVED) ~/Library/Developer/Xcode/DerivedData ~/.Trash -name prdctv.app -prune 2>/dev/null \
		| grep -v '^$(CURDIR)/$(MAC_APP)$$' | grep -v iphone) $(STORE_APP); do \
		[ -e "$$app/Contents/PlugIns" ] && for ext in "$$app"/Contents/PlugIns/*.appex; do pluginkit -r "$$ext" 2>/dev/null; done; \
		$(LSREGISTER) -u "$$app" 2>/dev/null || true; done
	@$(LSREGISTER) -f -R $(MAC_APP)
	@pluginkit -a $(MAC_APP)/Contents/PlugIns/prdctvWidget.appex
	@$(MAKE) --no-print-directory restart-widgets
	@echo "Widgets now come from the development build. Run make widgets-store to go back to the App Store copy."

# Gives the widget back to the App Store copy in /Applications.
widgets-store:
	@[ -d $(STORE_APP) ] || (echo "No App Store copy at $(STORE_APP)" && exit 1)
	@pluginkit -r $(MAC_APP)/Contents/PlugIns/prdctvWidget.appex 2>/dev/null || true
	@$(LSREGISTER) -u $(CURDIR)/$(MAC_APP) 2>/dev/null || true
	@$(LSREGISTER) -f -R $(STORE_APP)
	@pluginkit -a $(STORE_APP)/Contents/PlugIns/prdctvWidget.appex
	@$(MAKE) --no-print-directory restart-widgets
	@echo "Widgets now come from the App Store copy."

restart-widgets:
	@pkill -f 'prdctvWidget.appex/Contents/MacOS/prdctvWidget' || true
	@killall chronod 2>/dev/null || true
	@echo "Widgets restarted"
	@/bin/sleep 5; if /usr/bin/log show --last 10s --style compact --predicate 'process == "prdctvWidget"' 2>/dev/null \
		| grep -q "Request ended.*error"; then \
		echo "A widget reload failed. See /usr/bin/log show --last 1m --predicate 'process == \"prdctvWidget\"'"; fi

# MARK: iOS Simulator

ios-build: project
	$(XCODEBUILD) -scheme prdctviOS -destination 'platform=iOS Simulator,name=$(SIM)' build


# Xcode 27 has no separate Simulator app, so Xcode runs the app to show the simulator.
# The first run asks to allow controlling Xcode (System Settings → Privacy & Security → Automation).
ios: project
	@osascript scripts/run_in_xcode.applescript "$(CURDIR)/$(PROJECT)" prdctviOS "$(SIM)"

ios-demo: project
	@osascript scripts/run_in_xcode.applescript "$(CURDIR)/$(PROJECT)" prdctviOS "$(SIM)" --demo

# MARK: iOS device

device-build: project
	$(XCODEBUILD) -scheme prdctviOS -destination 'generic/platform=iOS' build

define launch_device
	@test -n "$(DEVICE)" || (echo "No paired device found. Connect and unlock your iPhone, or pass DEVICE=<id> (see make devices)." && exit 1)
	xcrun devicectl device install app --device $(DEVICE) $(DEVICE_APP)
	xcrun devicectl device process launch --device $(DEVICE) --terminate-existing $(BUNDLE_ID) $(1)
endef

device: device-build
	$(call launch_device,)

device-demo: device-build
	$(call launch_device,--demo)

# MARK: App Store

ARCHIVES := $(DERIVED)/archives
DIST     := $(DERIVED)/dist

# Mac App Store package for Transporter. The app is signed with Apple Distribution and the
# package with the Mac installer certificate, using the Production iCloud environment.
mac-dist: project
	xcodebuild -project $(PROJECT) -configuration Release -allowProvisioningUpdates -quiet \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) archive \
		-scheme prdctv -destination 'generic/platform=macOS' -archivePath $(ARCHIVES)/prdctv-mac.xcarchive
	@# The archive's copy of the app would otherwise take over the development widget.
	@$(LSREGISTER) -u $(CURDIR)/$(ARCHIVES)/prdctv-mac.xcarchive/Products/Applications/prdctv.app 2>/dev/null || true
	@rm -rf $(DIST)
	xcodebuild -exportArchive -allowProvisioningUpdates -archivePath $(ARCHIVES)/prdctv-mac.xcarchive \
		-exportOptionsPlist release/ExportOptions.plist -exportPath $(DIST)
	@scripts/check_mac_package.sh $(DIST)/prdctv.pkg
	@echo "Ready for Transporter: $(DIST)/prdctv.pkg (version $$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' $(ARCHIVES)/prdctv-mac.xcarchive/Products/Applications/prdctv.app/Contents/Info.plist), build $(BUILD_NUMBER))"

# Opens the project in Xcode to archive and upload the iOS app from the Organizer.
ios-xcode: project
	open $(PROJECT)

screenshots: project
	scripts/screenshots.sh

# Product page header (3840x1646) and search results art (3840x2560) from fresh iPhone screenshots.
store-art: ios-build
	@scripts/store_art.sh

# MARK: Other

# Separate build folder: this build is unsigned, and sharing $(DERIVED) would replace the
# signed app that `make mac` launches (it would then lose App Group and iCloud access).
test: project
	xcodebuild -project $(PROJECT) -derivedDataPath $(DERIVED)/test -scheme prdctv \
		-destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "^(✔|✘|◇ Test run)|error:|TEST (SUCCEEDED|FAILED)"
	@$(LSREGISTER) -u $(CURDIR)/$(DERIVED)/test/Build/Products/Debug/prdctv.app 2>/dev/null || true

icons:
	python3 scripts/make_icons.py

sims:
	@xcrun simctl list devices available | grep -E 'iPhone|iPad'

devices:
	@xcrun devicectl list devices

clean:
	rm -rf $(DERIVED)
