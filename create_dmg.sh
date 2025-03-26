#!/bin/bash

# Script to create a notarized disk image for Janet.app
# Created: $(date)

# Exit on error
set -e

echo "Starting Janet.app DMG creation process..."

# Check if Janet.app exists
if [ ! -d "Builds/Janet.app" ]; then
    echo "Error: Janet.app not found in Builds directory."
    exit 1
fi

# Variables
APP_NAME="Janet"
DMG_NAME="${APP_NAME}_$(date +%Y%m%d)"
DMG_TEMP_NAME="${DMG_NAME}_temp.dmg"
DMG_FINAL_NAME="${DMG_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
SOURCE_APP="Builds/${APP_NAME}.app"
TEAM_ID="VV7N83X7GR"
APPLE_ID=""
APP_PASSWORD=""

# Check for Apple ID and app-specific password
if [ -z "$APPLE_ID" ]; then
    read -p "Enter your Apple ID: " APPLE_ID
fi

if [ -z "$APP_PASSWORD" ]; then
    read -s -p "Enter your app-specific password: " APP_PASSWORD
    echo
fi

# Create a temporary directory for DMG contents
echo "Creating temporary directory..."
TEMP_DIR=$(mktemp -d)
mkdir -p "${TEMP_DIR}/Applications"

# Copy the app to the temporary directory
echo "Copying ${APP_NAME}.app to temporary directory..."
cp -R "${SOURCE_APP}" "${TEMP_DIR}/"

# Create a symbolic link to /Applications
echo "Creating symbolic link to /Applications..."
ln -s /Applications "${TEMP_DIR}/Applications"

# Create the temporary DMG
echo "Creating temporary DMG..."
hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${TEMP_DIR}" -ov -format UDRW "${DMG_TEMP_NAME}"

# Clean up the temporary directory
rm -rf "${TEMP_DIR}"

# Convert the temporary DMG to the final DMG
echo "Converting temporary DMG to final DMG..."
hdiutil convert "${DMG_TEMP_NAME}" -format UDZO -o "${DMG_FINAL_NAME}"
rm "${DMG_TEMP_NAME}"

# Sign the DMG
echo "Signing the DMG..."
IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development: mfolk77@yahoo.com" | head -1 | awk '{print $2}')
codesign --sign "$IDENTITY" "${DMG_FINAL_NAME}"

# Notarize the DMG
echo "Submitting DMG for notarization..."
xcrun notarytool submit "${DMG_FINAL_NAME}" --apple-id "${APPLE_ID}" --password "${APP_PASSWORD}" --team-id "${TEAM_ID}" --wait

# Staple the notarization ticket
echo "Stapling notarization ticket to DMG..."
xcrun stapler staple "${DMG_FINAL_NAME}"

echo "DMG creation and notarization process completed successfully."
echo "Final DMG: ${DMG_FINAL_NAME}"

