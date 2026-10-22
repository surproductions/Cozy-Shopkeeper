#!/bin/bash
# Archives, signs (Xcode cloud-managed automatic signing via an App Store Connect API key)
# and exports an App Store IPA. Uploading is done separately by ci_upload.sh.
#
# Required env (from repository secrets):
#   APPLE_TEAM_ID   10-character Team ID
#   ASC_KEY_ID      App Store Connect API key ID
#   ASC_ISSUER_ID   App Store Connect issuer ID
#   ASC_KEY_P8      contents of AuthKey_XXXX.p8 (raw PEM text or base64 of it)
#   BUILD_NUMBER    unique, increasing build number
set -euo pipefail

KEY_DIR="$HOME/.appstoreconnect/private_keys"
KEY_PATH="$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"
mkdir -p "$KEY_DIR"
python3 scripts/normalize_p8.py "$KEY_PATH"
openssl pkey -in "$KEY_PATH" -noout && echo "API key parses as a valid private key (key ID ${ASC_KEY_ID:0:4}…, team ${APPLE_TEAM_ID:0:3}…)"

AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

xcodebuild archive \
  -project CozyShopkeeper.xcodeproj -scheme CozyShopkeeper -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/AppStore.xcarchive \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" CODE_SIGN_STYLE=Automatic \
  "${AUTH[@]}"

cat > build/ExportOptions-AppStore.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>${APPLE_TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath build/AppStore.xcarchive \
  -exportOptionsPlist build/ExportOptions-AppStore.plist -exportPath build/appstore \
  "${AUTH[@]}"

cp build/appstore/*.ipa artifacts/Cozy-Shopkeeper-AppStore.ipa
mkdir -p build/verify && (cd build/verify && unzip -q -o ../../artifacts/Cozy-Shopkeeper-AppStore.ipa)
echo "--- Signature"
codesign -dv --verbose=2 build/verify/Payload/CozyShopkeeper.app 2>&1 | grep -E "Authority|TeamIdentifier|Identifier=" || true
codesign --verify --strict build/verify/Payload/CozyShopkeeper.app && echo "codesign verify: OK"
/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' build/verify/Payload/CozyShopkeeper.app/Info.plist
