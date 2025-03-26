#!/bin/bash

# Script to restart the AI model service for Janet
# Created: $(date)

# Exit on error
set -e

echo "Checking and restarting AI model service for Janet..."

# Check if Janet is running
JANET_PID=$(pgrep -f "Janet.app/Contents/MacOS/Janet" || echo "")

if [ -z "$JANET_PID" ]; then
    echo "Janet is not running. Starting Janet..."
    open Builds/Janet.app
    sleep 3
    JANET_PID=$(pgrep -f "Janet.app/Contents/MacOS/Janet" || echo "")
    
    if [ -z "$JANET_PID" ]; then
        echo "Failed to start Janet. Please check the application."
        exit 1
    fi
fi

echo "Janet is running with PID: $JANET_PID"

# Check for any model service processes
MODEL_PIDS=$(ps aux | grep -i "model\|llm\|claude\|gpt" | grep -v grep | awk '{print $2}' || echo "")

if [ -n "$MODEL_PIDS" ]; then
    echo "Found model service processes: $MODEL_PIDS"
    echo "Restarting model services..."
    
    for pid in $MODEL_PIDS; do
        echo "Stopping process $pid..."
        kill -15 $pid 2>/dev/null || echo "Process $pid already stopped"
    done
    
    sleep 2
else
    echo "No model service processes found."
fi

# Restart Janet to reinitialize model connections
echo "Restarting Janet to reinitialize model connections..."
killall Janet 2>/dev/null || echo "Janet process not found"
sleep 2
open Builds/Janet.app

echo "Waiting for Janet to initialize..."
sleep 5

# Check if Janet is running after restart
JANET_PID=$(pgrep -f "Janet.app/Contents/MacOS/Janet" || echo "")

if [ -n "$JANET_PID" ]; then
    echo "Janet restarted successfully with PID: $JANET_PID"
    echo "Model service should now be online. Please check the Janet interface."
else
    echo "Failed to restart Janet. Please check the application."
    exit 1
fi 