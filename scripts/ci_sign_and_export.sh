#!/bin/bash
# Signs and exports an installable IPA in CI. Requires these repository secrets:
#   BUILD_CERTIFICATE_BASE64      base64 of your .p12 signing certificate
#   P12_PASSWORD                  password for the .p12
#   BUILD_PROVISION_PROFILE_BASE64 base64 of the matching .mobileprovision
#   KEYCHAIN_PASSWORD             any random string (temporary keychain)
#   TEAM_ID                       your Apple Developer Team ID
#   EXPORT_METHOD (optional)      release-testing (ad hoc, default), debugging, or app-store-connect
set -euo pipefail

METHOD="${EXPORT_METHOD:-release-testing}"
KEYCHAIN="$RUNNER_TEMP/signing.keychain-db"
CERT="$RUNNER_TEMP/cert.p12"
PROFILE="$RUNNER_TEMP/profile.mobileprovision"

echo "$BUILD_CERTIFICATE_BASE64" | base64 --decode > "$CERT"
echo "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode > "$PROFILE"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$CERT" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychain -d user -s "$KEYCHAIN"

PROFILE_UUID=$(/usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin <<< "$(security cms -D -i "$PROFILE")")
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c 'Print Name' /dev/stdin <<< "$(security cms -D -i "$PROFILE")")
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PROFILE" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"

xcodebuild archive \
  -project CozyShopkeeper.xcodeproj -scheme CozyShopkeeper -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Signed.xcarchive \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Distribution" PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME" \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN"

sed -e "s/__METHOD__/$METHOD/" -e "s/__TEAM__/$TEAM_ID/" -e "s/__PROFILE__/$PROFILE_NAME/" \
  scripts/ExportOptions.template.plist > build/ExportOptions.plist

xcodebuild -exportArchive -archivePath build/Signed.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export

cp build/export/*.ipa artifacts/Cozy-Shopkeeper.ipa
codesign -dv --verbose=2 build/Signed.xcarchive/Products/Applications/CozyShopkeeper.app 2>&1 | grep -E "Authority|TeamIdentifier|Identifier" || true
security delete-keychain "$KEYCHAIN" || true
rm -f "$CERT" "$PROFILE"
