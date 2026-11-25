#!/usr/bin/env bash
set -euo pipefail

test "$(uname -m)" = arm64
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$repo_dir/build/ipa"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

archive="$stage/ARMSample.xcarchive"
xcodebuild -quiet archive \
  -project "$repo_dir/sample/ARMSample.xcodeproj" -scheme ARMSample \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$archive" -derivedDataPath "$stage/DerivedData" \
  ARCHS=arm64 CODE_SIGNING_ALLOWED=NO

plutil -lint "$archive/Info.plist"
app="$archive/Products/Applications/ARMSample.app"
test -x "$app/ARMSample"
mkdir -p "$stage/Payload" "$output_dir"
ditto "$app" "$stage/Payload/ARMSample.app"

artifact="$output_dir/ARMSample-unsigned.ipa"
(cd "$stage" && zip -q -X -r "ARMSample-unsigned.ipa" Payload)
mv "$stage/ARMSample-unsigned.ipa" "$artifact"
unzip -tq "$artifact"
unzip -p "$artifact" Payload/ARMSample.app/ARMSample > "$stage/executable"
unzip -p "$artifact" Payload/ARMSample.app/Info.plist > "$stage/Info.plist"
plutil -lint "$stage/Info.plist"
test "$(plutil -extract CFBundleExecutable raw -o - "$stage/Info.plist")" = ARMSample
test "$(xcrun lipo -archs "$stage/executable")" = arm64
xcrun vtool -show-build "$stage/executable" | grep -E 'platform[[:space:]]+IOS[[:space:]]*$'
ditto -c -k --keepParent "$archive" "$stage/ARMSample-unsigned.xcarchive.zip"
unzip -tq "$stage/ARMSample-unsigned.xcarchive.zip"
mv "$stage/ARMSample-unsigned.xcarchive.zip" "$output_dir/"
(cd "$output_dir" && shasum -a 256 ARMSample-unsigned.ipa ARMSample-unsigned.xcarchive.zip > SHA256SUMS && shasum -a 256 -c SHA256SUMS)
echo 'ios_arm64_ipa=verified'
