# Build-and-run shortcuts. `make` with no target lists them.
#
#   make mac               build and launch the Mac app
#   make ios               build and launch in the iOS Simulator (SIM="iPhone 17 Pro")
#   make device            build, install and launch on a connected iPhone (DEVICE=<id>)
#   add -demo to any of those for sample data in a throwaway store, e.g. `make ios-demo`

PROJECT   := TicketBoard.xcodeproj
DERIVED   := build
BUNDLE_ID := com.jonathanlee.TicketBoard
SIM       ?= iPhone 17 Pro
# First paired, available iPhone/iPad. Override with DEVICE=<identifier> (see `make devices`).
DEVICE    ?= $(shell xcrun devicectl list devices 2>/dev/null | grep 'available (paired)' | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1)

MAC_APP     := $(DERIVED)/Build/Products/Debug/prdctv.app
SIM_APP     := $(DERIVED)/Build/Products/Debug-iphonesimulator/prdctv.app
DEVICE_APP  := $(DERIVED)/Build/Products/Debug-iphoneos/prdctv.app
XCODEBUILD  := xcodebuild -project $(PROJECT) -derivedDataPath $(DERIVED) -allowProvisioningUpdates -quiet

# pipefail so a failing xcodebuild isn't masked by the output filter in `make test`.
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c

.DEFAULT_GOAL := help
.PHONY: icons help project mac mac-demo mac-build ios ios-demo ios-build device device-demo device-build \
        test sims devices clean

help:
	@echo "prdctv"
	@echo ""
	@echo "  make mac            Build and launch the Mac app"
	@echo "  make mac-demo       ...with sample data (in-memory, nothing saved)"
	@echo "  make ios            Build and launch in the Simulator ($(SIM))"
	@echo "  make ios-demo       ...with sample data"
	@echo "  make device         Build, install and launch on your iPhone"
	@echo "  make device-demo    ...with sample data"
	@echo "  make test           Run unit tests"
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
	$(XCODEBUILD) -scheme TicketBoard -destination 'platform=macOS,arch=arm64' build

mac: mac-build
	@pkill -x prdctv || true
	open $(MAC_APP)

mac-demo: mac-build
	@pkill -x prdctv || true
	open $(MAC_APP) --args --demo

# MARK: iOS Simulator

ios-build: project
	$(XCODEBUILD) -scheme TicketBoardiOS -destination 'platform=iOS Simulator,name=$(SIM)' build

define launch_sim
	@xcrun simctl boot "$(SIM)" 2>/dev/null || true
	@open -a Simulator
	xcrun simctl install "$(SIM)" $(SIM_APP)
	xcrun simctl launch --terminate-running-process "$(SIM)" $(BUNDLE_ID) $(1)
endef

ios: ios-build
	$(call launch_sim,)

ios-demo: ios-build
	$(call launch_sim,--demo)

# MARK: iOS device

device-build: project
	$(XCODEBUILD) -scheme TicketBoardiOS -destination 'generic/platform=iOS' build

define launch_device
	@test -n "$(DEVICE)" || (echo "No paired device found. Connect and unlock your iPhone, or pass DEVICE=<id> (see make devices)." && exit 1)
	xcrun devicectl device install app --device $(DEVICE) $(DEVICE_APP)
	xcrun devicectl device process launch --device $(DEVICE) --terminate-existing $(BUNDLE_ID) $(1)
endef

device: device-build
	$(call launch_device,)

device-demo: device-build
	$(call launch_device,--demo)

# MARK: Other

# Separate build folder: this build is unsigned, and sharing $(DERIVED) would replace the
# signed app that `make mac` launches (it would then lose App Group and iCloud access).
test: project
	xcodebuild -project $(PROJECT) -derivedDataPath $(DERIVED)/test -scheme TicketBoard \
		-destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "^(✔|✘|◇ Test run)|error:|TEST (SUCCEEDED|FAILED)"

icons:
	python3 scripts/make_icons.py

sims:
	@xcrun simctl list devices available | grep -E 'iPhone|iPad'

devices:
	@xcrun devicectl list devices

clean:
	rm -rf $(DERIVED)
