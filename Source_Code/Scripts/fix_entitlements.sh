#!/bin/bash

# fix_entitlements.sh
# Script to fix entitlements issues in the Janet Xcode project

echo "Janet Entitlements Fix Script"
echo "============================"
echo

# Set the base directory
BASE_DIR="/Volumes/Folk_DAS/Janet_25"
cd "$BASE_DIR" || { echo "Error: Cannot change to $BASE_DIR directory"; exit 1; }

# Create Janet directory if it doesn't exist
if [ ! -d "$BASE_DIR/Janet" ]; then
    echo "Creating Janet directory..."
    mkdir -p "$BASE_DIR/Janet"
    echo "✅ Janet directory created"
else
    echo "✅ Janet directory already exists"
fi

# Copy entitlements file if it doesn't exist in Janet directory
if [ ! -f "$BASE_DIR/Janet/Janet.entitlements" ]; then
    if [ -f "$BASE_DIR/Janet.entitlements" ]; then
        echo "Copying entitlements file to Janet directory..."
        cp "$BASE_DIR/Janet.entitlements" "$BASE_DIR/Janet/"
        echo "✅ Entitlements file copied"
    elif [ -f "$BASE_DIR/Source/Janet.entitlements" ]; then
        echo "Copying entitlements file from Source directory..."
        cp "$BASE_DIR/Source/Janet.entitlements" "$BASE_DIR/Janet/"
        echo "✅ Entitlements file copied from Source directory"
    else
        echo "❌ Error: Janet.entitlements file not found"
        exit 1
    fi
else
    echo "✅ Entitlements file already exists in Janet directory"
fi

# Copy source files if they don't exist
if [ ! -f "$BASE_DIR/Janet/JanetApp.swift" ]; then
    echo "Copying source files to Janet directory..."
    cp -r "$BASE_DIR/Source/"* "$BASE_DIR/Janet/"
    echo "✅ Source files copied"
else
    echo "✅ Source files already exist in Janet directory"
fi

# Verify the structure
echo
echo "Verifying project structure..."
if [ -f "$BASE_DIR/Janet/Janet.entitlements" ] && [ -f "$BASE_DIR/Janet/JanetApp.swift" ]; then
    echo "✅ Project structure is correct"
    echo
    echo "The entitlements issue has been fixed. You can now build the project in Xcode."
    echo "If you still encounter issues, try cleaning the build folder (Product > Clean Build Folder) and rebuilding."
else
    echo "❌ Error: Project structure verification failed"
    echo "Please check the project structure manually."
fi

echo
echo "Done!" 