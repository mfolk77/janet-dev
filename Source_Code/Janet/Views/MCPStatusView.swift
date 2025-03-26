import SwiftUI
import OSLog

struct MCPStatusView: View {
    @EnvironmentObject private var mcpBridge: MCPBridge
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "MCPStatusView")
    
    @State private var commandInput: String = ""
    @State private var commandResult: String = ""
    @State private var isExecutingCommand: Bool = false
    @State private var selectedModule: String = "fs"
    @State private var selectedCommand: String = "readFile"
    @State private var commandParams: String = "path=/Users/\(NSUserName())/Documents/test.txt"
    @State private var showCommandHistory: Bool = false
    @State private var commandHistory: [CommandHistoryItem] = []
    
    // Available modules and commands
    private let modules = [
        "fs": ["readFile"],
        "terminal": ["execute"],
        "ai": ["localModel"],
        "web": ["fetch"],
        "memory": ["storeMemory", "retrieveMemory", "searchMemory"],
        "automation": ["runAppleScript"]
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("MCP Status")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Toggle command history
                Button(action: {
                    showCommandHistory.toggle()
                }) {
                    Label(showCommandHistory ? "Hide History" : "Show History", 
                          systemImage: showCommandHistory ? "eye.slash" : "eye")
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            // Main content
            HStack(spacing: 0) {
                // Left panel - Status and controls
                VStack(alignment: .leading, spacing: 16) {
                    // MCP Status
                    GroupBox(label: Text("MCP Status").font(.headline)) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: mcpBridge.isRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(mcpBridge.isRunning ? .green : .red)
                                    .font(.title2)
                                
                                Text(mcpBridge.isRunning ? "MCP is running" : "MCP is not running")
                                    .font(.headline)
                            }
                            
                            if mcpBridge.isRunning {
                                Button(action: {
                                    logger.info("Stopping MCP...")
                                    Task {
                                        await mcpBridge.stopMCP()
                                    }
                                }) {
                                    Label("Stop MCP", systemImage: "stop.circle")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Button(action: {
                                    logger.info("Starting MCP...")
                                    Task {
                                        await mcpBridge.startMCP()
                                    }
                                }) {
                                    Label("Start MCP", systemImage: "play.circle")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                    .padding(.bottom, 8)
                    
                    // Command Builder
                    GroupBox(label: Text("Command Builder").font(.headline)) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Module selector
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Module:")
                                    .font(.subheadline)
                                
                                Picker("Module", selection: $selectedModule) {
                                    ForEach(Array(modules.keys.sorted()), id: \.self) { module in
                                        Text(module).tag(module)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: selectedModule) { oldValue, newValue in
                                    // Reset command when module changes
                                    if let commands = modules[newValue], !commands.isEmpty {
                                        selectedCommand = commands[0]
                                    }
                                }
                            }
                            
                            // Command selector
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Command:")
                                    .font(.subheadline)
                                
                                Picker("Command", selection: $selectedCommand) {
                                    ForEach(modules[selectedModule] ?? [], id: \.self) { command in
                                        Text(command).tag(command)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            
                            // Parameters
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Parameters:")
                                    .font(.subheadline)
                                
                                TextField("param1=value1 param2=value2", text: $commandParams)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            // Execute button
                            Button(action: {
                                executeCommand()
                            }) {
                                if isExecutingCommand {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                } else {
                                    Label("Execute Command", systemImage: "terminal")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!mcpBridge.isRunning || isExecutingCommand)
                        }
                        .padding()
                    }
                    
                    Spacer()
                }
                .frame(width: 300)
                .padding()
                .background(Color(.windowBackgroundColor).opacity(0.5))
                
                // Right panel - Command output or history
                VStack {
                    if showCommandHistory {
                        // Command history
                        List {
                            ForEach(commandHistory) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("\(item.module).\(item.command)")
                                            .font(.headline)
                                        
                                        Spacer()
                                        
                                        Text(item.timestamp, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text("Parameters: \(item.params)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Divider()
                                    
                                    Text("Result:")
                                        .font(.subheadline)
                                    
                                    Text(item.result)
                                        .font(.body)
                                        .padding(8)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(PlainListStyle())
                    } else {
                        // Command result
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Command Output")
                                .font(.headline)
                            
                            ScrollView {
                                Text(commandResult.isEmpty ? "No command executed yet. Use the command builder to execute MCP commands." : commandResult)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
                .background(Color(.windowBackgroundColor).opacity(0.3))
            }
        }
    }
    
    private func executeCommand() {
        guard mcpBridge.isRunning else {
            commandResult = "Error: MCP is not running"
            return
        }
        
        let fullCommand = "\(selectedModule).\(selectedCommand) \(commandParams)"
        isExecutingCommand = true
        commandResult = "Executing: \(fullCommand)..."
        
        Task {
            do {
                let result = try await mcpBridge.executeCommand(fullCommand)
                
                // Format the result as pretty JSON
                let jsonData = try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "Invalid JSON response"
                
                await MainActor.run {
                    commandResult = jsonString
                    isExecutingCommand = false
                    
                    // Add to command history
                    let historyItem = CommandHistoryItem(
                        id: UUID(),
                        module: selectedModule,
                        command: selectedCommand,
                        params: commandParams,
                        result: jsonString,
                        timestamp: Date()
                    )
                    commandHistory.insert(historyItem, at: 0)
                    
                    // Limit history to 20 items
                    if commandHistory.count > 20 {
                        commandHistory.removeLast()
                    }
                }
            } catch {
                await MainActor.run {
                    commandResult = "Error: \(error.localizedDescription)"
                    isExecutingCommand = false
                }
            }
        }
    }
}

// Command history item model
struct CommandHistoryItem: Identifiable {
    let id: UUID
    let module: String
    let command: String
    let params: String
    let result: String
    let timestamp: Date
}

#Preview {
    MCPStatusView()
        .environmentObject(MCPBridge.shared)
} 