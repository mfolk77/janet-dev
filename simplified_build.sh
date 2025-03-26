#!/bin/bash
# Simplified Janet Build Script
# This script builds only the essential components of Janet

# Exit on any error
set -e

echo "=============================="
echo "  Building Janet (Simplified)"
echo "=============================="

# Define paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_DIR="$SCRIPT_DIR/Source_Code"
XCODE_PROJECT="$SOURCE_DIR/Janet.xcodeproj"
BUILD_DIR="$SCRIPT_DIR/build_tmp"
APP_PATH="$BUILD_DIR/Build/Products/Release/Janet.app"
DESTINATION_PATH="$SCRIPT_DIR/Builds/Janet.app"

# Check if the Xcode project exists
if [ ! -d "$XCODE_PROJECT" ]; then
    echo "Error: Xcode project not found at $XCODE_PROJECT"
    exit 1
fi

# Clean up before building
echo "Cleaning up before building..."
rm -rf "$BUILD_DIR"

# Build the app
echo "Building Janet..."
xcodebuild -project "$XCODE_PROJECT" -scheme Janet -configuration Release -derivedDataPath "$BUILD_DIR" build

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build successful!"
    
    # Check if the app exists
    if [ -d "$APP_PATH" ]; then
        echo "Found valid app at: $APP_PATH"
        
        # Kill any existing Janet processes
        echo "Stopping any running Janet instances..."
        pkill -f "Janet.app/Contents/MacOS/Janet" || true
        
        # Create Builds directory if it doesn't exist
        mkdir -p "$SCRIPT_DIR/Builds"
        
        # Remove the old app if it exists
        if [ -d "$DESTINATION_PATH" ]; then
            echo "Removing existing app..."
            rm -rf "$DESTINATION_PATH"
        fi
        
        # Copy the new app to the Builds directory
        echo "Installing new app..."
        cp -R "$APP_PATH" "$DESTINATION_PATH"
        
        # Clean up build directory to save space
        echo "Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
        
        echo "Janet app built and installed successfully!"
    else
        echo "Error: Could not find built app at $APP_PATH"
        exit 1
    fi
else
    echo "Error: Build failed. Check the Xcode project for errors."
    exit 1
fi

echo "=============================="
echo "  Build Complete"
echo "=============================="
echo "You can now run Janet using ./launch_janet.sh" 