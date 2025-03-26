#!/bin/bash

# Script to install the MCP system in the Janet application support directory
# Created: $(date)

# Exit on error
set -e

echo "===== Janet MCP System Installation ====="

# Define directories
JANET_APP_SUPPORT_DIR="$HOME/Library/Application Support/Janet"
MCP_SOURCE_DIR="$(pwd)/mcp-system"
MCP_DEST_DIR="$JANET_APP_SUPPORT_DIR/mcp-system"
MODELS_DIR="$JANET_APP_SUPPORT_DIR/models"
MEMORY_DIR="$JANET_APP_SUPPORT_DIR/memory"
LOGS_DIR="$JANET_APP_SUPPORT_DIR/logs"

# Check if the MCP source directory exists
if [ ! -d "$MCP_SOURCE_DIR" ]; then
    echo "Error: MCP source directory not found at $MCP_SOURCE_DIR"
    exit 1
fi

# Create the Janet application support directory if it doesn't exist
echo "Creating Janet application support directory..."
mkdir -p "$JANET_APP_SUPPORT_DIR"
mkdir -p "$MODELS_DIR"
mkdir -p "$MEMORY_DIR"
mkdir -p "$LOGS_DIR"

# Check if the MCP is already installed
if [ -d "$MCP_DEST_DIR" ]; then
    echo "MCP is already installed. Updating..."
    # Backup the existing MCP configuration
    if [ -d "$MCP_DEST_DIR/config" ]; then
        echo "Backing up existing MCP configuration..."
        cp -R "$MCP_DEST_DIR/config" "$JANET_APP_SUPPORT_DIR/config_backup_$(date +%Y%m%d%H%M%S)"
    fi
    
    # Remove the existing MCP directory
    rm -rf "$MCP_DEST_DIR"
else
    echo "Installing MCP for the first time..."
fi

# Copy the MCP system to the Janet application support directory
echo "Copying MCP system..."
cp -R "$MCP_SOURCE_DIR" "$MCP_DEST_DIR"

# Navigate to the MCP directory
cd "$MCP_DEST_DIR"

# Install dependencies
echo "Installing MCP dependencies..."
npm install

# Build the MCP system
echo "Building MCP system..."
npm run build || {
    echo "Building with npm run build failed, trying direct TypeScript compilation..."
    ./node_modules/.bin/tsc
}

# Check if the build was successful
if [ ! -d "dist" ]; then
    echo "Error: MCP build failed. dist directory not found."
    exit 1
fi

# Create a launchd plist file for auto-starting the MCP
echo "Creating launchd plist file..."
cat > "$HOME/Library/LaunchAgents/com.janet.mcp.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.janet.mcp</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>$MCP_DEST_DIR/dist/index.js</string>
        <string>server</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOGS_DIR/mcp.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/mcp_error.log</string>
    <key>WorkingDirectory</key>
    <string>$MCP_DEST_DIR</string>
</dict>
</plist>
EOF

# Load the launchd plist file
echo "Loading launchd plist file..."
launchctl unload -w "$HOME/Library/LaunchAgents/com.janet.mcp.plist" 2>/dev/null || true
launchctl load -w "$HOME/Library/LaunchAgents/com.janet.mcp.plist"

echo "===== Janet MCP System Installation Complete ====="
echo ""
echo "The MCP system has been installed in $MCP_DEST_DIR"
echo "It will start automatically when you log in."
echo ""
echo "To manually start the MCP system:"
echo "  launchctl start com.janet.mcp"
echo ""
echo "To manually stop the MCP system:"
echo "  launchctl stop com.janet.mcp"
echo ""
echo "Log files are located in $LOGS_DIR" 