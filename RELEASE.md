# Releasing Bezel

## 1. Bump version

Update `Bezel/Info.plist`:
- `CFBundleShortVersionString` — user-facing version (e.g., `0.1.4`)
- `CFBundleVersion` — increment build number

## 2. Build

```bash
xcodebuild -project Bezel.xcodeproj -scheme Bezel -configuration Release build
cp -R ~/Library/Developer/Xcode/DerivedData/Bezel-*/Build/Products/Release/Bezel.app dist/
```

## 3. Sign

```bash
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application" \
  dist/Bezel.app
```

## 4. Notarize

```bash
ditto -c -k --keepParent dist/Bezel.app dist/Bezel-VERSION.zip

xcrun notarytool submit dist/Bezel-VERSION.zip \
  --apple-id "$APPLE_EMAIL" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
```

If it fails, check the log:
```bash
xcrun notarytool log SUBMISSION_ID \
  --apple-id "$APPLE_EMAIL" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD"
```

## 5. Staple & re-zip

```bash
xcrun stapler staple dist/Bezel.app
rm dist/Bezel-VERSION.zip
ditto -c -k --keepParent dist/Bezel.app dist/Bezel-VERSION.zip
```

## 6. GitHub release

```bash
git tag -a vVERSION -m "Release vVERSION"
git push origin vVERSION

gh release create vVERSION dist/Bezel-VERSION.zip \
  --title "Bezel vVERSION" \
  --notes "Release notes"
```

## 7. Update Homebrew tap

```bash
# Get SHA
shasum -a 256 dist/Bezel-VERSION.zip

# Update ~/work/projects/homebrew-tap/Casks/bezel.rb with new version and SHA

cd ~/work/projects/homebrew-tap
git add Casks/bezel.rb
git commit -m "Update bezel to VERSION"
git push
```
