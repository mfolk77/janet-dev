#!/bin/bash

# Fix NavigationState Redeclaration Script
echo "🔧 Fixing NavigationState redeclaration issue..."

# Define paths
SOURCE_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Source"
JANET_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Janet"

# Ensure the Models directory exists
mkdir -p "$JANET_DIR/Models"

# Copy the latest NavigationState.swift file
echo "📄 Copying NavigationState.swift..."
cp "$SOURCE_DIR/Models/NavigationState.swift" "$JANET_DIR/Models/"

# Set proper permissions
chmod 644 "$JANET_DIR/Models/NavigationState.swift"

echo "✅ NavigationState fix completed!"
echo "You can now build the app without the redeclaration error." 