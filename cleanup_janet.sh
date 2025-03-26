#!/bin/bash
# Janet Cleanup Script
# This script cleans up unnecessary files and directories in the Janet project

# Exit on any error
set -e

echo "=============================="
echo "  Cleaning up Janet Project"
echo "=============================="

# Define paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_TMP_DIR="$SCRIPT_DIR/build_tmp"
BACKUP_DIR="$SCRIPT_DIR/Backup_Jarvis"
MCP_NODE_MODULES="$SCRIPT_DIR/mcp-system/node_modules"
MCP_DIST_DIR="$SCRIPT_DIR/mcp-system/dist"

# Remove build_tmp directory
if [ -d "$BUILD_TMP_DIR" ]; then
    echo "Removing build_tmp directory..."
    rm -rf "$BUILD_TMP_DIR"
    echo "✅ build_tmp directory removed"
fi

# Remove Backup_Jarvis directory
if [ -d "$BACKUP_DIR" ]; then
    echo "Removing Backup_Jarvis directory..."
    rm -rf "$BACKUP_DIR"
    echo "✅ Backup_Jarvis directory removed"
fi

# Clean up MCP system
if [ -d "$MCP_NODE_MODULES" ]; then
    echo "Cleaning up MCP node_modules..."
    rm -rf "$MCP_NODE_MODULES"
    echo "✅ MCP node_modules removed"
fi

if [ -d "$MCP_DIST_DIR" ]; then
    echo "Cleaning up MCP dist directory..."
    rm -rf "$MCP_DIST_DIR"
    echo "✅ MCP dist directory removed"
fi

# Remove any .DS_Store files
echo "Removing .DS_Store files..."
find "$SCRIPT_DIR" -name ".DS_Store" -delete
echo "✅ .DS_Store files removed"

# Remove any backup files
echo "Removing backup files..."
find "$SCRIPT_DIR" -name "*.backup.*" -delete
echo "✅ Backup files removed"

echo "=============================="
echo "  Cleanup Complete"
echo "=============================="
echo "The Janet project has been cleaned up."
echo "To rebuild Janet, run ./build_janet.sh"
echo "To reinstall MCP dependencies, run:"
echo "  cd mcp-system && npm install" 