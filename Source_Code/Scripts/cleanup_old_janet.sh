#!/bin/bash

# Script to clean up old Janet directories
echo "==============================" 
echo "  Cleaning up old Janet directories"
echo "==============================" 

# List of directories to remove
DIRS_TO_REMOVE=(
    "/Volumes/Folk_DAS/Janet"
    "/Volumes/Folk_DAS/Janet AI"
    "/Volumes/Folk_DAS/Janet_Backup_20250301_223430"
    "/Volumes/Folk_DAS/Janet1"
    "/Volumes/Folk_DAS/JanetApp"
    "/Volumes/Folk_DAS/old Janet"
    "/Volumes/Folk_DAS/Janet\\"
)

# Ask for confirmation before removing each directory
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ] || [ -f "$dir" ]; then
        echo "Do you want to remove $dir? (y/n)"
        read -r answer
        if [ "$answer" = "y" ]; then
            echo "Removing $dir..."
            rm -rf "$dir"
            echo "Done."
        else
            echo "Skipping $dir."
        fi
    else
        echo "$dir does not exist. Skipping."
    fi
done

echo "==============================" 
echo "  Cleanup complete"
echo "==============================" 