//
//  CommandHandler.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import Foundation
import AppKit

class CommandHandler: ObservableObject {
    
    // Command prefixes that indicate a system command
    private let commandPrefixes = [
        "janet run",
        "janet execute",
        "janet open",
        "janet write",
        "janet create",
        "janet search",
        "janet find",
        "run command",
        "execute command",
        "system command"
    ]
    
    // Check if the input is a command
    func isCommand(_ input: String) async -> Bool {
        let lowercased = input.lowercased()
        return commandPrefixes.contains { lowercased.hasPrefix($0) }
    }
    
    // Process a command and return the result
    func processCommand(_ input: String) async -> String {
        print("Processing command: \(input)")
        
        let lowercased = input.lowercased()
        
        // Extract the actual command (remove the prefix)
        var actualCommand = input
        for prefix in commandPrefixes {
            if lowercased.hasPrefix(prefix) {
                actualCommand = String(input.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Check command type
        if lowercased.contains("open") {
            return await openApplication(actualCommand)
        } else if lowercased.contains("write") || lowercased.contains("create file") {
            return await writeFile(actualCommand)
        } else if lowercased.contains("search") || lowercased.contains("find") {
            return await searchFiles(actualCommand)
        } else {
            // Default to shell command execution
            return await executeShellCommand(actualCommand)
        }
    }
    
    // Execute a shell command
    private func executeShellCommand(_ command: String) async -> String {
        // Security check - only allow safe commands
        guard isSafeCommand(command) else {
            return "Sorry, this command is not allowed for security reasons. I can only run safe informational commands."
        }
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        do {
            try task.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "No output"
            
            // Limit output size
            let maxOutputSize = 2000
            if output.count > maxOutputSize {
                return "Command executed successfully. Output (truncated):\n\n\(output.prefix(maxOutputSize))...\n\n(Output truncated. Full length: \(output.count) characters)"
            } else {
                return "Command executed successfully. Output:\n\n\(output)"
            }
        } catch {
            return "Error executing command: \(error.localizedDescription)"
        }
    }
    
    // Open an application
    private func openApplication(_ input: String) async -> String {
        // Try to extract app name
        var appName = input
        
        // Check for common patterns like "open X" or "launch X"
        if let range = input.range(of: "open\\s+|launch\\s+", options: .regularExpression) {
            appName = String(input[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Add .app extension if not present
        if !appName.lowercased().hasSuffix(".app") {
            appName += ".app"
        }
        
        // Common app locations
        let appLocations = [
            "/Applications/",
            "/Applications/Utilities/",
            "/System/Applications/"
        ]
        
        for location in appLocations {
            let appPath = location + appName
            if FileManager.default.fileExists(atPath: appPath) {
                let url = URL(fileURLWithPath: appPath)
                
                do {
                    try NSWorkspace.shared.open(url)
                    return "Successfully opened \(appName)"
                } catch {
                    return "Error opening \(appName): \(error.localizedDescription)"
                }
            }
        }
        
        return "Could not find application: \(appName)"
    }
    
    // Write content to a file
    private func writeFile(_ input: String) async -> String {
        // Try to parse file path and content
        let components = input.components(separatedBy: " with content ")
        
        guard components.count >= 2 else {
            return "Please specify both a file path and content. Format: 'write [file path] with content [content]'"
        }
        
        var filePath = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove "to" or "file" prefix if present
        if let range = filePath.range(of: "^(to|file)\\s+", options: .regularExpression) {
            filePath = String(filePath[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract content (everything after "with content")
        let content = components[1...].joined(separator: " with content ")
        
        // Expand ~ to home directory if present
        if filePath.hasPrefix("~") {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            filePath = homeDirectory + filePath.dropFirst()
        }
        
        // Make sure the directory exists
        let directoryURL = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            // Write the file
            try content.write(toFile: filePath, atomically: true, encoding: .utf8)
            return "Successfully wrote content to \(filePath)"
        } catch {
            return "Error writing file: \(error.localizedDescription)"
        }
    }
    
    // Search for files
    private func searchFiles(_ input: String) async -> String {
        var searchPath = "~"
        var searchTerm = input
        
        // Try to parse "search for X in Y" pattern
        if let match = input.range(of: "for\\s+(.+?)\\s+in\\s+(.+)", options: .regularExpression) {
            let matchedString = String(input[match])
            let components = matchedString.components(separatedBy: " in ")
            
            if components.count >= 2 {
                searchTerm = components[0].replacingOccurrences(of: "for ", with: "")
                searchPath = components[1]
            }
        } else if let match = input.range(of: "in\\s+(.+?)\\s+for\\s+(.+)", options: .regularExpression) {
            let matchedString = String(input[match])
            let components = matchedString.components(separatedBy: " for ")
            
            if components.count >= 2 {
                searchPath = components[0].replacingOccurrences(of: "in ", with: "")
                searchTerm = components[1]
            }
        }
        
        // Expand ~ to home directory if present
        if searchPath.hasPrefix("~") {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            searchPath = homeDirectory + searchPath.dropFirst()
        }
        
        // Create and execute the find command
        let command = "find \"\(searchPath)\" -name \"*\(searchTerm)*\" -type f -not -path \"*/\\.*\" | head -n 20"
        return await executeShellCommand(command)
    }
    
    // Security check for shell commands
    private func isSafeCommand(_ command: String) -> Bool {
        let lowercasedCommand = command.lowercased()
        
        // Block list of dangerous commands
        let blockedCommands = [
            "rm -rf", "rmdir", "mkfs", "dd", 
            "chmod 777", "chown", "sudo", "su",
            "> /dev/", "mv /", "wget", "curl",
            "shutdown", "reboot", "halt", 
            ":(){", "fork", "bomb"
        ]
        
        for blocked in blockedCommands {
            if lowercasedCommand.contains(blocked) {
                return false
            }
        }
        
        // Allow list approach - only permit certain informational commands
        let allowedCommands = [
            "ls", "pwd", "echo", "whoami", "hostname",
            "date", "cal", "uptime", "top", "ps",
            "df", "du", "find", "locate", "grep",
            "wc", "cat", "head", "tail", "uname",
            "sw_vers", "system_profiler", "diskutil list"
        ]
        
        // Check if the command starts with an allowed command
        for allowed in allowedCommands {
            if lowercasedCommand.hasPrefix(allowed) || 
               lowercasedCommand.hasPrefix("/bin/\(allowed)") ||
               lowercasedCommand.hasPrefix("/usr/bin/\(allowed)") {
                return true
            }
        }
        
        // By default, reject unknown commands
        return false
    }
}