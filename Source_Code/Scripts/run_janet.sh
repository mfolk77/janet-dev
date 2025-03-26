#!/bin/bash

# Janet Run Script
# This script builds and runs the Janet app

echo "=============================="
echo "  Running Janet GUI"
echo "=============================="

# Define paths
JANET_DIR="/Volumes/Folk_DAS/Janet_25"
XCODE_PROJECT="$JANET_DIR/Janet.xcodeproj"
BUILD_DIR="$JANET_DIR/build"
APP_PATH="$BUILD_DIR/Build/Products/Debug/Janet.app"

# Check if the fix script exists and run it if needed
if [ -f "$JANET_DIR/fix_janet_build.sh" ]; then
  echo "Running build fixes..."
  chmod +x "$JANET_DIR/fix_janet_build.sh"
  "$JANET_DIR/fix_janet_build.sh"
fi

# Build the app
echo "Building Janet..."
xcodebuild -project "$XCODE_PROJECT" -scheme Janet -configuration Debug -derivedDataPath "$BUILD_DIR" build

# Check if build was successful
if [ $? -eq 0 ]; then
  echo "Build successful!"
  
  # Check if the app exists
  if [ -d "$APP_PATH" ]; then
    echo "Found valid app at: $APP_PATH"
    
    # Kill any existing Janet processes
    pkill -f Janet || true
    
    # Launch the app
    echo "Launching Janet GUI..."
    open "$APP_PATH"
  else
    echo "Error: Could not find built app at $APP_PATH"
    exit 1
  fi
else
  echo "Error: Build failed. Check the Xcode project for errors."
  exit 1
fi

echo "==============================" 