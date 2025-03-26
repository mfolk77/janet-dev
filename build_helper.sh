#!/bin/bash

# Script to build and install the JanetHelper tool
# Created: $(date)

# Exit on error
set -e

echo "Building and installing JanetHelper tool..."

# Check if JanetHelper directory exists
if [ ! -d "JanetHelper" ]; then
    echo "Error: JanetHelper directory not found."
    exit 1
fi

# Navigate to JanetHelper directory
cd JanetHelper

# Build the helper tool
echo "Building JanetHelper..."
make

# Install the helper tool (requires sudo)
echo "Installing JanetHelper (requires sudo)..."
sudo make install

# Return to the original directory
cd ..

echo "JanetHelper built and installed successfully."
echo ""
echo "You can now use the helper tool for operations requiring root privileges."
echo "Example usage:"
echo "  sudo /Library/PrivilegedHelperTools/com.FolkAI.JanetHelper/JanetHelper exec \"command\""
echo "  sudo /Library/PrivilegedHelperTools/com.FolkAI.JanetHelper/JanetHelper chmod 755 /path/to/file"
echo "  sudo /Library/PrivilegedHelperTools/com.FolkAI.JanetHelper/JanetHelper chown 501 20 /path/to/file" 