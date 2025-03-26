#!/bin/bash

# MCP System Installation Script

echo "Installing MCP System dependencies..."

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Install dependencies
npm install

# Create required directories
mkdir -p logs
mkdir -p config

# Create default config files if they don't exist
if [ ! -f config/security.json ]; then
    echo "Creating default security configuration..."
    echo '{
  "usersFilePath": "./config/users.json",
  "tokenSecret": "'$(openssl rand -hex 16)'",
  "tokenExpiration": 86400,
  "encryptionKey": "'$(openssl rand -hex 16)'"
}' > config/security.json
fi

if [ ! -f config/users.json ]; then
    echo "Creating empty users file..."
    echo '{"users": []}' > config/users.json
fi

# Build the project
echo "Building MCP System..."
npm run build

echo "Installation complete!"
echo "You can now use the MCP System by running: node dist/index.js" 