#!/bin/bash

# Master setup script for Janet system
# Created: $(date)

# Exit on error
set -e

echo "===== Janet System Setup ====="
echo "This script will set up the complete Janet system with all necessary components."
echo "It will:"
echo "1. Re-sign Janet.app with proper entitlements"
echo "2. Build and integrate the MCP system"
echo "3. Build and install the JanetHelper tool (requires sudo)"
echo "4. Grant necessary permissions (requires sudo)"
echo "5. Restart Janet with the new configuration"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Step 1: Re-sign Janet.app
echo ""
echo "===== Step 1: Re-signing Janet.app ====="
./resign_janet.sh

# Step 2: Build and integrate MCP
echo ""
echo "===== Step 2: Building and integrating MCP ====="
./integrate_mcp.sh

# Step 3: Build and install JanetHelper
echo ""
echo "===== Step 3: Building and installing JanetHelper ====="
./build_helper.sh

# Step 4: Grant permissions
echo ""
echo "===== Step 4: Granting permissions ====="
echo "This step requires sudo access."
sudo ./grant_permissions.sh

# Step 5: Start MCP and restart Janet
echo ""
echo "===== Step 5: Starting MCP and restarting Janet ====="
./mcp_launcher.sh
./restart_model_service.sh

echo ""
echo "===== Setup Complete ====="
echo "The Janet system has been set up successfully."
echo ""
echo "If you encounter any issues:"
echo "1. Check the logs in the 'logs' directory"
echo "2. Run './restart_model_service.sh' to restart Janet"
echo "3. Run './mcp_launcher.sh' to restart the MCP system"
echo ""
echo "Enjoy using Janet as your system commander!" 