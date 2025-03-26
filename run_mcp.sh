#!/bin/bash

# Script to run the Janet MCP system
# Created: $(date)

# Exit on error
set -e

echo "Starting MCP..."

# Define directories
MCP_DIR="$HOME/Library/Application Support/Janet/mcp-system"
LOGS_DIR="$HOME/Library/Application Support/Janet/logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

# Check if MCP is already running
if pgrep -f "node.*dist/index.js.*server" > /dev/null; then
  PID=$(pgrep -f "node.*dist/index.js.*server")
  echo "MCP is already running with PID: $PID"
  exit 0
fi

# Change to MCP directory and start the MCP
cd "$MCP_DIR"

# First, let's rebuild the MCP to ensure our changes are applied
echo "Rebuilding MCP..."
npm run build >> "$LOGS_DIR/mcp_build.log" 2>&1

# Start the MCP in server mode
node dist/index.js server > "$LOGS_DIR/mcp_output.log" 2> "$LOGS_DIR/mcp_error.log" &
MCP_PID=$!

# Wait a moment to see if the process stays alive
sleep 2

# Check if the process is still running
if ps -p $MCP_PID > /dev/null; then
  echo "MCP started successfully with PID: $MCP_PID"
  echo $MCP_PID > "$LOGS_DIR/mcp.pid"
  exit 0
else
  echo "Failed to start MCP. Check logs for details."
  exit 1
fi 