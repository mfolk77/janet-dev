import Foundation
import OSLog

/// Bridge between Janet and the MCP system
public class MCPBridge: ObservableObject, @unchecked Sendable {
    /// Shared instance of the MCPBridge
    public static let shared = MCPBridge()
    
    /// Logger for the MCP bridge
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "MCPBridge")
    
    /// Whether the MCP is currently running
    @Published public var isRunning: Bool = false
    
    /// The path to the MCP executable
    private let mcpPath: String
    
    /// The MCP server URL
    private let mcpServerURL = URL(string: "http://localhost:3000")!
    
    /// The process for the MCP
    private var mcpProcess: Process?
    
    /// Initialize the MCP bridge
    private init() {
        // Set the path to the MCP executable
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let janetDir = appSupportDir.appendingPathComponent("Janet")
        mcpPath = janetDir.appendingPathComponent("mcp-system/mcp_proxy_server.js").path
        
        // Check if the MCP is already running
        Task {
            isRunning = await checkMCPStatus()
        }
        
        // Set up a timer to periodically check MCP status
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                guard let self = self else { return }
                self.isRunning = await self.checkMCPStatus()
            }
        }
    }
    
    /// Check if the MCP service is running
    public func checkMCPStatus() async -> Bool {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["aux"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let isRunning = output.contains("mcp_service") || output.contains("mcp.py")
                logger.info("MCP status check: \(self.isRunning ? "running" : "not running")")
                return isRunning
            }
        } catch {
            logger.error("Error checking MCP status: \(error.localizedDescription)")
        }
        
        return false
    }
    
    /// Start the MCP
    public func startMCP() async {
        logger.info("Starting MCP service...")
        
        guard !isRunning else {
            logger.info("MCP is already running")
            return
        }
        
        // Create the Janet directory if it doesn't exist
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let janetDir = appSupportDir.appendingPathComponent("Janet")
        let logsDir = janetDir.appendingPathComponent("logs")
        
        do {
            try FileManager.default.createDirectory(at: janetDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Error creating directories: \(error.localizedDescription)")
            return
        }
        
        // Start the MCP process
        let task = Process()
        let logPipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/node")
        task.arguments = [mcpPath]
        task.standardOutput = logPipe
        task.standardError = logPipe
        
        // Set the current directory to the MCP directory
        let mcpDir = (mcpPath as NSString).deletingLastPathComponent
        task.currentDirectoryURL = URL(fileURLWithPath: mcpDir)
        
        do {
            try task.run()
            mcpProcess = task
            
            // Read the output asynchronously
            DispatchQueue.global(qos: .background).async {
                let data = logPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                self.logger.info("MCP output: \(output)")
            }
            
            // Wait a moment for the process to start
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check if the process is running
            isRunning = await checkMCPStatus()
            
            if isRunning {
                logger.info("MCP service started successfully")
            } else {
                logger.error("Failed to start MCP service")
            }
        } catch {
            logger.error("Error starting MCP: \(error.localizedDescription)")
        }
    }
    
    /// Stop the MCP
    public func stopMCP() async {
        logger.info("Stopping MCP service...")
        
        guard isRunning else {
            logger.info("MCP is not running")
            return
        }
        
        // Kill the MCP process
        let task = Process()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "node.*mcp_proxy_server.js"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            // Wait a moment for the process to stop
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Check if the process is still running
            isRunning = await checkMCPStatus()
            
            if !isRunning {
                logger.info("MCP service stopped successfully")
            } else {
                logger.error("Failed to stop MCP service")
            }
        } catch {
            logger.error("Error stopping MCP: \(error.localizedDescription)")
        }
    }
    
    /// Execute a command with the MCP
    public func executeCommand(_ command: String) async throws -> [String: Any] {
        guard isRunning else {
            throw MCPError.notRunning
        }
        
        // Create the request URL
        let commandURL = mcpServerURL.appendingPathComponent("command")
        
        // Create the request
        var request = URLRequest(url: commandURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let body: [String: Any] = ["command": command]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Send the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check the response
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MCPError.invalidResponse
        }
        
        // Parse the JSON
        if let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return result
        } else {
            throw MCPError.invalidResponse
        }
    }
}

/// Errors that can occur in the MCP bridge
public enum MCPError: Error {
    /// The MCP is not running
    case notRunning
    
    /// The MCP returned an invalid response
    case invalidResponse
    
    /// The MCP command execution failed
    case executionFailed(String)
}

/// Extension to provide localized descriptions for MCP errors
extension MCPError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "The MCP is not running"
        case .invalidResponse:
            return "The MCP returned an invalid response"
        case .executionFailed(let message):
            return "The MCP command execution failed: \(message)"
        }
    }
} 