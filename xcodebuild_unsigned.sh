#!/bin/bash

xcodebuild -project SwTgWs.xcodeproj \
    -scheme TgWsProxy \
    -destination 'generic/platform=iOS' \
    -configuration Release \
    -archivePath packages/TgWsProxy.xcarchive \
    archive \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    GCC_WARN_INHIBIT_ALL_WARNINGS=YES

mkdir -p packages/Payload
cp -r packages/TgWsProxy.xcarchive/Products/Applications/TgWsProxy.app packages/Payload
cd packages && zip -r TgWsProxy-unsigned.ipa Payload/
rm -rf Payload
