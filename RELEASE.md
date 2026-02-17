# Releasing Bezel

## Prerequisites

- Xcode 16+ with command line tools
- An Apple Developer account (for signing and notarization)
- `xcodegen` installed (`brew install xcodegen`)
- `create-dmg` installed (`brew install create-dmg`) — optional, for DMG packaging

## 1. Bump the version

Update `Bezel/Info.plist`:

```xml
<key>CFBundleVersion</key>
<string>2</string>                <!-- build number, increment each release -->
<key>CFBundleShortVersionString</key>
<string>1.1</string>              <!-- user-facing version -->
```

## 2. Regenerate the Xcode project

```bash
xcodegen generate
```

## 3. Build a release archive

```bash
xcodebuild -project Bezel.xcodeproj \
  -scheme Bezel \
  -configuration Release \
  -archivePath dist/Bezel.xcarchive \
  archive
```

## 4. Export the app bundle

```bash
xcodebuild -exportArchive \
  -archivePath dist/Bezel.xcarchive \
  -exportPath dist/ \
  -exportOptionsPlist ExportOptions.plist
```

If you don't have an `ExportOptions.plist`, create one:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

Replace `YOUR_TEAM_ID` with your Apple Developer Team ID.

### Ad-hoc (unsigned) export

For local distribution without an Apple Developer account, skip the export step and copy the app directly from the archive:

```bash
cp -R dist/Bezel.xcarchive/Products/Applications/Bezel.app dist/Bezel.app
```

## 5. Code signing

### Sign with Developer ID (recommended for distribution)

```bash
codesign --force --deep --options runtime \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  dist/Bezel.app
```

### Verify the signature

```bash
codesign --verify --deep --strict --verbose=2 dist/Bezel.app
spctl --assess --type execute --verbose dist/Bezel.app
```

## 6. Notarization

Notarization is required for macOS apps distributed outside the Mac App Store (Gatekeeper will block unnotarized apps on macOS 10.15+).

### Create a ZIP for notarization

```bash
ditto -c -k --keepParent dist/Bezel.app dist/Bezel.zip
```

### Submit for notarization

```bash
xcrun notarytool submit dist/Bezel.zip \
  --apple-id "swairshah@gmail.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
```

The `APPLE_APP_PASSWORD` env var should contain an app-specific password generated at [appleid.apple.com](https://appleid.apple.com/account/manage) under **Sign-In and Security > App-Specific Passwords**.

### Staple the notarization ticket

```bash
xcrun stapler staple dist/Bezel.app
```

## 7. Package as DMG (optional)

```bash
create-dmg \
  --volname "Bezel" \
  --volicon "assets/app-icon.png" \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "Bezel.app" 150 200 \
  --app-drop-link 450 200 \
  --hide-extension "Bezel.app" \
  "dist/Bezel.dmg" \
  "dist/Bezel.app"
```

## 8. Create a GitHub release

```bash
# Tag the release
git tag -a v1.1 -m "Release v1.1"
git push origin v1.1

# Create the release with the DMG attached
gh release create v1.1 dist/Bezel.dmg \
  --title "Bezel v1.1" \
  --notes "Release notes here"
```

Or attach a ZIP instead of a DMG:

```bash
gh release create v1.1 dist/Bezel.zip \
  --title "Bezel v1.1" \
  --notes "Release notes here"
```

## Quick release (unsigned, local only)

For quick local builds without signing or notarization:

```bash
xcodebuild -project Bezel.xcodeproj -scheme Bezel -configuration Release build
cp -R ~/Library/Developer/Xcode/DerivedData/Bezel-*/Build/Products/Release/Bezel.app dist/
```

The app will show an "unidentified developer" warning on first launch. Users can right-click > Open to bypass this.
