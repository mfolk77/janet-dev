//
//  FileSystemOptimizer.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os

/// Optimizes and cleans up the file system
public class FileSystemOptimizer {
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = FileSystemOptimizer()
    
    // MARK: - Private Properties
    
    /// Logger for the file system optimizer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "FileSystemOptimizer")
    
    /// Queue for thread safety
    private let queue = DispatchQueue(label: "com.janet.ai.fileSystemOptimizer", qos: .userInitiated)
    
    /// System command executor
    private let systemCommandExecutor = SystemCommandExecutor.shared
    
    /// File extensions to ignore
    private let ignoredExtensions: Set<String> = [".DS_Store", ".git", ".gitignore", ".gitattributes", ".gitmodules", ".svn", ".hg", ".bzr", ".idea", ".vscode", ".vs", ".project", ".settings", ".classpath", ".metadata", ".iml", ".ipr", ".iws", ".suo", ".user", ".sln", ".vcxproj", ".vcproj", ".xcodeproj", ".xcworkspace", ".pbxproj", ".pbxuser", ".mode1v3", ".mode2v3", ".perspectivev3", ".xcuserstate", ".xcsettings", ".xcscheme", ".xccheckout", ".xcscmblueprint", ".xctimeline", ".xcactivitylog", ".xcresult", ".xcbaseline", ".xcappdata", ".xcarchive", ".xcworkspacedata", ".xcuserdata", ".xcassets", ".xib", ".storyboard", ".nib", ".xcdatamodeld", ".xcdatamodel", ".xcmappingmodel", ".xcfilelist", ".xcconfig", ".xcscheme", ".xcworkspace", ".xcodeproj", ".xcassets", ".xib", ".storyboard", ".nib", ".xcdatamodeld", ".xcdatamodel", ".xcmappingmodel", ".xcfilelist", ".xcconfig", ".xcscheme", ".xcworkspace", ".xcodeproj", ".xcassets", ".xib", ".storyboard", ".nib", ".xcdatamodeld", ".xcdatamodel", ".xcmappingmodel", ".xcfilelist", ".xcconfig", ".xcscheme", ".xcworkspace", ".xcodeproj", ".xcassets", ".xib", ".storyboard", ".nib", ".xcdatamodeld", ".xcdatamodel", ".xcmappingmodel", ".xcfilelist", ".xcconfig", ".xcscheme", ".xcworkspace", ".xcodeproj", ".xcassets", ".xib", ".storyboard", ".nib", ".xcdatamodeld", ".xcdatamodel", ".xcmappingmodel", ".xcfilelist", ".xcconfig", ".xcscheme", ".xcworkspace", ".xcodeproj", ".xcassets", ".xib", ".storyboard", ".nib", ".xcdatamodeld", ".xcdatamodel", ".xcmappingmodel", ".xcfilelist", ".xcconfig", ".xcscheme"]
    
    // MARK: - Initialization
    
    /// Initialize a new file system optimizer
    private init() {
        logger.info("Initializing FileSystemOptimizer")
    }
    
    // MARK: - Public Methods
    
    /// Identify redundant and unused files
    /// - Parameter directory: The directory to scan
    /// - Returns: Array of redundant file paths
    public func identifyRedundantFiles(directory: URL) async throws -> [URL] {
        logger.info("Identifying redundant files in \(directory.path)")
        
        // Check if the directory exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            logger.error("Directory does not exist: \(directory.path)")
            throw FileSystemOptimizerError.directoryNotFound(path: directory.path)
        }
        
        // Get all files in the directory
        let files = try await getAllFiles(directory: directory)
        
        // Group files by content hash
        var filesByHash: [String: [URL]] = [:]
        
        for file in files {
            // Skip ignored extensions
            if ignoredExtensions.contains(file.pathExtension) {
                continue
            }
            
            // Calculate the hash of the file
            if let hash = try? await calculateFileHash(file: file) {
                if filesByHash[hash] == nil {
                    filesByHash[hash] = []
                }
                
                filesByHash[hash]?.append(file)
            }
        }
        
        // Find duplicates
        var redundantFiles: [URL] = []
        
        for (_, files) in filesByHash {
            if files.count > 1 {
                // Keep the first file, mark the rest as redundant
                redundantFiles.append(contentsOf: files.dropFirst())
            }
        }
        
        logger.info("Found \(redundantFiles.count) redundant files")
        return redundantFiles
    }
    
    /// Organize and structure directories
    /// - Parameter directory: The directory to organize
    /// - Returns: Array of actions taken
    public func organizeDirectories(directory: URL) async throws -> [String] {
        logger.info("Organizing directories in \(directory.path)")
        
        // Check if the directory exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            logger.error("Directory does not exist: \(directory.path)")
            throw FileSystemOptimizerError.directoryNotFound(path: directory.path)
        }
        
        // Get all files in the directory
        let files = try await getAllFiles(directory: directory)
        
        // Group files by extension
        var filesByExtension: [String: [URL]] = [:]
        
        for file in files {
            let fileExtension = file.pathExtension.lowercased()
            
            // Skip ignored extensions
            if ignoredExtensions.contains(fileExtension) {
                continue
            }
            
            if filesByExtension[fileExtension] == nil {
                filesByExtension[fileExtension] = []
            }
            
            filesByExtension[fileExtension]?.append(file)
        }
        
        // Create directories for each extension
        var actions: [String] = []
        
        for (fileExtension, files) in filesByExtension {
            // Skip if there are too few files
            if files.count < 5 {
                continue
            }
            
            // Create a directory for this extension
            let extensionDirectory = directory.appendingPathComponent(fileExtension)
            
            if !fileManager.fileExists(atPath: extensionDirectory.path) {
                try fileManager.createDirectory(at: extensionDirectory, withIntermediateDirectories: true, attributes: nil)
                actions.append("Created directory: \(extensionDirectory.lastPathComponent)")
            }
            
            // Move files to the directory
            for file in files {
                let destination = extensionDirectory.appendingPathComponent(file.lastPathComponent)
                
                // Skip if the file is already in the correct directory
                if file.deletingLastPathComponent().path == extensionDirectory.path {
                    continue
                }
                
                try fileManager.moveItem(at: file, to: destination)
                actions.append("Moved \(file.lastPathComponent) to \(extensionDirectory.lastPathComponent)")
            }
        }
        
        logger.info("Took \(actions.count) actions to organize directories")
        return actions
    }
    
    /// Clean up temporary files
    /// - Returns: Array of deleted file paths
    public func cleanupTemporaryFiles() async throws -> [URL] {
        logger.info("Cleaning up temporary files")
        
        // Get the temporary directory
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        
        // Get all files in the temporary directory
        let fileManager = FileManager.default
        let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil, options: [])
        
        // Delete files older than 7 days
        var deletedFiles: [URL] = []
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        for file in tempFiles {
            // Get the file attributes
            let attributes = try fileManager.attributesOfItem(atPath: file.path)
            
            // Get the creation date
            if let creationDate = attributes[.creationDate] as? Date {
                if creationDate < sevenDaysAgo {
                    try fileManager.removeItem(at: file)
                    deletedFiles.append(file)
                }
            }
        }
        
        logger.info("Deleted \(deletedFiles.count) temporary files")
        return deletedFiles
    }
    
    /// Optimize file system structure
    /// - Parameter directory: The directory to optimize
    /// - Returns: Array of actions taken
    public func optimizeFileSystem(directory: URL) async throws -> [String] {
        logger.info("Optimizing file system in \(directory.path)")
        
        // Check if the directory exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else {
            logger.error("Directory does not exist: \(directory.path)")
            throw FileSystemOptimizerError.directoryNotFound(path: directory.path)
        }
        
        var actions: [String] = []
        
        // Identify redundant files
        let redundantFiles = try await identifyRedundantFiles(directory: directory)
        
        // Delete redundant files
        for file in redundantFiles {
            try fileManager.removeItem(at: file)
            actions.append("Deleted redundant file: \(file.lastPathComponent)")
        }
        
        // Organize directories
        let organizationActions = try await organizeDirectories(directory: directory)
        actions.append(contentsOf: organizationActions)
        
        // Clean up temporary files
        let deletedTempFiles = try await cleanupTemporaryFiles()
        for file in deletedTempFiles {
            actions.append("Deleted temporary file: \(file.lastPathComponent)")
        }
        
        logger.info("Took \(actions.count) actions to optimize file system")
        return actions
    }
    
    // MARK: - Private Methods
    
    /// Get all files in a directory recursively
    /// - Parameter directory: The directory to scan
    /// - Returns: Array of file URLs
    private func getAllFiles(directory: URL) async throws -> [URL] {
        logger.info("Getting all files in \(directory.path)")
        
        // Use the system command executor to find all files
        let result = try await systemCommandExecutor.executeCommand(
            command: "find",
            arguments: [directory.path, "-type", "f"],
            workingDirectory: nil,
            environment: nil
        )
        
        // Parse the output
        let files = result.output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
        
        logger.info("Found \(files.count) files")
        return files
    }
    
    /// Calculate the hash of a file
    /// - Parameter file: The file to hash
    /// - Returns: The hash of the file
    private func calculateFileHash(file: URL) async throws -> String {
        logger.info("Calculating hash for \(file.path)")
        
        // Use the system command executor to calculate the hash
        let result = try await systemCommandExecutor.executeCommand(
            command: "md5",
            arguments: [file.path],
            workingDirectory: nil,
            environment: nil
        )
        
        // Parse the output
        let hash = result.output
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .last ?? ""
        
        return hash
    }
}

// MARK: - File System Optimizer Error

/// Errors that can occur in file system optimization
public enum FileSystemOptimizerError: Error {
    /// Directory not found
    case directoryNotFound(path: String)
    
    /// Failed to calculate file hash
    case hashCalculationFailed(path: String)
    
    /// Failed to move file
    case fileMoveFailed(path: String)
    
    /// Failed to delete file
    case fileDeleteFailed(path: String)
}

// MARK: - File System Optimizer Error Extension

extension FileSystemOptimizerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .hashCalculationFailed(let path):
            return "Failed to calculate hash for file: \(path)"
        case .fileMoveFailed(let path):
            return "Failed to move file: \(path)"
        case .fileDeleteFailed(let path):
            return "Failed to delete file: \(path)"
        }
    }
} 