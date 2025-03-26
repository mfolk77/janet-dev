# Janet's Master Control Program (MCP)

Janet's Master Control Program (MCP) is a robust, autonomous AI system for macOS, integrating AI-driven automation, full system access, local model execution, and advanced memory retention. It is designed to be fully offline-capable, with privacy-first design principles.

## Overview

The MCP serves as the brain of Janet, directing tasks to submodules and providing a comprehensive system for executing commands, managing files, and integrating with AI models. It handles orchestration, automation, and dynamic task execution, ensuring Janet functions as a powerful AI-driven system controller.

## Architecture

The MCP is built with a modular architecture, consisting of the following components:

### Core Components

1. **MCP Core**: The central system that manages modules, plugins, and command execution.
2. **Module System**: Extensible modules for different functionality domains.
3. **Security Manager**: Handles authentication, permissions, and secure operations.
4. **Memory System**: Manages persistent storage and retrieval of AI memories.

### Modules

1. **File System Module**: Read, write, move, and delete files; create and list directories.
2. **Terminal Module**: Execute shell commands, run diagnostics, manage processes.
3. **Web Module**: Fetch and parse web content, make API calls, download files.
4. **AI Module**: Run local AI models, process text, handle voice commands.
5. **Memory Module**: Store and retrieve memories, search for relevant context.
6. **Automation Module**: Control macOS applications, execute AppleScript, schedule tasks.

## Installation

To install the MCP system:

```bash
./install_mcp.sh
```

This script will:
1. Install the MCP in `~/Library/Application Support/Janet/mcp-system`
2. Create directories for models, memory, and logs
3. Install dependencies and build the MCP
4. Create a launchd plist file for auto-starting the MCP
5. Load the launchd service to start the MCP

## Usage

### From Janet

Janet communicates with the MCP through the `MCPBridge` class, which provides methods for:

- Starting and stopping the MCP
- Checking if the MCP is running
- Executing commands with the MCP

### Command Line

You can also use the MCP directly from the command line:

```bash
# Execute a file system command
node ~/Library/Application\ Support/Janet/mcp-system/dist/index.js fs.readFile path=/path/to/file.txt

# Execute a terminal command
node ~/Library/Application\ Support/Janet/mcp-system/dist/index.js terminal.execute command="ls -la"

# Execute an AI command
node ~/Library/Application\ Support/Janet/mcp-system/dist/index.js ai.localModel prompt="Explain quantum computing" model=mistral-7b
```

### Command Format

Commands follow this format:

```
module.command param1=value1 param2=value2
```

## Features

### 1. System Integration & Orchestration

The MCP acts as the brain of Janet, directing tasks to submodules:

- **Dynamic Module Selection**: Routes tasks to the appropriate module based on complexity.
- **Task Execution**: Handles system commands, file management, and automation.
- **Memory Recall**: Fetches relevant past interactions for context-aware responses.

### 2. AI Model Handling & Local Execution

The MCP supports local AI processing:

- **Local LLM Integration**: Uses llama.cpp for fully local AI processing.
- **Model Switching**: Optimizes AI model selection for task-based efficiency.
- **Multi-Modal Capabilities**: Supports text processing, voice interaction, and image recognition.

### 3. Full System Automation & Permissions

The MCP provides deep macOS integration:

- **System Access**: Full Disk Access, Accessibility & Automation, Notification Handling.
- **Background Execution**: Ensures Janet is always available.
- **AppleScript Execution**: Controls macOS Finder, Terminal, and Application execution.

### 4. Advanced Memory & Recall System

The MCP includes a sophisticated memory system:

- **Persistent Storage**: Stores memories in a structured format for long-term recall.
- **Context-Aware Responses**: Enables responses based on past interactions.
- **Secure Storage**: Encrypts sensitive data for privacy.

## Security

The MCP includes several security features:

- **Authentication**: Verifies the identity of callers before executing commands.
- **Permission System**: Controls access to sensitive operations.
- **Encryption**: Protects sensitive data in memory storage.
- **Audit Logging**: Records all command executions for accountability.

## Development

### Project Structure

```
mcp-system/
├── config/           # Configuration files
├── logs/             # Log files
├── src/              # Source code
│   ├── core/         # Core system components
│   ├── interfaces/   # TypeScript interfaces
│   ├── modules/      # Built-in modules
│   │   ├── ai/       # AI model integration
│   │   ├── automation/ # System automation
│   │   ├── fs/       # File system operations
│   │   ├── memory/   # Memory management
│   │   ├── terminal/ # Terminal command execution
│   │   └── web/      # Web automation and API integration
│   ├── plugins/      # Plugin system
│   ├── security/     # Security components
│   ├── utils/        # Utility functions
│   └── index.ts      # Main entry point
├── dist/             # Compiled code
├── package.json      # Dependencies and scripts
└── tsconfig.json     # TypeScript configuration
```

### Creating a New Module

1. Create a new directory in `src/modules/`
2. Create an `index.ts` file that exports a class extending `BaseModule`
3. Create command implementations in a `commands/` subdirectory

### Creating a New Command

1. Create a new file in the module's `commands/` directory
2. Create a class extending `BaseCommand`
3. Implement the `onExecute` method

## Troubleshooting

### MCP Not Starting

If the MCP fails to start:

1. Check the logs in `~/Library/Application Support/Janet/logs/mcp.log`
2. Ensure Node.js is installed and in the PATH
3. Try manually starting the MCP:
   ```bash
   launchctl start com.janet.mcp
   ```

### Command Execution Failures

If commands fail to execute:

1. Check if the MCP is running:
   ```bash
   launchctl list | grep com.janet.mcp
   ```
2. Check the command syntax and parameters
3. Check the logs for error messages

## License

MIT 