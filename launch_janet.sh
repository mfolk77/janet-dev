#!/bin/bash
# Janet Launcher Script
# This script launches the Janet app from the Builds directory

# Exit on any error
set -e

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JANET_APP="$SCRIPT_DIR/Builds/Janet.app"

# Check if the app exists
if [ ! -d "$JANET_APP" ]; then
    echo "Error: Janet app not found at $JANET_APP"
    exit 1
fi

# Check if the app is already running
if pgrep -f "Janet.app/Contents/MacOS/Janet" > /dev/null; then
    echo "Janet is already running. Would you like to restart it? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Restarting Janet..."
        pkill -f "Janet.app/Contents/MacOS/Janet"
        sleep 2
    else
        echo "Bringing Janet to the foreground..."
        osascript -e 'tell application "Janet" to activate'
        exit 0
    fi
fi

# Check if the executable exists and is executable
if [ ! -x "$JANET_APP/Contents/MacOS/Janet" ]; then
    echo "Error: Janet executable not found or not executable"
    echo "Attempting to fix permissions..."
    chmod +x "$JANET_APP/Contents/MacOS/Janet"
fi

echo "Launching Janet..."
open "$JANET_APP"

# Wait a moment and check if the app started successfully
sleep 2
if ! pgrep -f "Janet.app/Contents/MacOS/Janet" > /dev/null; then
    echo "Error: Failed to launch Janet"
    echo "Attempting to launch directly..."
    "$JANET_APP/Contents/MacOS/Janet" &
fi

echo "Janet launched successfully!"
