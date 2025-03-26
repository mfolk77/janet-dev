#!/bin/bash

# Script to build and integrate the MCP system with Janet
# Created: $(date)

# Exit on error
set -e

echo "Starting MCP integration with Janet..."

# Check if MCP directory exists
if [ ! -d "mcp-system" ]; then
    echo "Error: mcp-system directory not found."
    exit 1
fi

# Navigate to MCP directory
cd mcp-system

# Install dependencies if needed
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.bin/tsc" ]; then
    echo "Installing MCP dependencies..."
    npm install
fi

# Build the MCP system
echo "Building MCP system..."
npm run build || {
    echo "Building with npm run build failed, trying direct TypeScript compilation..."
    ./node_modules/.bin/tsc
}

# Check if build was successful
if [ ! -d "dist" ]; then
    echo "Error: MCP build failed. dist directory not found."
    exit 1
fi

# Create a launcher script for MCP
echo "Creating MCP launcher script..."
cd ..
cat > mcp_launcher.sh << 'EOF'
#!/bin/bash

# MCP Launcher Script
# This script starts the MCP system and keeps it running

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change to the MCP directory
cd "$SCRIPT_DIR/mcp-system"

# Check if the MCP is already running
MCP_PID=$(pgrep -f "node.*dist/index.js" || echo "")

if [ -n "$MCP_PID" ]; then
    echo "MCP is already running with PID: $MCP_PID"
    exit 0
fi

# Start the MCP system
echo "Starting MCP system..."
nohup node dist/index.js server > ../logs/mcp.log 2>&1 &

# Check if MCP started successfully
sleep 2
MCP_PID=$(pgrep -f "node.*dist/index.js" || echo "")

if [ -n "$MCP_PID" ]; then
    echo "MCP started successfully with PID: $MCP_PID"
else
    echo "Failed to start MCP. Check logs for details."
    exit 1
fi
EOF

chmod +x mcp_launcher.sh

# Create a directory for logs if it doesn't exist
mkdir -p logs

# Create a script to grant necessary permissions
echo "Creating permission granting script..."
cat > grant_permissions.sh << 'EOF'
#!/bin/bash

# Script to grant necessary permissions for Janet and MCP
# This script requires administrator privileges

# Exit on error
set -e

echo "Granting necessary permissions for Janet and MCP..."

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

# Get the username of the user who ran sudo
REAL_USER=$(who am i | awk '{print $1}')
REAL_USER_HOME=$(eval echo ~$REAL_USER)

echo "Granting permissions for user: $REAL_USER"

# Grant Full Disk Access
echo "Granting Full Disk Access..."
sqlite3 "$REAL_USER_HOME/Library/Application Support/com.apple.TCC/TCC.db" "INSERT OR REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','com.FolkAI.Janet',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1);" || echo "Failed to grant Full Disk Access. Please grant manually."

# Grant Automation permissions
echo "Granting Automation permissions..."
sqlite3 "$REAL_USER_HOME/Library/Application Support/com.apple.TCC/TCC.db" "INSERT OR REPLACE INTO access VALUES('kTCCServiceAppleEvents','com.FolkAI.Janet',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1);" || echo "Failed to grant Automation permissions. Please grant manually."

# Create a privileged helper tool directory
HELPER_DIR="/Library/PrivilegedHelperTools/com.FolkAI.JanetHelper"
mkdir -p "$HELPER_DIR"

# Set ownership and permissions
chown -R $REAL_USER:staff "$HELPER_DIR"
chmod -R 755 "$HELPER_DIR"

echo "Permissions granted successfully."
EOF

chmod +x grant_permissions.sh

echo "Integration setup completed."
echo ""
echo "To complete the integration:"
echo "1. Run './mcp_launcher.sh' to start the MCP system"
echo "2. Run 'sudo ./grant_permissions.sh' to grant necessary permissions"
echo "3. Run './restart_model_service.sh' to restart Janet with the new integration"
echo ""
echo "Note: You may need to manually grant additional permissions through System Preferences > Security & Privacy" 