APP_NAME = QuotaLens
BUILD_DIR = .build/release
BUNDLE = $(APP_NAME).app
CONTENTS = $(BUNDLE)/Contents

.PHONY: build bundle run test clean install logos icon dmg

build:
	swift build -c release

test:
	swift test

# Regenerate Resources/AppIcon.icns from Resources/AppIconSource.png.
# The committed .icns means a normal build doesn't depend on this.
icon:
	rm -rf build/AppIcon.iconset && mkdir -p build/AppIcon.iconset
	@for pair in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" "512 512x512" "1024 512x512@2x"; do \
		set -- $$pair; sips -z $$1 $$1 Resources/AppIconSource.png --out build/AppIcon.iconset/icon_$$2.png >/dev/null; \
	done
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
	@echo "Wrote Resources/AppIcon.icns"

# Pull the official Claude/Codex marks from locally-installed apps (not
# redistributed in the repo). Missing apps just fall back to SF Symbols.
logos:
	@mkdir -p Resources
	@cp "/Applications/Claude.app/Contents/Resources/TrayIconTemplate.png"    Resources/ClaudeMark.png    2>/dev/null || echo "  Claude.app not found — Claude logo falls back to an SF Symbol"
	@cp "/Applications/Claude.app/Contents/Resources/TrayIconTemplate@2x.png" Resources/ClaudeMark@2x.png 2>/dev/null || true
	@cp "/Applications/Claude.app/Contents/Resources/TrayIconTemplate@3x.png" Resources/ClaudeMark@3x.png 2>/dev/null || true
	@cp "/Applications/Codex.app/Contents/Resources/codexTemplate.png"        Resources/CodexMark.png     2>/dev/null || echo "  Codex.app not found — Codex logo falls back to an SF Symbol"
	@cp "/Applications/Codex.app/Contents/Resources/codexTemplate@2x.png"     Resources/CodexMark@2x.png  2>/dev/null || true

bundle: build logos
	rm -rf $(BUNDLE)
	mkdir -p $(CONTENTS)/MacOS
	mkdir -p $(CONTENTS)/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(CONTENTS)/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	cp Resources/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	-cp Resources/*.png $(CONTENTS)/Resources/ 2>/dev/null
	@echo "Bundled $(BUNDLE)"

run: bundle
	open $(BUNDLE)

install: bundle
	rm -rf "/Applications/$(BUNDLE)"
	cp -R $(BUNDLE) /Applications/
	@echo "Installed /Applications/$(BUNDLE)"

# Build a drag-to-install DMG with the custom background. Needs `create-dmg`
# (brew install create-dmg). Icons are centred in the background's drop zones;
# the Applications link's label is hidden (a space-named symlink).
dmg: bundle
	rm -rf build/dmg-src build/QuotaLens.dmg
	mkdir -p build/dmg-src
	cp -R $(BUNDLE) build/dmg-src/
	-SetFile -a E "build/dmg-src/$(BUNDLE)"
	ln -s /Applications "build/dmg-src/ "
	sips -z 512 768 Resources/dmg-background.png --out build/dmg-bg.png >/dev/null
	create-dmg \
	  --volname "QuotaLens" \
	  --background "build/dmg-bg.png" \
	  --window-pos 200 120 --window-size 768 512 \
	  --icon-size 110 \
	  --icon "$(BUNDLE)" 220 262 \
	  --icon " " 548 262 \
	  --hide-extension "$(BUNDLE)" \
	  --no-internet-enable \
	  build/QuotaLens.dmg build/dmg-src/
	@echo "Built build/QuotaLens.dmg"

clean:
	rm -rf .build build $(BUNDLE)
