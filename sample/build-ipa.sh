#!/usr/bin/env bash
set -euo pipefail

test "$(uname -m)" = arm64
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$repo_dir/build/ipa"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

bundle="$stage/Payload/ARMSample.app"
mkdir -p "$bundle" "$output_dir"
cp "$repo_dir/sample/Info.plist" "$bundle/Info.plist"
sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos swiftc -parse-as-library -module-name ARMSample \
  -sdk "$sdk" -target arm64-apple-ios16.0 \
  "$repo_dir/sample/ARMSample.swift" -o "$bundle/ARMSample"

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
(cd "$output_dir" && shasum -a 256 ARMSample-unsigned.ipa > SHA256SUMS && shasum -a 256 -c SHA256SUMS)
echo 'ios_arm64_ipa=verified'
