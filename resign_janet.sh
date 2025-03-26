#!/bin/bash

# Script to re-sign Janet.app with the proper entitlements
# Created: $(date)

# Exit on error
set -e

echo "Starting Janet.app re-signing process..."

# Check if Janet.app exists
if [ ! -d "Builds/Janet.app" ]; then
    echo "Error: Janet.app not found in Builds directory."
    exit 1
fi

# Check if entitlements file exists
if [ ! -f "janet_entitlements.plist" ]; then
    echo "Error: janet_entitlements.plist not found."
    exit 1
fi

# Get the signing identity
IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development: mfolk77@yahoo.com" | head -1 | awk '{print $2}')

if [ -z "$IDENTITY" ]; then
    echo "Error: Could not find appropriate signing identity."
    echo "Available identities:"
    security find-identity -v -p codesigning
    exit 1
fi

echo "Using signing identity: $IDENTITY"

# Re-sign the app
echo "Re-signing Janet.app..."
codesign --force --deep --sign "$IDENTITY" --entitlements janet_entitlements.plist Builds/Janet.app

# Verify the signature
echo "Verifying signature..."
codesign -v Builds/Janet.app

# Display the entitlements
echo "Current entitlements:"
codesign -d --entitlements :- Builds/Janet.app

echo "Re-signing process completed successfully." 