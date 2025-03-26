# Janet Distribution Guide

This document provides instructions for signing, notarizing, and distributing the Janet AI Assistant application.

## Prerequisites

- macOS development environment
- Apple Developer account
- Xcode command line tools installed
- Valid code signing certificates

## Signing Janet.app

The `resign_janet.sh` script automates the process of re-signing Janet.app with the proper entitlements.

### Usage

```bash
./resign_janet.sh
```

This script will:
1. Check if Janet.app exists in the Builds directory
2. Find the appropriate signing identity
3. Re-sign the app with the entitlements specified in `janet_entitlements.plist`
4. Verify the signature and display the current entitlements

## Creating a Notarized DMG

The `create_dmg.sh` script creates a notarized disk image for distribution.

### Usage

```bash
./create_dmg.sh
```

You will be prompted to enter:
- Your Apple ID
- Your app-specific password (generated from appleid.apple.com)

This script will:
1. Create a temporary DMG with Janet.app and a link to /Applications
2. Convert it to a compressed DMG
3. Sign the DMG with your developer certificate
4. Submit the DMG for notarization to Apple
5. Staple the notarization ticket to the DMG

The final DMG will be named `Janet_YYYYMMDD.dmg` with the current date.

## Entitlements

The `janet_entitlements.plist` file contains the following entitlements:

- App Sandbox
- Microphone access
- User-selected file access (read-only and read-write)
- Network client and server capabilities
- Apple Events automation
- Personal information access (address book, calendars, location)
- Printing capabilities

## Export Options

The `export.plist` file contains the export options for archiving the app, including:

- Development signing method
- Team ID
- Automatic signing style
- Provisioning profile information

## Troubleshooting

### Signing Issues

If you encounter signing issues:

1. Check that your certificates are valid:
   ```bash
   security find-identity -v -p codesigning
   ```

2. Verify that the entitlements file is correctly formatted:
   ```bash
   plutil -lint janet_entitlements.plist
   ```

### Notarization Issues

If notarization fails:

1. Check the notarization log:
   ```bash
   xcrun notarytool log [REQUEST_UUID] --apple-id [YOUR_APPLE_ID] --password [APP_PASSWORD] --team-id [TEAM_ID]
   ```

2. Ensure your app meets Apple's notarization requirements:
   - Signed with a Developer ID certificate
   - Includes a secure timestamp
   - Includes hardened runtime entitlements
   - Does not contain unsigned executable code 