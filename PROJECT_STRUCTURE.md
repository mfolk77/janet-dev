# Janet Project Structure

This document provides an overview of the Janet project structure, explaining the purpose of each component and how they work together.

## Core Components

### 1. Swift/Xcode App (Source_Code/)
The main Janet application is a Swift app built with Xcode. The source code is located in the `Source_Code/` directory.

- **Source_Code/Janet/**: Contains the main application code
  - **Services/**: Core services like Ollama integration, memory management, etc.
  - **Views/**: SwiftUI views for the user interface
  - **Models/**: Data models used throughout the application
  - **Utilities/**: Helper functions and utilities

### 2. MCP System (mcp-system/)
The MCP (Master Control Program) is a Node.js-based middleware component that provides additional functionality to Janet.

- **mcp-system/src/**: TypeScript source code for the MCP
- **mcp-system/dist/**: Compiled JavaScript code (generated during build)
- **mcp-system/node_modules/**: Node.js dependencies (can be safely deleted and reinstalled)

## Build and Launch Scripts

- **build_janet.sh**: Builds the Janet app from source
- **launch_janet.sh**: Launches the built Janet app
- **cleanup_janet.sh**: Cleans up unnecessary files and directories
- **install_mcp.sh**: Installs the MCP system
- **run_mcp.sh**: Runs the MCP system

## Directory Structure

```
Janet_25/
├── Builds/                  # Contains the built Janet.app
├── Source_Code/             # Main source code for the Swift app
│   ├── Janet/               # Core application code
│   └── Janet.xcodeproj/     # Xcode project file
├── mcp-system/              # MCP middleware component
│   ├── src/                 # TypeScript source code
│   └── dist/                # Compiled JavaScript (generated)
├── build_janet.sh           # Script to build the app
├── launch_janet.sh          # Script to launch the app
├── cleanup_janet.sh         # Script to clean up the project
└── install_mcp.sh           # Script to install the MCP
```

## Development Workflow

1. Make changes to the Swift code in `Source_Code/Janet/`
2. Run `./build_janet.sh` to build the app
3. Run `./launch_janet.sh` to launch the app

If you need to modify the MCP system:
1. Make changes to the TypeScript code in `mcp-system/src/`
2. Run `cd mcp-system && npm run build` to compile the TypeScript
3. Run `./run_mcp.sh` to start the MCP system

## Cleanup

To clean up unnecessary files and reduce disk space:
1. Run `./cleanup_janet.sh`
2. This will remove temporary build files, node_modules, and other unnecessary files
3. You can always rebuild the app and reinstall dependencies as needed 