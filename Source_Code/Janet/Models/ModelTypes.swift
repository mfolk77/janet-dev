//
//  ModelTypes.swift
//  Janet
//
//  Created by Michael folk on 2/25/25.
//

import Foundation

/// Model errors that can occur during model operations
public enum ModelError: Error {
    case modelNotFound
    case tokenizerNotFound
    case modelNotLoaded
    case generationFailed(String)
    case invalidModelPath(path: String)
    case invalidTokenizerPath(path: String)
    case modelLoadFailed(reason: String)
    case invalidModelConfiguration
    case invalidPrompt
}

/// Types of models supported by Janet
public enum JanetModelType: String, CaseIterable, Codable, Sendable {
    case ollama // Default model type
    case llama
    case mistral
    case phi
    case auto
    case generic
    case deepseekCoder // Add DeepSeek Coder model type
    case gpt4 // OpenAI GPT-4 model
    case claude // Anthropic Claude model
    case code // Code-specific model
    
    /// Get the workspace path
    private static func getWorkspacePath() -> String {
        // Try to get the path from the bundle
        if let bundlePath = Bundle.main.bundlePath.components(separatedBy: "/Janet.app").first {
            return bundlePath
        }
        
        // Fallback to the known workspace path
        return "/Volumes/Folk_DAS/Janet"
    }
    
    /// Get the default model path for this model type
    public var defaultModelPath: String {
        // Get the workspace path
        let workspacePath = JanetModelType.getWorkspacePath()
        
        switch self {
        case .ollama:
            return "\(workspacePath)/Models/Ollama"
        case .llama:
            return "/Users/Shared/Models/Llama-3"
        case .mistral:
            return "/Users/Shared/Models/Mistral"
        case .phi:
            return "/Users/Shared/Models/Phi"
        case .auto, .generic:
            return "\(workspacePath)/Models/Ollama"
        case .deepseekCoder:
            return "/Users/Shared/Models/DeepSeekCoder"
        case .gpt4:
            return "/Users/Shared/Models/GPT-4"
        case .claude:
            return "/Users/Shared/Models/Claude"
        case .code:
            return "/Users/Shared/Models/Code"
        }
    }
    
    /// Get the default tokenizer path for this model type
    public var defaultTokenizerPath: String {
        // Get the workspace path
        let workspacePath = JanetModelType.getWorkspacePath()
        
        switch self {
        case .ollama:
            return "\(workspacePath)/Models/Ollama/tokenizer.json"
        case .llama:
            return "/Users/Shared/Models/Llama-3/tokenizer.json"
        case .mistral:
            return "/Users/Shared/Models/Mistral/tokenizer.json"
        case .phi:
            return "/Users/Shared/Models/Phi/tokenizer.json"
        case .auto, .generic:
            return "\(workspacePath)/Models/Ollama/tokenizer.json"
        case .deepseekCoder:
            return "/Users/Shared/Models/DeepSeekCoder/tokenizer.json"
        case .gpt4:
            return "/Users/Shared/Models/GPT-4/tokenizer.json"
        case .claude:
            return "/Users/Shared/Models/Claude/tokenizer.json"
        case .code:
            return "/Users/Shared/Models/Code/tokenizer.json"
        }
    }
    
    /// Display name
    public var displayName: String {
        switch self {
        case .ollama:
            return "Ollama"
        case .llama:
            return "Llama-3"
        case .mistral:
            return "Mistral"
        case .phi:
            return "Phi"
        case .auto:
            return "Auto"
        case .generic:
            return "Generic"
        case .deepseekCoder:
            return "DeepSeek Coder"
        case .gpt4:
            return "GPT-4"
        case .claude:
            return "Claude"
        case .code:
            return "Code"
        }
    }
    
    /// Check if the model files exist at the default paths
    public var modelFilesExist: Bool {
        // For Ollama models, we don't need to check for files
        if self == .ollama {
            return true
        }
        
        let modelPath = self.defaultModelPath
        let tokenizerPath = self.defaultTokenizerPath
        
        return FileManager.default.fileExists(atPath: modelPath) && 
               FileManager.default.fileExists(atPath: tokenizerPath)
    }
    
    /// Get alternative model paths if the default ones don't exist
    public var alternativeModelPaths: [String] {
        let workspacePath = JanetModelType.getWorkspacePath()
        
        switch self {
        case .ollama:
            return [
                "\(workspacePath)/Models/Ollama",
                "/Users/Shared/Models/Ollama",
                "/Applications/Janet.app/Contents/Resources/Models/Ollama"
            ]
        default:
            return [self.defaultModelPath]
        }
    }
    
    /// Find the first valid model path from the alternatives
    public var firstValidModelPath: String? {
        // For Ollama models, we don't need to check for files
        if self == .ollama {
            return self.defaultModelPath
        }
        
        // Check the default path first
        if FileManager.default.fileExists(atPath: self.defaultModelPath) {
            return self.defaultModelPath
        }
        
        // Check the alternatives
        for path in self.alternativeModelPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    // Custom model type support
    /// Create a custom model type from an ID
    /// - Parameter id: The ID of the custom model
    /// - Returns: A custom model type if valid, nil otherwise
    public static func custom(_ id: String) -> JanetModelType? {
        return JanetModelType(rawValue: "custom_\(id)")
    }
} 