//
//  ModelOrchestrator.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import Combine
import os

/// The central orchestrator that manages model selection, loading, and execution
public class ModelOrchestrator: ObservableObject {
    // MARK: - Singleton
    
    /// Shared instance of the ModelOrchestrator
    public static let shared = ModelOrchestrator()
    
    // MARK: - Published Properties
    
    /// Currently active model
    @Published public private(set) var activeModel: JanetModelType = .ollama
    
    /// Available models that can be used
    @Published public private(set) var availableModels: [RegisteredModel] = []
    
    /// Whether the orchestrator is currently processing a request
    @Published public private(set) var isProcessing: Bool = false
    
    /// Current execution mode
    @Published public var executionMode: ExecutionMode = .auto
    
    // MARK: - Private Properties
    
    /// Logger for the orchestrator
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "ModelOrchestrator")
    
    /// Model registry that manages available models
    public let modelRegistry = ModelRegistry()
    
    /// Task analyzer that determines the appropriate model for a task
    public let taskAnalyzer = TaskAnalyzer()
    
    /// Execution engine that handles model execution
    public let executionEngine = ExecutionEngine()
    
    /// Memory context manager
    public let memoryContextManager = MemoryContextManager()
    
    /// System command executor
    private let systemCommandExecutor = SystemCommandExecutor.shared
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        logger.info("Initializing ModelOrchestrator")
        
        // Register for notifications from ModelManager
        NotificationCenter.default.publisher(for: .modelLoadStateChanged)
            .sink { [weak self] notification in
                self?.handleModelLoadStateChanged(notification)
            }
            .store(in: &cancellables)
        
        // Initialize the model registry
        initializeModelRegistry()
    }
    
    // MARK: - Public Methods
    
    /// Generate text using the most appropriate model for the given task
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - taskType: The type of task to perform
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Temperature for generation
    ///   - topP: Top-p sampling parameter
    ///   - repetitionPenalty: Penalty for repetition
    /// - Returns: The generated text
    public func generateText(
        prompt: String,
        taskType: TaskType = .general,
        maxTokens: Int = 1024,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        repetitionPenalty: Float = 1.1
    ) async throws -> String {
        logger.info("Generating text for task type: \(String(describing: taskType))")
        
        // Update processing state
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            // Reset processing state when done
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Check if this is a system command task
        if taskType == .systemCommand || taskType == .fileSystem {
            return try await handleSystemCommand(prompt: prompt)
        }
        
        // Get available models
        let availableModels = modelRegistry.getAllRegisteredModels().filter { $0.isLoaded }
        
        // If no models are available, try to load at least one model
        if availableModels.isEmpty {
            logger.warning("No models available, attempting to load a model")
            
            // Try to load models in this priority order
            let modelTypesToTry: [JanetModelType] = [.phi, .ollama, .llama, .mistral]
            
            for modelType in modelTypesToTry {
                do {
                    logger.info("Attempting to load model: \(modelType.rawValue)")
                    try await ModelManager.shared.loadModel(type: modelType)
                    
                    // Update the model registry
                    modelRegistry.updateModelLoadState(modelType: modelType, isLoaded: true)
                    
                    // Break the loop if we successfully loaded a model
                    break
                } catch {
                    logger.error("Failed to load model \(modelType.rawValue): \(error.localizedDescription)")
                    // Continue to the next model
                }
            }
            
            // Check again if we have any available models
            let updatedAvailableModels = modelRegistry.getAllRegisteredModels().filter { $0.isLoaded }
            
            if updatedAvailableModels.isEmpty {
                logger.error("No models available for task after load attempts")
                throw OrchestratorError.noModelsAvailable
            }
        }
        
        // Get the updated list of available models
        let modelsToUse = modelRegistry.getAllRegisteredModels().filter { $0.isLoaded }
        
        // Analyze the task to determine the most appropriate model(s)
        let selectedModels: [RegisteredModel]
        do {
            selectedModels = try await taskAnalyzer.analyzeTask(
                taskType: taskType,
                prompt: prompt,
                availableModels: modelsToUse
            )
        } catch {
            logger.warning("Task analysis failed, falling back to available models: \(error.localizedDescription)")
            selectedModels = modelsToUse
        }
        
        // If no models were selected, use all available models
        let modelsForExecution = selectedModels.isEmpty ? modelsToUse : selectedModels
        
        // Generate context-aware prompt
        let contextAwarePrompt = await memoryContextManager.generateContextAwarePrompt(
            prompt: prompt,
            modelType: modelsForExecution.first?.modelType ?? .ollama
        )
        
        // Update the context with the context-aware prompt
        let contextAwareContext = RequestContext(
            prompt: contextAwarePrompt,
            taskType: taskType,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP,
            repetitionPenalty: repetitionPenalty
        )
        
        // Execute the request with automatic fallback
        var lastError: Error? = nil
        for model in modelsForExecution {
            do {
                logger.info("Attempting to execute with model: \(model.modelType.rawValue)")
                
                // Try to execute with this model
                let result = try await executionEngine.executeSingle(
                    context: contextAwareContext,
                    model: model
                )
                
                // If successful, store the result in memory and return
                await memoryContextManager.storeInteraction(
                    prompt: prompt,
                    response: result,
                    models: [model.modelType]
                )
                
                logger.info("Successfully generated text with model: \(model.modelType.rawValue)")
                return result
            } catch {
                logger.warning("Failed to execute with model \(model.modelType.rawValue): \(error.localizedDescription)")
                lastError = error
                // Continue to the next model
            }
        }
        
        // If we get here, all models failed
        logger.error("All models failed to generate text")
        
        // Try one last attempt with a simplified prompt
        if contextAwarePrompt != prompt {
            logger.info("Attempting with simplified prompt")
            
            let simplifiedContext = RequestContext(
                prompt: prompt,  // Use the original prompt without context
                taskType: taskType,
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                repetitionPenalty: repetitionPenalty
            )
            
            for model in modelsForExecution {
                do {
                    let result = try await executionEngine.executeSingle(
                        context: simplifiedContext,
                        model: model
                    )
                    
                    await memoryContextManager.storeInteraction(
                        prompt: prompt,
                        response: result,
                        models: [model.modelType]
                    )
                    
                    logger.info("Successfully generated text with simplified prompt")
                    return result
                } catch {
                    // Continue to the next model
                }
            }
        }
        
        // If we still get here, throw the last error
        throw lastError ?? OrchestratorError.modelGenerationFailed
    }
    
    /// Load a specific model
    /// - Parameter modelType: The type of model to load
    public func loadModel(modelType: JanetModelType) async throws {
        logger.info("Loading model: \(String(describing: modelType))")
        
        // Check if the model is already registered
        guard modelRegistry.isModelRegistered(modelType) else {
            logger.error("Model not registered: \(String(describing: modelType))")
            throw OrchestratorError.modelNotRegistered
        }
        
        // Load the model using ModelManager
        try await ModelManager.shared.loadModel(type: modelType)
        
        // Update the active model
        await MainActor.run {
            activeModel = modelType
        }
        
        logger.info("Model loaded successfully: \(String(describing: modelType))")
    }
    
    /// Unload a specific model to free up resources
    /// - Parameter modelType: The type of model to unload
    public func unloadModel(modelType: JanetModelType) async {
        logger.info("Unloading model: \(String(describing: modelType))")
        
        // Unload logic would go here
        // This would require extending ModelManager to support unloading
        
        logger.info("Model unloaded: \(String(describing: modelType))")
    }
    
    /// Register a new model with the orchestrator
    /// - Parameter model: The model to register
    public func registerModel(_ model: RegisteredModel) {
        logger.info("Registering model: \(model.modelType.rawValue)")
        
        modelRegistry.registerModel(model)
        
        // Update available models
        updateAvailableModels()
    }
    
    /// Unregister a model from the orchestrator
    /// - Parameter modelType: The type of model to unregister
    public func unregisterModel(modelType: JanetModelType) {
        logger.info("Unregistering model: \(String(describing: modelType))")
        
        modelRegistry.unregisterModel(modelType)
        
        // Update available models
        updateAvailableModels()
    }
    
    /// Get the capabilities of a specific model
    /// - Parameter modelType: The type of model
    /// - Returns: The capabilities of the model
    public func getModelCapabilities(modelType: JanetModelType) -> ModelCapabilities? {
        return modelRegistry.getModelCapabilities(modelType)
    }
    
    /// Execute a chain of models in sequence
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - modelChain: The sequence of models to use
    /// - Returns: The final result after processing through all models
    public func executeModelChain(prompt: String, modelChain: [JanetModelType]) async throws -> String {
        logger.info("Executing model chain with \(modelChain.count) models")
        
        // Update processing state
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            // Reset processing state when done
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Convert model types to registered models
        let registeredModels = modelChain.compactMap { modelType in
            modelRegistry.getRegisteredModel(modelType)
        }
        
        // Check if all models were found
        guard registeredModels.count == modelChain.count else {
            logger.error("Not all models in the chain are registered")
            throw OrchestratorError.modelNotRegistered
        }
        
        // Create request context
        let requestContext = RequestContext(
            prompt: prompt,
            taskType: .general,
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            repetitionPenalty: 1.1
        )
        
        // Execute the chain
        let result = try await executionEngine.executeChain(
            context: requestContext,
            modelChain: registeredModels
        )
        
        // Store the result in memory context
        await memoryContextManager.storeResult(prompt: prompt, result: result, models: registeredModels)
        
        return result
    }
    
    /// Execute multiple models in parallel and combine their results
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - models: The models to execute in parallel
    ///   - combinationStrategy: How to combine the results
    /// - Returns: The combined result
    public func executeParallel(
        prompt: String,
        models: [JanetModelType],
        combinationStrategy: CombinationStrategy = .best
    ) async throws -> String {
        logger.info("Executing parallel models with strategy: \(String(describing: combinationStrategy))")
        
        // Update processing state
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            // Reset processing state when done
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Convert model types to registered models
        let registeredModels = models.compactMap { modelType in
            modelRegistry.getRegisteredModel(modelType)
        }
        
        // Check if all models were found
        guard registeredModels.count == models.count else {
            logger.error("Not all models for parallel execution are registered")
            throw OrchestratorError.modelNotRegistered
        }
        
        // Create request context
        let requestContext = RequestContext(
            prompt: prompt,
            taskType: .general,
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            repetitionPenalty: 1.1
        )
        
        // Execute in parallel
        let result = try await executionEngine.executeParallel(
            context: requestContext,
            models: registeredModels,
            combinationStrategy: combinationStrategy
        )
        
        // Store the result in memory context
        await memoryContextManager.storeResult(prompt: prompt, result: result, models: registeredModels)
        
        return result
    }
    
    /// Auto-refine a response through multiple iterations
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - iterations: Number of refinement iterations
    ///   - modelType: The model to use for refinement
    /// - Returns: The refined result
    public func autoRefine(
        prompt: String,
        iterations: Int = 3,
        modelType: JanetModelType = .phi
    ) async throws -> String {
        logger.info("Auto-refining response with \(iterations) iterations using model: \(String(describing: modelType))")
        
        // Update processing state
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            // Reset processing state when done
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Get the registered model
        guard let registeredModel = modelRegistry.getRegisteredModel(modelType) else {
            logger.error("Model not registered: \(String(describing: modelType))")
            throw OrchestratorError.modelNotRegistered
        }
        
        // Create request context
        let requestContext = RequestContext(
            prompt: prompt,
            taskType: .general,
            maxTokens: 1024,
            temperature: 0.7,
            topP: 0.9,
            repetitionPenalty: 1.1
        )
        
        // Execute auto-refinement
        let result = try await executionEngine.autoRefine(
            context: requestContext,
            model: registeredModel,
            iterations: iterations
        )
        
        // Store the result in memory context
        await memoryContextManager.storeResult(prompt: prompt, result: result, models: [registeredModel])
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Initialize the model registry with available models
    private func initializeModelRegistry() {
        logger.info("Initializing model registry")
        
        // Register Ollama model
        let ollamaModel = RegisteredModel(
            modelType: .ollama,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .summarization],
                reasoningAbility: .medium,
                contextWindow: 4096,
                isLocalOnly: true
            ),
            priority: 1
        )
        modelRegistry.registerModel(ollamaModel)
        
        // Register Phi model
        let phiModel = RegisteredModel(
            modelType: .phi,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .reasoning, .summarization],
                reasoningAbility: .high,
                contextWindow: 2048,
                isLocalOnly: true
            ),
            priority: 2
        )
        modelRegistry.registerModel(phiModel)
        
        // Register Llama model
        let llamaModel = RegisteredModel(
            modelType: .llama,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .code, .reasoning],
                reasoningAbility: .high,
                contextWindow: 4096,
                isLocalOnly: true
            ),
            priority: 3
        )
        modelRegistry.registerModel(llamaModel)
        
        // Register Mistral model
        let mistralModel = RegisteredModel(
            modelType: .mistral,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .summarization],
                reasoningAbility: .medium,
                contextWindow: 8192,
                isLocalOnly: true
            ),
            priority: 4
        )
        modelRegistry.registerModel(mistralModel)
        
        // Update available models
        updateAvailableModels()
    }
    
    /// Update the list of available models
    private func updateAvailableModels() {
        let models = modelRegistry.getAllRegisteredModels()
        
        // Update on main thread
        Task { @MainActor in
            availableModels = models
        }
    }
    
    /// Handle model load state changes
    /// - Parameter notification: The notification containing load state information
    private func handleModelLoadStateChanged(_ notification: Notification) {
        logger.info("Model load state changed")
        
        // Extract model type and load state from notification
        if let userInfo = notification.userInfo,
           let modelTypeRaw = userInfo["modelType"] as? String,
           let isLoaded = userInfo["isLoaded"] as? Bool,
           let modelType = JanetModelType(rawValue: modelTypeRaw) {
            
            logger.info("Model \(modelTypeRaw) load state: \(isLoaded)")
            
            // Update model registry
            modelRegistry.updateModelLoadState(modelType: modelType, isLoaded: isLoaded)
            
            // Update available models
            updateAvailableModels()
        }
    }
    
    /// Handle a system command task
    /// - Parameter prompt: The input prompt
    /// - Returns: The command output
    private func handleSystemCommand(prompt: String) async throws -> String {
        logger.info("Handling system command: \(prompt)")
        
        // Parse the command from the prompt
        let (command, arguments) = parseSystemCommand(prompt: prompt)
        
        // Execute the command
        do {
            let result = try await systemCommandExecutor.executeCommand(
                command: command,
                arguments: arguments
            )
            
            // Format the result
            let formattedResult = """
            Command: \(command) \(arguments.joined(separator: " "))
            Exit Code: \(result.exitCode)
            
            Output:
            \(result.output)
            
            \(result.error.isEmpty ? "" : "Error:\n\(result.error)")
            """
            
            return formattedResult
        } catch {
            // If the command is not allowed, try to provide a helpful message
            if let systemError = error as? SystemCommandError {
                switch systemError {
                case .commandNotAllowed(let command):
                    return "Command not allowed: \(command)\n\nFor security reasons, only a limited set of commands are allowed."
                case .directoryNotAllowed(let path):
                    return "Directory not allowed: \(path)\n\nFor security reasons, only certain directories are allowed."
                case .dangerousArguments:
                    return "Command contains dangerous arguments.\n\nFor security reasons, commands with potentially dangerous arguments are not allowed."
                case .executionFailed(let error):
                    return "Command execution failed: \(error.localizedDescription)"
                case .fileSystemError(let error):
                    return "File system operation failed: \(error.localizedDescription)"
                }
            }
            
            throw error
        }
    }
    
    /// Parse a system command from a prompt
    /// - Parameter prompt: The input prompt
    /// - Returns: The command and arguments
    private func parseSystemCommand(prompt: String) -> (command: String, arguments: [String]) {
        logger.info("Parsing system command from prompt: \(prompt)")
        
        // Remove common prefixes
        var cleanedPrompt = prompt
            .replacingOccurrences(of: "execute", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "run", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "command", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "shell", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "terminal", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "bash", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "zsh", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "system", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "process", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove quotes
        if cleanedPrompt.hasPrefix("\"") && cleanedPrompt.hasSuffix("\"") {
            cleanedPrompt = String(cleanedPrompt.dropFirst().dropLast())
        }
        
        if cleanedPrompt.hasPrefix("'") && cleanedPrompt.hasSuffix("'") {
            cleanedPrompt = String(cleanedPrompt.dropFirst().dropLast())
        }
        
        // Split the command and arguments
        let components = cleanedPrompt.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        guard let command = components.first else {
            return ("ls", [])
        }
        
        let arguments = Array(components.dropFirst())
        
        return (command, arguments)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Notification sent when a model's load state changes
    static let modelLoadStateChanged = Notification.Name("modelLoadStateChanged")
}

// MARK: - Orchestrator Errors

/// Errors that can occur in the orchestrator
public enum OrchestratorError: Error {
    /// No suitable model was found for the task
    case noSuitableModel
    
    /// The requested model is not registered
    case modelNotRegistered
    
    /// The model failed to load
    case modelLoadFailed
    
    /// The model failed to generate text
    case modelGenerationFailed
    
    /// The execution mode is not supported
    case unsupportedExecutionMode
    
    /// The combination strategy is not supported
    case unsupportedCombinationStrategy
    
    /// No models are available for the task
    case noModelsAvailable
}

// MARK: - Execution Mode

/// The mode of execution for the orchestrator
public enum ExecutionMode {
    /// Automatically select the best execution strategy
    case auto
    
    /// Use a single model
    case single
    
    /// Chain multiple models
    case chain
    
    /// Execute models in parallel
    case parallel
}

// MARK: - Combination Strategy

/// Strategy for combining results from multiple models
public enum CombinationStrategy {
    /// Use the result from the best model
    case best
    
    /// Concatenate all results
    case concatenate
    
    /// Summarize all results
    case summarize
    
    /// Use a voting mechanism to select the best result
    case vote
} 