# Project Variables
PROJECT_NAME = SubScript
BUILD_TYPE = release
PROJECT_ROOT = $(shell pwd)
BUILD_DIR = $(PROJECT_ROOT)/.build/$(BUILD_TYPE)
APP_BUNDLE = $(BUILD_DIR)/$(PROJECT_NAME).app
METALLIB_SRC = $(PROJECT_ROOT)/.build/checkouts/speech-swift/.build/release/mlx.metallib
FFMPEG_BIN_DIR = $(PROJECT_ROOT)/Sources/SubScript/Resources/Binaries
FFMPEG_BIN = $(FFMPEG_BIN_DIR)/ffmpeg
ICON_SET = $(PROJECT_ROOT)/Sources/SubScript/Assets.xcassets/AppIcon.appiconset
DMG_OUT = $(PROJECT_ROOT)/$(PROJECT_NAME).dmg

# Commands
SWIFT = swift
XCODEBUILD = xcodebuild
Hdiutil = hdiutil

.PHONY: all setup metallib build bundle dmg clean

all: dmg

setup:
	@echo "=== Setting up Environment ==="
	@$(XCODEBUILD) -downloadComponent MetalToolchain || echo "Metal Toolchain already installed"
	@mkdir -p $(FFMPEG_BIN_DIR)
	@if [ ! -f $(FFMPEG_BIN) ]; then \
		echo "Downloading FFmpeg (Full Version)..."; \
		curl -L "https://evermeet.cx/ffmpeg/getrelease/zip" -o ffmpeg.zip; \
		unzip -o ffmpeg.zip; \
		mv ffmpeg $(FFMPEG_BIN); \
		chmod +x $(FFMPEG_BIN); \
		rm ffmpeg.zip; \
	else \
		echo "✓ FFmpeg already exists"; \
	fi
	@echo "=== Resolving SPM packages ==="
	@$(SWIFT) package resolve
	@echo "✓ Packages resolved"

metallib: setup
	@echo "=== Building MLX metallib ==="
	@cd $(PROJECT_ROOT)/.build/checkouts/speech-swift && \
	$(SWIFT) build -c release --disable-sandbox && \
	chmod +x scripts/build_mlx_metallib.sh && \
	./scripts/build_mlx_metallib.sh release
	@echo "✓ MLX metallib ready"

build: metallib
	@echo "=== Building $(PROJECT_NAME) ($(BUILD_TYPE)) ==="
	@$(SWIFT) build -c $(BUILD_TYPE) --disable-sandbox
	@cp $(METALLIB_SRC) $(BUILD_DIR)/mlx.metallib
	@echo "✓ Build complete"

bundle: build
	@echo "=== Creating App Bundle ==="
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(PROJECT_NAME) $(APP_BUNDLE)/Contents/MacOS/$(PROJECT_NAME)
	@chmod +x $(APP_BUNDLE)/Contents/MacOS/$(PROJECT_NAME)
	@cp $(METALLIB_SRC) $(APP_BUNDLE)/Contents/MacOS/
	@cp $(FFMPEG_BIN) $(APP_BUNDLE)/Contents/Resources/
	@cp -R $(PROJECT_ROOT)/Sources/SubScript/Resources/*.lproj $(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@cp $(ICON_SET)/* $(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/Resources/AppIcon.iconset
	@cp $(APP_BUNDLE)/Contents/Resources/icon_*.png $(APP_BUNDLE)/Contents/Resources/AppIcon.iconset/ 2>/dev/null || true
	@$(XCODEBUILD) -downloadComponent MetalToolchain 2>/dev/null || true
	@iconutil -c icns $(APP_BUNDLE)/Contents/Resources/AppIcon.iconset -o $(APP_BUNDLE)/Contents/Resources/AppIcon.icns 2>/dev/null || true
	@rm -rf $(APP_BUNDLE)/Contents/Resources/AppIcon.iconset $(APP_BUNDLE)/Contents/Resources/icon_*.png 2>/dev/null || true
	@$(PROJECT_ROOT)/generate_plist.sh $(APP_BUNDLE)/Contents/Info.plist
	@echo "✓ App bundle created: $(APP_BUNDLE)"

dmg: bundle
	@echo "=== Creating DMG Image ==="
	@rm -rf /tmp/SubScriptDMG
	@mkdir -p /tmp/SubScriptDMG
	@cp -R $(APP_BUNDLE) /tmp/SubScriptDMG/
	@ln -s /Applications /tmp/SubScriptDMG/Applications
	@$(Hdiutil) create -volname "$(PROJECT_NAME)" -srcfolder /tmp/SubScriptDMG -ov -format UDZO $(DMG_OUT)
	@rm -rf /tmp/SubScriptDMG
	@echo "✓ DMG created: $(DMG_OUT)"

clean:
	@echo "=== Cleaning build artifacts ==="
	@rm -rf .build
	@rm -f $(DMG_OUT)
	@echo "✓ Cleaned"
