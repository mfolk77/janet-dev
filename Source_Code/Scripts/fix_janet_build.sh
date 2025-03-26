#!/bin/bash

# Fix Janet Build Issues Script
echo "🔧 Starting Janet build fixes..."

# Define paths
SOURCE_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Source"
JANET_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Janet"

# Create Janet directory if it doesn't exist
if [ ! -d "$JANET_DIR" ]; then
  echo "📁 Creating Janet directory..."
  mkdir -p "$JANET_DIR"
fi

# Create necessary subdirectories
mkdir -p "$JANET_DIR/Models"
mkdir -p "$JANET_DIR/Services"
mkdir -p "$JANET_DIR/Services/Memory"
mkdir -p "$JANET_DIR/Views"

# Copy files
echo "📄 Copying files..."

# Copy JanetApp.swift
cp "$SOURCE_DIR/JanetApp.swift" "$JANET_DIR/"

# Copy Models
cp "$SOURCE_DIR/Models/"*.swift "$JANET_DIR/Models/"

# Copy Services
cp "$SOURCE_DIR/Services/"*.swift "$JANET_DIR/Services/"
cp "$SOURCE_DIR/Services/Memory/"*.swift "$JANET_DIR/Services/Memory/"

# Copy Views
cp "$SOURCE_DIR/Views/"*.swift "$JANET_DIR/Views/"

# Copy entitlements file
cp "$SOURCE_DIR/Janet.entitlements" "$JANET_DIR/"

# Fix NavigationState redeclaration issue
echo "🔧 Fixing NavigationState redeclaration issue..."
# Ensure we have the latest version with speech support
cp "$SOURCE_DIR/Models/NavigationState.swift" "$JANET_DIR/Models/"

# Fix SpeechService issue
echo "🔧 Ensuring SpeechService is properly copied..."
if [ -f "$SOURCE_DIR/Services/SpeechService.swift" ]; then
  cp "$SOURCE_DIR/Services/SpeechService.swift" "$JANET_DIR/Services/"
  echo "✅ SpeechService.swift copied successfully"
else
  echo "⚠️ Warning: SpeechService.swift not found in source directory"
fi

# Fix OllamaModel struct issue
echo "🔧 Fixing OllamaModel struct issue..."
OLLAMA_SERVICE_FILE="$JANET_DIR/Services/OllamaService.swift"

# Check if the file exists
if [ -f "$OLLAMA_SERVICE_FILE" ]; then
  # Add OllamaModel struct if it doesn't exist
  if ! grep -q "struct OllamaModel: Codable" "$OLLAMA_SERVICE_FILE"; then
    # Find the line number where to insert the struct
    LINE_NUM=$(grep -n "struct OllamaModelInfo" "$OLLAMA_SERVICE_FILE" | cut -d':' -f1)
    if [ -n "$LINE_NUM" ]; then
      # Insert the OllamaModel struct before OllamaModelInfo
      sed -i '' "${LINE_NUM}i\\
// MARK: - OllamaModel\\
struct OllamaModel: Codable {\\
    let name: String\\
    let modified_at: String\\
    let size: Int64\\
}\\
" "$OLLAMA_SERVICE_FILE"
      echo "✅ Added OllamaModel struct to OllamaService.swift"
    fi
  fi
fi

# Fix logToFile function calls
echo "🔧 Fixing logToFile function calls..."
if [ -f "$OLLAMA_SERVICE_FILE" ]; then
  # Replace logToFile(message: "...") with logToFile("...")
  sed -i '' 's/logToFile(message: "/logToFile("/g' "$OLLAMA_SERVICE_FILE"
  echo "✅ Fixed logToFile function calls in OllamaService.swift"
fi

# Fix permissions
echo "🔒 Setting file permissions..."
chmod -R 644 "$JANET_DIR"/*.swift "$JANET_DIR"/*/*.swift "$JANET_DIR"/*/*/*.swift
chmod 644 "$JANET_DIR/Janet.entitlements"

echo "✅ Build fixes completed!"
echo "You can now open the Xcode project and build the app."
echo "If you encounter any issues, please check the console output for errors." 