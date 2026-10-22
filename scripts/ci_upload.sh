#!/bin/bash
# Validates and uploads the App Store IPA to App Store Connect (it then appears in TestFlight).
# Needs the app record to exist in App Store Connect for bundle ID com.surproductions.cozyshopkeeper.
set -euo pipefail
IPA=artifacts/Cozy-Shopkeeper-AppStore.ipa
test -f "$IPA"
xcrun altool --validate-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" --output-format normal
xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" --output-format normal
echo "UPLOAD_OK"
