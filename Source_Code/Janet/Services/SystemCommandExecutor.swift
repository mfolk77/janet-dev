//
//  SystemCommandExecutor.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os

/// Executes system commands with sandboxing and permission control
public class SystemCommandExecutor {
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = SystemCommandExecutor()
    
    // MARK: - Private Properties
    
    /// Logger for the system command executor
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "SystemCommandExecutor")
    
    /// Queue for thread safety
    private let queue = DispatchQueue(label: "com.janet.ai.systemCommandExecutor", qos: .userInitiated)
    
    /// Allowed commands
    private let allowedCommands: Set<String> = ["ls", "find", "grep", "cat", "head", "tail", "mkdir", "touch", "mv", "cp", "rm", "echo", "pwd"]
    
    /// Allowed directories
    private var allowedDirectories: [URL] = []
    
    /// Whether dangerous commands are allowed (requires explicit permission)
    private var allowDangerousCommands: Bool = false
    
    // MARK: - Initialization
    
    /// Initialize a new system command executor
    private init() {
        logger.info("Initializing SystemCommandExecutor")
        
        // Set up allowed directories
        setupAllowedDirectories()
    }
    
    // MARK: - Public Methods
    
    /// Execute a system command
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Arguments for the command
    ///   - workingDirectory: Working directory for the command
    ///   - environment: Environment variables for the command
    /// - Returns: The command output
    public func executeCommand(
        command: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil
    ) async throws -> CommandResult {
        logger.info("Executing command: \(command) \(arguments.joined(separator: " "))")
        
        // Check if the command is allowed
        guard isCommandAllowed(command) else {
            logger.error("Command not allowed: \(command)")
            throw SystemCommandError.commandNotAllowed(command: command)
        }
        
        // Check if the working directory is allowed
        if let workingDirectory = workingDirectory {
            guard isDirectoryAllowed(workingDirectory) else {
                logger.error("Working directory not allowed: \(workingDirectory.path)")
                throw SystemCommandError.directoryNotAllowed(path: workingDirectory.path)
            }
        }
        
        // Check for dangerous arguments
        if containsDangerousArguments(command: command, arguments: arguments) {
            guard allowDangerousCommands else {
                logger.error("Dangerous arguments detected: \(command) \(arguments.joined(separator: " "))")
                throw SystemCommandError.dangerousArguments
            }
            
            logger.warning("Executing command with dangerous arguments: \(command) \(arguments.joined(separator: " "))")
        }
        
        // Create the process
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        // Set up the process
        process.executableURL = URL(fileURLWithPath: "/usr/bin/\(command)")
        process.arguments = arguments
        
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        
        if let environment = environment {
            process.environment = environment
        }
        
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        // Log the command
        logger.info("Executing: \(process.executableURL?.path ?? "unknown") \(arguments.joined(separator: " "))")
        
        // Execute the command
        do {
            try process.run()
            process.waitUntilExit()
            
            // Get the output
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            // Create the result
            let result = CommandResult(
                exitCode: Int(process.terminationStatus),
                output: output,
                error: error
            )
            
            // Log the result
            logger.info("Command completed with exit code: \(result.exitCode)")
            
            if !result.error.isEmpty {
                logger.warning("Command error output: \(result.error)")
            }
            
            return result
        } catch {
            logger.error("Failed to execute command: \(error.localizedDescription)")
            throw SystemCommandError.executionFailed(error: error)
        }
    }
    
    /// List files in a directory
    /// - Parameter directory: The directory to list
    /// - Returns: Array of file names
    public func listDirectory(directory: URL) async throws -> [String] {
        logger.info("Listing directory: \(directory.path)")
        
        // Check if the directory is allowed
        guard isDirectoryAllowed(directory) else {
            logger.error("Directory not allowed: \(directory.path)")
            throw SystemCommandError.directoryNotAllowed(path: directory.path)
        }
        
        // List the directory
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(atPath: directory.path)
            
            logger.info("Found \(contents.count) items in directory")
            return contents
        } catch {
            logger.error("Failed to list directory: \(error.localizedDescription)")
            throw SystemCommandError.fileSystemError(error: error)
        }
    }
    
    /// Move a file or directory
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination path
    public func moveItem(source: URL, destination: URL) async throws {
        logger.info("Moving item from \(source.path) to \(destination.path)")
        
        // Check if the source and destination are allowed
        guard isDirectoryAllowed(source) else {
            logger.error("Source directory not allowed: \(source.path)")
            throw SystemCommandError.directoryNotAllowed(path: source.path)
        }
        
        guard isDirectoryAllowed(destination) else {
            logger.error("Destination directory not allowed: \(destination.path)")
            throw SystemCommandError.directoryNotAllowed(path: destination.path)
        }
        
        // Move the item
        do {
            let fileManager = FileManager.default
            try fileManager.moveItem(at: source, to: destination)
            
            logger.info("Item moved successfully")
        } catch {
            logger.error("Failed to move item: \(error.localizedDescription)")
            throw SystemCommandError.fileSystemError(error: error)
        }
    }
    
    /// Copy a file or directory
    /// - Parameters:
    ///   - source: Source path
    ///   - destination: Destination path
    public func copyItem(source: URL, destination: URL) async throws {
        logger.info("Copying item from \(source.path) to \(destination.path)")
        
        // Check if the source and destination are allowed
        guard isDirectoryAllowed(source) else {
            logger.error("Source directory not allowed: \(source.path)")
            throw SystemCommandError.directoryNotAllowed(path: source.path)
        }
        
        guard isDirectoryAllowed(destination) else {
            logger.error("Destination directory not allowed: \(destination.path)")
            throw SystemCommandError.directoryNotAllowed(path: destination.path)
        }
        
        // Copy the item
        do {
            let fileManager = FileManager.default
            try fileManager.copyItem(at: source, to: destination)
            
            logger.info("Item copied successfully")
        } catch {
            logger.error("Failed to copy item: \(error.localizedDescription)")
            throw SystemCommandError.fileSystemError(error: error)
        }
    }
    
    /// Delete a file or directory
    /// - Parameter path: Path to delete
    public func deleteItem(path: URL) async throws {
        logger.info("Deleting item at \(path.path)")
        
        // Check if the path is allowed
        guard isDirectoryAllowed(path) else {
            logger.error("Path not allowed: \(path.path)")
            throw SystemCommandError.directoryNotAllowed(path: path.path)
        }
        
        // Delete the item
        do {
            let fileManager = FileManager.default
            try fileManager.removeItem(at: path)
            
            logger.info("Item deleted successfully")
        } catch {
            logger.error("Failed to delete item: \(error.localizedDescription)")
            throw SystemCommandError.fileSystemError(error: error)
        }
    }
    
    /// Create a directory
    /// - Parameter path: Path to create
    public func createDirectory(path: URL) async throws {
        logger.info("Creating directory at \(path.path)")
        
        // Check if the path is allowed
        guard isDirectoryAllowed(path) else {
            logger.error("Path not allowed: \(path.path)")
            throw SystemCommandError.directoryNotAllowed(path: path.path)
        }
        
        // Create the directory
        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            
            logger.info("Directory created successfully")
        } catch {
            logger.error("Failed to create directory: \(error.localizedDescription)")
            throw SystemCommandError.fileSystemError(error: error)
        }
    }
    
    /// Set whether dangerous commands are allowed
    /// - Parameter allowed: Whether dangerous commands are allowed
    public func setAllowDangerousCommands(_ allowed: Bool) {
        logger.info("Setting allow dangerous commands: \(allowed)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.allowDangerousCommands = allowed
        }
    }
    
    /// Add an allowed directory
    /// - Parameter directory: Directory to allow
    public func addAllowedDirectory(_ directory: URL) {
        logger.info("Adding allowed directory: \(directory.path)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if the directory is already allowed
            if !self.allowedDirectories.contains(directory) {
                self.allowedDirectories.append(directory)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Set up allowed directories
    private func setupAllowedDirectories() {
        logger.info("Setting up allowed directories")
        
        // Add default allowed directories
        let fileManager = FileManager.default
        
        // Add the user's home directory
        if let homeDirectory = fileManager.homeDirectoryForCurrentUser as URL? {
            allowedDirectories.append(homeDirectory)
            
            // Add common subdirectories
            allowedDirectories.append(homeDirectory.appendingPathComponent("Documents"))
            allowedDirectories.append(homeDirectory.appendingPathComponent("Downloads"))
            allowedDirectories.append(homeDirectory.appendingPathComponent("Desktop"))
        }
        
        // Add the temporary directory
        if let tempDirectory = URL(string: NSTemporaryDirectory()) {
            allowedDirectories.append(tempDirectory)
        }
        
        // Add the application support directory
        if let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            allowedDirectories.append(appSupportDirectory)
        }
    }
    
    /// Check if a command is allowed
    /// - Parameter command: The command to check
    /// - Returns: Whether the command is allowed
    private func isCommandAllowed(_ command: String) -> Bool {
        return allowedCommands.contains(command)
    }
    
    /// Check if a directory is allowed
    /// - Parameter directory: The directory to check
    /// - Returns: Whether the directory is allowed
    private func isDirectoryAllowed(_ directory: URL) -> Bool {
        // Check if the directory is in the allowed directories
        for allowedDirectory in allowedDirectories {
            if directory.path.hasPrefix(allowedDirectory.path) {
                return true
            }
        }
        
        return false
    }
    
    /// Check if a command contains dangerous arguments
    /// - Parameters:
    ///   - command: The command
    ///   - arguments: The arguments
    /// - Returns: Whether the command contains dangerous arguments
    private func containsDangerousArguments(command: String, arguments: [String]) -> Bool {
        // Check for dangerous patterns
        let dangerousPatterns = [
            "rm -rf /",
            "rm -rf /*",
            "> /dev/",
            "< /dev/",
            "|",
            ";",
            "&&",
            "||",
            "`",
            "$(",
            "sudo",
            "su"
        ]
        
        // Combine command and arguments
        let fullCommand = "\(command) \(arguments.joined(separator: " "))"
        
        // Check for dangerous patterns
        for pattern in dangerousPatterns {
            if fullCommand.contains(pattern) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Command Result

/// Result of a command execution
public struct CommandResult {
    /// Exit code of the command
    public let exitCode: Int
    
    /// Standard output of the command
    public let output: String
    
    /// Standard error of the command
    public let error: String
    
    /// Whether the command was successful
    public var isSuccess: Bool {
        return exitCode == 0
    }
}

// MARK: - System Command Error

/// Errors that can occur in system command execution
public enum SystemCommandError: Error {
    /// Command is not allowed
    case commandNotAllowed(command: String)
    
    /// Directory is not allowed
    case directoryNotAllowed(path: String)
    
    /// Command contains dangerous arguments
    case dangerousArguments
    
    /// Command execution failed
    case executionFailed(error: Error)
    
    /// File system operation failed
    case fileSystemError(error: Error)
}

// MARK: - System Command Error Extension

extension SystemCommandError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .commandNotAllowed(let command):
            return "Command not allowed: \(command)"
        case .directoryNotAllowed(let path):
            return "Directory not allowed: \(path)"
        case .dangerousArguments:
            return "Command contains dangerous arguments"
        case .executionFailed(let error):
            return "Command execution failed: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system operation failed: \(error.localizedDescription)"
        }
    }
} 