# Model Context Protocol (MCP)

A modular system for executing commands, managing files, and integrating with AI models.

## Features

### 1. File System Control
- Read, write, move, and delete files
- Create and list directories
- Open and manipulate Finder windows
- Modify file permissions

### 2. Terminal Execution & System Management
- Execute shell commands
- Run diagnostics (`top`, `df -h`, `ps aux`)
- Install and manage software (`brew install`, `npm install`)
- Manage running processes (`kill`, `pkill`, `ps`)

### 3. Web Automation & API Integration
- Fetch and parse web content
- Automate browser interactions (Puppeteer)
- Make API calls (Claude, cloud services)
- Download and upload files

### 4. AI & Automation
- Run local AI models for text analysis
- Support Speech-to-Text (voice commands)
- Store logs for context retention

### 5. Security & Privacy
- Enforce controlled permissions
- Log all executed commands for auditing
- Handle encrypted file storage

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/mcp-system.git
cd mcp-system

# Install dependencies
npm install

# Build the project
npm run build
```

## Usage

### Command Line Interface

```bash
# Execute a command
node dist/index.js fs.readFile path=/path/to/file.txt

# Execute a command with authentication
node dist/index.js fs.readFile path=/path/to/file.txt apiKey=your-api-key
```

### Module Structure

The MCP system is organized into modules, each providing a set of commands:

- **fs**: File system operations
- **terminal**: Terminal command execution
- **web**: Web automation and API integration
- **ai**: AI model integration

### Command Format

Commands follow this format:

```
module.command param1=value1 param2=value2
```

For example:

```
fs.readFile path=/path/to/file.txt encoding=utf8
terminal.execute command="ls -la" timeout=5000
web.apiCall url="https://api.example.com/data" method=GET
ai.claude prompt="Explain quantum computing" model=claude-3-haiku
```

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

## License

MIT 