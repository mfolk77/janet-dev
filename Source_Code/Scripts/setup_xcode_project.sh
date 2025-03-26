#!/bin/bash

echo "Janet Xcode Project Setup Script"
echo "================================"
echo

# Define paths
JANET_DIR="/Volumes/Folk_DAS/Janet_25"
SOURCE_DIR="$JANET_DIR/Source"
XCODE_TEMPLATE="$JANET_DIR/xcode_template"

# Check if Source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found at $SOURCE_DIR"
    exit 1
fi

echo "This script will help you set up a new Xcode project for Janet."
echo "It will create a template project that you can use as a starting point."
echo

# Create a directory for the Xcode template
mkdir -p "$XCODE_TEMPLATE"

# Create a basic Info.plist file
cat > "$XCODE_TEMPLATE/Info.plist" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.FolkAI.Janet</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 FolkAI. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOL

echo "Created Info.plist template"

# Create a basic entitlements file
cat > "$XCODE_TEMPLATE/Janet.entitlements" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
EOL

echo "Created entitlements template"

echo
echo "Template files have been created in $XCODE_TEMPLATE"
echo
echo "Next steps:"
echo "1. Open Xcode and create a new macOS App project"
echo "2. Name it 'Janet' with organization identifier 'com.FolkAI'"
echo "3. Choose SwiftUI for the interface and Swift for the language"
echo "4. Save the project in $JANET_DIR"
echo "5. Delete the auto-generated files (ContentView.swift, etc.)"
echo "6. Add the files from $SOURCE_DIR to your project"
echo "7. Replace the Info.plist with the template from $XCODE_TEMPLATE/Info.plist"
echo "8. Add the entitlements file from $XCODE_TEMPLATE/Janet.entitlements"
echo "9. Add the SQLite.swift package (version 0.14.1) to your project"
echo
echo "For detailed instructions, refer to the README.txt file."
echo
echo "Setup complete!" 