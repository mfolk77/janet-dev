#!/bin/bash

# Fix build issues script for Janet
echo "🔧 Starting Janet build fixes..."

# Define paths
SOURCE_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Source"
JANET_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Janet"
ENTITLEMENTS_FILE="Janet.entitlements"

# Create Janet directory if it doesn't exist
if [ ! -d "$JANET_DIR" ]; then
  echo "📁 Creating Janet directory..."
  mkdir -p "$JANET_DIR"
fi

# Create necessary subdirectories
mkdir -p "$JANET_DIR/Models"
mkdir -p "$JANET_DIR/Services"
mkdir -p "$JANET_DIR/Services/Memory"
mkdir -p "$JANET_DIR/Views"

# Copy entitlements file
echo "📄 Copying entitlements file..."
cp "$SOURCE_DIR/$ENTITLEMENTS_FILE" "$JANET_DIR/$ENTITLEMENTS_FILE"

# Copy model files
echo "📄 Copying model files..."
cp "$SOURCE_DIR/Models/"*.swift "$JANET_DIR/Models/"

# Copy service files
echo "📄 Copying service files..."
cp "$SOURCE_DIR/Services/"*.swift "$JANET_DIR/Services/"
cp "$SOURCE_DIR/Services/Memory/"*.swift "$JANET_DIR/Services/Memory/"

# Copy view files
echo "📄 Copying view files..."
cp "$SOURCE_DIR/Views/"*.swift "$JANET_DIR/Views/"

# Copy app file
echo "📄 Copying app file..."
cp "$SOURCE_DIR/JanetApp.swift" "$JANET_DIR/"

# Fix permissions
echo "🔒 Setting file permissions..."
chmod -R 644 "$JANET_DIR"/*.swift "$JANET_DIR"/*/*.swift "$JANET_DIR"/*/*/*.swift
chmod 644 "$JANET_DIR/$ENTITLEMENTS_FILE"

echo "✅ Build fixes completed!"
echo "You can now open the Xcode project and build the app."
echo "If you encounter any issues, please check the console output for errors." 