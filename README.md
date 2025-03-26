# Janet AI Assistant

Janet is a powerful AI assistant application for macOS that orchestrates multiple AI models to provide intelligent responses to user queries.

## Directory Structure

- **Source_Code/**: Contains all the source code for the Janet application
  - Janet/: Main application source code
  - Janet.xcodeproj/: Xcode project files
  - Tests/: Test files for the application
  - Scripts/: Utility scripts
  - Janet.entitlements: App entitlements file

- **Documentation/**: Contains all documentation for the project
  - README.md: Main project documentation
  - LAUNCHER_README.md: Documentation for launcher applications

- **Resources/**: Contains resources used by the application
  - JanetIcon.icns: Application icon file

- **Builds/**: Contains built application binaries
  - Janet.app: The compiled Janet application

## Getting Started

1. To launch Janet, use the provided launch script:
   ```
   ./launch_janet.sh
   ```

2. Alternatively, you can directly open the application from the Builds directory:
   ```
   open Builds/Janet.app
   ```

## Building from Source

To build Janet from source:

1. Navigate to the Source_Code directory:
   ```
   cd Source_Code
   ```

2. Build using xcodebuild:
   ```
   xcodebuild -scheme Janet -configuration Release -destination 'platform=macOS' build
   ```

3. The built application will be available in the DerivedData directory.

## Features

- Multi-model orchestration for optimal responses
- Support for various AI models including Ollama, Phi, Llama, and Mistral
- Task-specific model selection
- Memory context for maintaining conversation history
- System command execution capabilities
- Parallel and chain execution modes

## Requirements

- macOS 12.0 or later
- Xcode 14.0 or later (for building from source)
- Minimum 8GB RAM (16GB recommended)
- 2GB free disk space

## License

[License information would go here]

Janet is a powerful AI assistant for macOS that integrates with various language models and provides a clean, intuitive interface for interacting with AI.

## Directory Structure

This package is organized as follows:

- **Source_Code/**: Contains all the source code for the Janet application
  - Janet/: Main application source code
  - Janet.xcodeproj: Xcode project file
  - Scripts/: Utility scripts
  - Tests/: Test files

- **Documentation/**: Contains all documentation files
  - README.md: Main documentation
  - LAUNCHER_README.md: Documentation for launcher applications
  - Other documentation files

- **Resources/**: Contains resources like icons and assets
  - JanetIcon.icns: Application icon

- **Builds/**: Contains the built Janet application
  - Janet.app: The compiled macOS application

## Getting Started

1. To launch Janet, use the `launch_janet.sh` script in the root directory:
   ```
   ./launch_janet.sh
   ```

2. If you encounter any issues with icons not displaying correctly, refer to the icon troubleshooting guide in the Documentation folder.

## Building from Source

To build Janet from source:

1. Navigate to the Source_Code directory
2. Open Janet.xcodeproj in Xcode
3. Select the Janet scheme and build for your target architecture
4. The built app will be placed in the DerivedData directory

## Troubleshooting

### Icon Issues

If you encounter issues with icons not displaying correctly:

1. Install the fileicon utility: `brew install fileicon`
2. Use the clear_icon_cache.sh script to clear the macOS icon cache
3. Restart Finder and Dock

### Application Crashes

If the application crashes on startup:

1. Check that all required models are properly installed
2. Verify that the Ollama service is running if using local models
3. Check the system logs for detailed error information

## License

Janet is licensed under proprietary terms. See the license file for details.
