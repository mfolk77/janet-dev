# Janet Installation Guide

This guide provides step-by-step instructions for installing and setting up the Janet AI Assistant on your macOS system.

## System Requirements

Before installing Janet, ensure your system meets the following requirements:

- macOS 12.0 or later
- At least 8GB RAM (16GB recommended)
- 2GB free disk space
- Internet connection (for model downloads)

## Installation Methods

There are two ways to install Janet:

1. Using the pre-built application
2. Building from source

## Method 1: Using the Pre-built Application

### Step 1: Copy the Application

1. Navigate to the `Builds` directory in the Janet package
2. Copy the `Janet.app` file to your Applications folder:
   ```
   cp -R /path/to/Janet_25/Builds/Janet.app /Applications/
   ```

### Step 2: First Launch

1. Open Finder and navigate to your Applications folder
2. Right-click on `Janet.app` and select "Open"
3. If prompted with a security warning, click "Open" to confirm
4. Janet will initialize and may request permissions for various features

## Method 2: Building from Source

### Step 1: Install Development Tools

1. Install Xcode from the Mac App Store if you don't already have it
2. Install the Xcode Command Line Tools:
   ```
   xcode-select --install
   ```

### Step 2: Build the Application

1. Navigate to the Source_Code directory:
   ```
   cd /path/to/Janet_25/Source_Code
   ```

2. Build using xcodebuild:
   ```
   xcodebuild -scheme Janet -configuration Release -destination 'platform=macOS' build
   ```

3. The built application will be available in the DerivedData directory

### Step 3: Install the Built Application

1. Copy the built application to your Applications folder:
   ```
   cp -R /path/to/DerivedData/Build/Products/Release/Janet.app /Applications/
   ```

2. Launch the application as described in Method 1, Step 2

## Using the Launch Script

For convenience, a launch script is provided in the Janet_25 directory:

1. Make sure the script is executable:
   ```
   chmod +x /path/to/Janet_25/launch_janet.sh
   ```

2. Run the script:
   ```
   /path/to/Janet_25/launch_janet.sh
   ```

## Setting Up AI Models

Janet requires AI models to function. By default, it supports several models:

### Ollama

1. Install Ollama from [https://ollama.ai/](https://ollama.ai/)
2. Pull the required models:
   ```
   ollama pull llama2
   ```

### Other Models

For other models like Phi, Llama, and Mistral, follow the specific installation instructions for each model in their respective documentation.

## Troubleshooting

### Application Won't Open

If Janet won't open due to security settings:

1. Go to System Preferences > Security & Privacy
2. Look for a message about Janet being blocked
3. Click "Open Anyway" to allow the application to run

### Models Not Loading

If models aren't loading properly:

1. Check that the model files are in the correct location
2. Ensure you have sufficient disk space
3. Restart the application

### Performance Issues

If Janet is running slowly:

1. Close other resource-intensive applications
2. Consider using smaller models if your system has limited resources
3. Increase your system's swap space if possible

## Getting Help

If you encounter issues not covered in this guide, please refer to the documentation in the `Documentation` directory or contact support. 