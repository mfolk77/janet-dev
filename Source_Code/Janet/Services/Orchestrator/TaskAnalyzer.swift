//
//  TaskAnalyzer.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os
import NaturalLanguage

/// Analyzes tasks to determine the most appropriate model
public class TaskAnalyzer {
    // MARK: - Private Properties
    
    /// Logger for the task analyzer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "TaskAnalyzer")
    
    /// NLP tagger for analyzing prompts
    private let tagger = NLTagger(tagSchemes: [.lemma, .nameType, .lexicalClass])
    
    /// Keywords that indicate specific task types
    private let taskKeywords: [TaskType: Set<String>] = [
        .code: ["code", "function", "program", "script", "algorithm", "programming", "developer", "software", "class", "method", "debug", "fix", "error", "bug", "compile", "syntax", "api", "library", "framework", "module", "package", "import", "export", "variable", "constant", "parameter", "argument", "return", "value", "type", "interface", "implementation", "inheritance", "polymorphism", "encapsulation", "abstraction", "object", "instance", "constructor", "destructor", "static", "dynamic", "public", "private", "protected", "internal", "virtual", "override", "abstract", "final", "sealed", "partial", "extension", "protocol", "delegate", "event", "callback", "handler", "listener", "observer", "subscriber", "publisher", "async", "await", "promise", "future", "task", "thread", "process", "concurrency", "parallelism", "synchronization", "mutex", "semaphore", "lock", "atomic", "volatile", "transaction", "commit", "rollback", "database", "query", "sql", "nosql", "orm", "entity", "repository", "dao", "dto", "model", "view", "controller", "presenter", "viewmodel", "mvvm", "mvc", "mvp", "clean", "architecture", "design", "pattern", "singleton", "factory", "builder", "prototype", "adapter", "decorator", "facade", "proxy", "bridge", "composite", "flyweight", "chain", "command", "interpreter", "iterator", "mediator", "memento", "observer", "state", "strategy", "template", "visitor"],
        .summarization: ["summarize", "summary", "brief", "condense", "shorten", "overview", "synopsis", "recap", "tldr"],
        .reasoning: ["reason", "logic", "analyze", "deduce", "infer", "think", "consider", "evaluate", "assess", "judge"],
        .financial: ["finance", "financial", "money", "stock", "market", "investment", "economy", "economic", "budget", "profit", "loss", "revenue", "expense", "cash", "fund", "asset", "liability", "equity", "dividend", "portfolio"],
        .healthcare: ["health", "medical", "doctor", "patient", "disease", "treatment", "diagnosis", "symptom", "hospital", "clinic", "medicine", "drug", "therapy", "surgery", "prescription"],
        .business: ["business", "company", "corporation", "enterprise", "organization", "firm", "industry", "market", "customer", "client", "product", "service", "strategy", "management", "executive", "ceo", "cfo", "coo", "board", "stakeholder"],
        .systemCommand: ["execute", "run", "command", "shell", "terminal", "bash", "zsh", "script", "system", "process", "directory", "folder", "file", "path", "list", "ls", "find", "grep", "cat", "head", "tail", "mkdir", "touch", "mv", "cp", "rm", "echo", "pwd"],
        .fileSystem: ["file", "directory", "folder", "path", "create", "delete", "remove", "move", "copy", "rename", "list", "search", "find", "read", "write", "append", "modify", "update", "permission", "access", "owner", "group", "size", "date", "time", "extension", "type", "format", "compress", "extract", "archive", "zip", "unzip", "tar", "gzip", "bzip2"]
    ]
    
    // MARK: - Initialization
    
    /// Initialize a new task analyzer
    public init() {
        logger.info("Initializing TaskAnalyzer")
    }
    
    // MARK: - Public Methods
    
    /// Analyze a task to determine the most appropriate model(s)
    /// - Parameters:
    ///   - taskType: The type of task
    ///   - prompt: The input prompt
    ///   - availableModels: The available models
    /// - Returns: The selected models
    public func analyzeTask(
        taskType: TaskType,
        prompt: String,
        availableModels: [RegisteredModel]
    ) async throws -> [RegisteredModel] {
        logger.info("Analyzing task of type: \(String(describing: taskType))")
        
        // If no models are available, throw an error
        guard !availableModels.isEmpty else {
            logger.error("No models available for task analysis")
            throw TaskAnalyzerError.noModelsAvailable
        }
        
        // Determine the actual task type based on the prompt and provided task type
        let detectedTaskType = await detectTaskType(prompt: prompt, providedTaskType: taskType)
        logger.info("Detected task type: \(String(describing: detectedTaskType))")
        
        // Get models that support the detected task type
        var supportingModels = availableModels.filter { model in
            model.capabilities.supportedTasks.contains(detectedTaskType)
        }
        
        // If no models support the detected task type, fall back to models that support general tasks
        if supportingModels.isEmpty {
            logger.warning("No models support task type: \(String(describing: detectedTaskType)), falling back to general models")
            supportingModels = availableModels.filter { model in
                model.capabilities.supportedTasks.contains(.general)
            }
        }
        
        // If still no models are available, throw an error
        guard !supportingModels.isEmpty else {
            logger.error("No suitable models found for task type: \(String(describing: detectedTaskType))")
            throw TaskAnalyzerError.noSuitableModel
        }
        
        // Rank models based on their suitability for the task
        let rankedModels = rankModels(models: supportingModels, taskType: detectedTaskType, prompt: prompt)
        
        // Return the top models (up to 3)
        let selectedModels = Array(rankedModels.prefix(3))
        logger.info("Selected \(selectedModels.count) models for task")
        
        return selectedModels
    }
    
    // MARK: - Private Methods
    
    /// Detect the task type based on the prompt and provided task type
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - providedTaskType: The provided task type
    /// - Returns: The detected task type
    private func detectTaskType(prompt: String, providedTaskType: TaskType) async -> TaskType {
        // If the provided task type is not general, use it
        if providedTaskType != .general {
            return providedTaskType
        }
        
        // Normalize the prompt
        let normalizedPrompt = prompt.lowercased()
        
        // Check for code-related keywords
        if containsKeywords(normalizedPrompt, for: .code) {
            return .code
        }
        
        // Check for system command keywords
        if containsKeywords(normalizedPrompt, for: .systemCommand) {
            return .systemCommand
        }
        
        // Check for file system keywords
        if containsKeywords(normalizedPrompt, for: .fileSystem) {
            return .fileSystem
        }
        
        // Check for other task types
        for taskType in TaskType.allCases where taskType != .general && taskType != .code && taskType != .systemCommand && taskType != .fileSystem {
            if containsKeywords(normalizedPrompt, for: taskType) {
                return taskType
            }
        }
        
        // Default to general
        return .general
    }
    
    /// Rank models based on their suitability for the task
    /// - Parameters:
    ///   - models: The models to rank
    ///   - taskType: The type of task
    ///   - prompt: The input prompt
    /// - Returns: The ranked models
    private func rankModels(models: [RegisteredModel], taskType: TaskType, prompt: String) -> [RegisteredModel] {
        // Create a copy of the models
        var rankedModels = models
        
        // For code tasks, prioritize DeepSeek Coder
        if taskType == .code {
            // Move DeepSeek Coder to the top if available
            if let deepSeekCoderIndex = rankedModels.firstIndex(where: { $0.modelType == .deepseekCoder }) {
                let deepSeekCoder = rankedModels.remove(at: deepSeekCoderIndex)
                rankedModels.insert(deepSeekCoder, at: 0)
            }
        }
        
        // Sort by priority (lower is higher priority)
        rankedModels.sort { $0.priority < $1.priority }
        
        return rankedModels
    }
    
    /// Check if the prompt contains keywords for a specific task type
    /// - Parameters:
    ///   - prompt: The prompt to check
    ///   - taskType: The task type to check for
    /// - Returns: Whether the prompt contains keywords for the task type
    private func containsKeywords(_ prompt: String, for taskType: TaskType) -> Bool {
        guard let keywords = taskKeywords[taskType] else {
            return false
        }
        
        for keyword in keywords {
            if prompt.contains(keyword) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Task Analyzer Errors

/// Errors that can occur in the task analyzer
public enum TaskAnalyzerError: Error {
    /// No models are available
    case noModelsAvailable
    
    /// No suitable model was found for the task
    case noSuitableModel
} 