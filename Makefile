APP_NAME = EzNote
BUNDLE_DIR = build/$(APP_NAME).app

.PHONY: build bundle run clean icon

icon:
	@Resources/build_icon.sh

build:
	swift build -c release

bundle: build
	@BIN_PATH=$$(swift build -c release --show-bin-path) && \
	mkdir -p "$(BUNDLE_DIR)/Contents/MacOS" && \
	mkdir -p "$(BUNDLE_DIR)/Contents/Resources" && \
	cp "$$BIN_PATH/$(APP_NAME)" "$(BUNDLE_DIR)/Contents/MacOS/$(APP_NAME)" && \
	cp Resources/Info.plist "$(BUNDLE_DIR)/Contents/Info.plist" && \
	cp Resources/AppIcon.icns "$(BUNDLE_DIR)/Contents/Resources/AppIcon.icns" && \
	echo "APPL????" > "$(BUNDLE_DIR)/Contents/PkgInfo" && \
	codesign --force --deep --sign - "$(BUNDLE_DIR)" 2>/dev/null || true && \
	xattr -cr "$(BUNDLE_DIR)" 2>/dev/null || true && \
	echo "✅ App bundle created at $(BUNDLE_DIR)"

run: bundle
	open "$(BUNDLE_DIR)"

debug:
	swift build
	@BIN_PATH=$$(swift build --show-bin-path) && \
	"$$BIN_PATH/$(APP_NAME)"

clean:
	swift package clean
	rm -rf build
