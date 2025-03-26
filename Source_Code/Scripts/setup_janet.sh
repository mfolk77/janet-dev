#!/bin/bash

echo "Janet Setup Script"
echo "================="
echo

# Define paths
JANET_DIR="/Volumes/Folk_DAS/Janet_25"
SOURCE_DIR="$JANET_DIR/Source"
XCODE_TEMPLATE="$JANET_DIR/xcode_template"
BUILD_DIR="$JANET_DIR/build"

# Check if Source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found at $SOURCE_DIR"
    exit 1
fi

echo "This script will help you set up Janet with the correct file structure."
echo

# Create necessary directories
mkdir -p "$XCODE_TEMPLATE"
mkdir -p "$BUILD_DIR"

# Step 1: Create template files
echo "Step 1: Creating template files..."

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

echo "Template files created successfully."

# Step 2: Check if Xcode project exists
echo
echo "Step 2: Checking Xcode project..."

if [ -d "$JANET_DIR/Janet.xcodeproj" ]; then
    echo "Found existing Xcode project at $JANET_DIR/Janet.xcodeproj"
    
    # Backup the project file
    echo "Creating backup of project.pbxproj..."
    cp "$JANET_DIR/Janet.xcodeproj/project.pbxproj" "$JANET_DIR/Janet.xcodeproj/project.pbxproj.backup.$(date +%Y%m%d%H%M%S)"
    
    echo "You may need to update the file paths in the Xcode project to point to the correct locations."
    echo "See the README.txt for instructions on setting up the project in Xcode."
else
    echo "No existing Xcode project found."
    echo "You will need to create a new Xcode project. See the README.txt for instructions."
fi

# Step 3: Check if SQLite.swift package is installed
echo
echo "Step 3: Checking for SQLite.swift package..."
echo "You will need to add the SQLite.swift package (version 0.14.1) to your Xcode project."
echo "See the README.txt for instructions on adding the package."

# Step 4: Verify run_janet.sh script
echo
echo "Step 4: Verifying run_janet.sh script..."

if [ -f "$JANET_DIR/run_janet.sh" ]; then
    echo "Found run_janet.sh script."
    
    # Make sure it's executable
    chmod +x "$JANET_DIR/run_janet.sh"
    echo "Made run_janet.sh executable."
else
    echo "Error: run_janet.sh script not found."
    exit 1
fi

# Step 5: Verify Launch Janet.command
echo
echo "Step 5: Verifying Launch Janet.command..."

if [ -f "$JANET_DIR/Launch Janet.command" ]; then
    echo "Found Launch Janet.command script."
    
    # Make sure it's executable
    chmod +x "$JANET_DIR/Launch Janet.command"
    echo "Made Launch Janet.command executable."
else
    echo "Error: Launch Janet.command script not found."
    exit 1
fi

# Step 6: Check for cleanup script
echo
echo "Step 6: Checking for cleanup script..."

if [ -f "$JANET_DIR/cleanup_old_janet.sh" ]; then
    echo "Found cleanup_old_janet.sh script."
    
    # Make sure it's executable
    chmod +x "$JANET_DIR/cleanup_old_janet.sh"
    echo "Made cleanup_old_janet.sh executable."
else
    echo "Warning: cleanup_old_janet.sh script not found."
    echo "You may want to create this script to help clean up old Janet directories."
fi

echo
echo "Setup complete!"
echo
echo "Next steps:"
echo "1. Follow the instructions in README.txt to set up the Xcode project"
echo "2. Build and run the app using run_janet.sh or Launch Janet.command"
echo "3. If needed, clean up old directories using cleanup_old_janet.sh"
echo
echo "For detailed instructions, refer to the README.txt file." 