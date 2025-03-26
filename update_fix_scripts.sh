#!/bin/bash
# Script to update all fix scripts to use the correct paths

# Exit on any error
set -e

echo "=============================="
echo "  Updating Fix Scripts"
echo "=============================="

# Define paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_CODE_DIR="$SCRIPT_DIR/Source_Code"
SCRIPTS_DIR="$SOURCE_CODE_DIR/Scripts"

# Check if the scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "Error: Scripts directory not found at $SCRIPTS_DIR"
    exit 1
fi

# Update all scripts in the Scripts directory
echo "Updating scripts in $SCRIPTS_DIR..."
for script in "$SCRIPTS_DIR"/*.sh; do
    echo "Processing $script..."
    
    # Replace old paths with new paths
    sed -i.bak "s|/Volumes/Folk_DAS/Janet_Clean/Source|$SOURCE_CODE_DIR/Source|g" "$script"
    sed -i.bak "s|/Volumes/Folk_DAS/Janet_Clean/Janet|$SOURCE_CODE_DIR/Janet|g" "$script"
    sed -i.bak "s|/Volumes/Folk_DAS/Janet_Clean|$SCRIPT_DIR|g" "$script"
    
    # Remove backup files
    rm -f "$script.bak"
    
    echo "Updated $script"
done

echo "=============================="
echo "  Update Complete"
echo "=============================="
echo "All fix scripts have been updated to use the correct paths." 