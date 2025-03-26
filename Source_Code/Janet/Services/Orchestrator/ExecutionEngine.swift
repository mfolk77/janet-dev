//
//  ExecutionEngine.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os

/// Engine for executing models
public class ExecutionEngine {
    // MARK: - Private Properties
    
    /// Logger for the execution engine
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "ExecutionEngine")
    
    /// Cloud model executor for cloud-based models
    private lazy var cloudExecutor = CloudModelExecutor()
    
    // MARK: - Initialization
    
    /// Initialize a new execution engine
    public init() {
        logger.info("Initializing ExecutionEngine")
    }
    
    // MARK: - Public Methods
    
    /// Execute a request using the selected models
    /// - Parameters:
    ///   - context: The request context
    ///   - models: The models to use
    ///   - mode: The execution mode
    /// - Returns: The generated text
    public func execute(
        context: RequestContext,
        models: [RegisteredModel],
        mode: ExecutionMode
    ) async throws -> String {
        logger.info("Executing request with \(models.count) models in mode: \(String(describing: mode))")
        
        // If no models are provided, throw an error
        guard !models.isEmpty else {
            logger.error("No models provided for execution")
            throw ExecutionError.noModelsProvided
        }
        
        // Execute based on the mode
        switch mode {
        case .auto:
            // Automatically determine the best execution mode
            return try await executeAuto(context: context, models: models)
        case .single:
            // Use a single model
            guard let model = models.first else {
                throw ExecutionError.noModelsProvided
            }
            return try await executeSingle(context: context, model: model)
        case .chain:
            // Chain multiple models
            return try await executeChain(context: context, modelChain: models)
        case .parallel:
            // Execute models in parallel
            return try await executeParallel(context: context, models: models, combinationStrategy: .best)
        }
    }
    
    /// Execute a chain of models in sequence
    /// - Parameters:
    ///   - context: The request context
    ///   - modelChain: The sequence of models to use
    /// - Returns: The final result after processing through all models
    public func executeChain(
        context: RequestContext,
        modelChain: [RegisteredModel]
    ) async throws -> String {
        logger.info("Executing chain with \(modelChain.count) models")
        
        // If no models are provided, throw an error
        guard !modelChain.isEmpty else {
            logger.error("No models provided for chain execution")
            throw ExecutionError.noModelsProvided
        }
        
        // Get the current prompt from the context
        var currentPrompt = context.prompt
        var currentResult = ""
        
        // Process through each model in the chain
        for (index, model) in modelChain.enumerated() {
            logger.info("Chain step \(index + 1): Using model \(model.modelType.rawValue)")
            
            // Create a new context with the current prompt
            let stepContext = RequestContext(
                prompt: currentPrompt,
                taskType: context.taskType,
                maxTokens: context.maxTokens,
                temperature: context.temperature,
                topP: context.topP,
                repetitionPenalty: context.repetitionPenalty
            )
            
            // Execute the model
            currentResult = try await executeSingle(context: stepContext, model: model)
            
            // Use the result as the prompt for the next model
            currentPrompt = currentResult
        }
        
        return currentResult
    }
    
    /// Execute multiple models in parallel and combine their results
    /// - Parameters:
    ///   - context: The request context
    ///   - models: The models to execute in parallel
    ///   - combinationStrategy: How to combine the results
    /// - Returns: The combined result
    public func executeParallel(
        context: RequestContext,
        models: [RegisteredModel],
        combinationStrategy: CombinationStrategy
    ) async throws -> String {
        logger.info("Executing \(models.count) models in parallel with strategy: \(String(describing: combinationStrategy))")
        
        // Execute all models in parallel
        let results = try await withThrowingTaskGroup(of: (JanetModelType, String).self) { group in
            for model in models {
                group.addTask {
                    let result = try await self.executeSingle(context: context, model: model)
                    return (model.modelType, result)
                }
            }
            
            var modelResults: [(JanetModelType, String)] = []
            for try await result in group {
                modelResults.append(result)
            }
            
            return modelResults
        }
        
        // Combine the results based on the strategy
        return combineResults(results: results, strategy: combinationStrategy)
    }
    
    /// Auto-refine a response through multiple iterations
    /// - Parameters:
    ///   - context: The request context
    ///   - model: The model to use for refinement
    ///   - iterations: Number of refinement iterations
    /// - Returns: The refined result
    public func autoRefine(
        context: RequestContext,
        model: RegisteredModel,
        iterations: Int
    ) async throws -> String {
        logger.info("Auto-refining with \(iterations) iterations using model: \(model.modelType.rawValue)")
        
        // Get the current prompt from the context
        var currentPrompt = context.prompt
        var currentResult = ""
        
        // Refine through multiple iterations
        for iteration in 1...iterations {
            logger.info("Refinement iteration \(iteration)")
            
            // Create a refinement prompt
            let refinementPrompt: String
            if iteration == 1 {
                // First iteration uses the original prompt
                refinementPrompt = currentPrompt
            } else {
                // Subsequent iterations ask for refinement
                refinementPrompt = """
                I need you to refine and improve the following response. Make it more accurate, clear, and comprehensive:
                
                Original prompt: \(context.prompt)
                
                Current response:
                \(currentResult)
                
                Improved response:
                """
            }
            
            // Create a new context with the refinement prompt
            let refinementContext = RequestContext(
                prompt: refinementPrompt,
                taskType: context.taskType,
                maxTokens: context.maxTokens,
                temperature: max(context.temperature - 0.1 * Float(iteration - 1), 0.1), // Reduce temperature with each iteration
                topP: context.topP,
                repetitionPenalty: context.repetitionPenalty
            )
            
            // Execute the model
            currentResult = try await executeSingle(context: refinementContext, model: model)
        }
        
        return currentResult
    }
    
    /// Execute a request using a single model
    /// - Parameters:
    ///   - context: The request context
    ///   - model: The model to use
    /// - Returns: The generated text
    public func executeSingle(
        context: RequestContext,
        model: RegisteredModel
    ) async throws -> String {
        logger.info("Executing single model: \(model.modelType.rawValue)")
        
        // Ensure the model is loaded
        if !model.isLoaded {
            logger.info("Model \(model.modelType.rawValue) is not loaded, loading now")
            try await ModelManager.shared.loadModel(type: model.modelType)
        }
        
        // Get the model instance
        guard let modelInstance = ModelManager.shared.getModel(type: model.modelType) else {
            logger.error("Failed to get model instance for \(model.modelType.rawValue)")
            throw ExecutionError.modelNotLoaded
        }
        
        // Generate text
        do {
            let result = try await modelInstance.generateText(
                prompt: context.prompt,
                maxTokens: context.maxTokens,
                temperature: context.temperature,
                topP: context.topP,
                repetitionPenalty: context.repetitionPenalty
            )
            
            logger.info("Model \(model.modelType.rawValue) generated \(result.count) characters")
            return result
        } catch {
            logger.error("Error generating text with model \(model.modelType.rawValue): \(error.localizedDescription)")
            throw ExecutionError.modelGenerationFailed
        }
    }
    
    /// Automatically determine the best execution mode
    /// - Parameters:
    ///   - context: The request context
    ///   - models: The models to use
    /// - Returns: The generated text
    private func executeAuto(
        context: RequestContext,
        models: [RegisteredModel]
    ) async throws -> String {
        logger.info("Auto-selecting execution mode for \(models.count) models")
        
        // If only one model is provided, use single mode
        if models.count == 1 {
            return try await executeSingle(context: context, model: models[0])
        }
        
        // For complex reasoning tasks, use chain mode
        if context.taskType == .reasoning && models.count > 1 {
            // Sort models by reasoning ability (highest first)
            let sortedModels = models.sorted { 
                let abilityOrder: [ReasoningAbility] = [.high, .medium, .low]
                let aIndex = abilityOrder.firstIndex(of: $0.capabilities.reasoningAbility) ?? 2
                let bIndex = abilityOrder.firstIndex(of: $1.capabilities.reasoningAbility) ?? 2
                return aIndex < bIndex
            }
            
            return try await executeChain(context: context, modelChain: sortedModels)
        }
        
        // For summarization tasks, use parallel mode
        if context.taskType == .summarization && models.count > 1 {
            return try await executeParallel(context: context, models: models, combinationStrategy: .summarize)
        }
        
        // For financial tasks, use parallel mode with voting
        if context.taskType == .financial && models.count > 1 {
            return try await executeParallel(context: context, models: models, combinationStrategy: .vote)
        }
        
        // Default to using the highest priority model
        let bestModel = models.min { $0.priority < $1.priority } ?? models[0]
        return try await executeSingle(context: context, model: bestModel)
    }
    
    /// Combine results from multiple models
    /// - Parameters:
    ///   - results: The results from each model
    ///   - strategy: The strategy to use for combining
    /// - Returns: The combined result
    private func combineResults(
        results: [(JanetModelType, String)],
        strategy: CombinationStrategy
    ) -> String {
        logger.info("Combining results using strategy: \(String(describing: strategy))")
        
        // If there's only one result, return it
        if results.count == 1, let singleResult = results.first {
            return singleResult.1
        }
        
        // Apply the combination strategy
        switch strategy {
        case .best:
            // Use the result from the highest priority model
            if let bestResult = results.min(by: { $0.0.rawValue < $1.0.rawValue }) {
                return bestResult.1
            }
            return "No results available"
            
        case .concatenate:
            // Concatenate all results
            var combined = ""
            for (modelType, result) in results {
                combined += "=== \(modelType.rawValue.uppercased()) ===\n\(result)\n\n"
            }
            return combined
            
        case .summarize:
            // Summarize all results
            // This would ideally use another model to summarize
            return summarizeResults(results: results.map { $0.1 })
            
        case .vote:
            // Use a voting mechanism
            return voteOnResults(results: results.map { $0.1 })
        }
    }
    
    /// Get all available models
    /// - Returns: Array of available models
    private func getAvailableModels() -> [RegisteredModel] {
        logger.info("Getting available models")
        
        var availableModels: [RegisteredModel] = []
        
        // Get loaded models from ModelManager
        let loadedModels = ModelManager.shared.getLoadedModels()
        
        // Create RegisteredModel instances for each loaded model
        for modelType in JanetModelType.allCases {
            if loadedModels.contains(modelType),
               let _ = ModelManager.shared.getModel(type: modelType) {
                let registeredModel = RegisteredModel(
                    modelType: modelType,
                    capabilities: ModelCapabilities(
                        supportedTasks: [.general],
                        reasoningAbility: .medium,
                        contextWindow: 4096,
                        isLocalOnly: true
                    ),
                    priority: 1,
                    isLoaded: true
                )
                availableModels.append(registeredModel)
            }
        }
        
        return availableModels
    }
    
    /// Execute models in parallel with advanced combination strategies
    /// - Parameters:
    ///   - context: The request context
    ///   - models: The models to execute in parallel
    ///   - combinationStrategy: How to combine the results
    ///   - weightingStrategy: How to weight the results
    /// - Returns: The combined result
    public func executeAdvancedParallel(
        context: RequestContext,
        models: [RegisteredModel],
        combinationStrategy: AdvancedCombinationStrategy,
        weightingStrategy: WeightingStrategy
    ) async throws -> String {
        logger.info("Executing \(models.count) models in parallel with advanced strategy: \(String(describing: combinationStrategy))")
        
        // Execute all models in parallel
        let results = try await withThrowingTaskGroup(of: (JanetModelType, String, Double).self) { group in
            for model in models {
                group.addTask {
                    let result = try await self.executeSingle(context: context, model: model)
                    let confidence = self.calculateConfidence(result: result, model: model)
                    return (model.modelType, result, confidence)
                }
            }
            
            var modelResults: [(JanetModelType, String, Double)] = []
            for try await result in group {
                modelResults.append(result)
            }
            
            return modelResults
        }
        
        // Apply weighting strategy
        let weightedResults = applyWeighting(results: results, strategy: weightingStrategy)
        
        // Convert the weighted results to the format expected by combineAdvancedResults
        let formattedResults = weightedResults.map { (_, text, weight) in
            return (text, weight)
        }
        
        // Combine the results based on the strategy
        return combineAdvancedResults(results: formattedResults, strategy: combinationStrategy)
    }
    
    /// Apply weighting to results
    /// - Parameters:
    ///   - results: The results from each model
    ///   - strategy: The weighting strategy
    /// - Returns: The weighted results
    private func applyWeighting(
        results: [(JanetModelType, String, Double)],
        strategy: WeightingStrategy
    ) -> [(JanetModelType, String, Double)] {
        // Apply weighting based on the strategy
        // For now, we'll just return the original results
        // In a real implementation, we would apply different weighting strategies
        return results
    }
    
    /// Find a model with summarization capability
    /// - Returns: A model that can perform summarization
    private func findSummarizationModel() async throws -> RegisteredModel {
        logger.info("Finding a model for summarization")
        
        // Get the loaded models
        let loadedModels = ModelManager.shared.getLoadedModels()
        
        for modelType in JanetModelType.allCases {
            if loadedModels.contains(modelType),
               let _ = ModelManager.shared.getModel(type: modelType) {
                // Check if the model supports summarization
                // This is a simplified check; in a real implementation, we would check the model's capabilities
                return RegisteredModel(
                    modelType: modelType,
                    capabilities: ModelCapabilities(
                        supportedTasks: [.summarization],
                        reasoningAbility: .medium,
                        contextWindow: 4096,
                        isLocalOnly: true
                    ),
                    priority: 1,
                    isLoaded: true
                )
            }
        }
        
        // If no suitable model is found, throw an error
        logger.error("No model with summarization capability found")
        throw ExecutionError.noSuitableModel
    }
    
    /// Calculate confidence for a result from a model
    /// - Parameters:
    ///   - result: The result from the model
    ///   - model: The model that generated the result
    /// - Returns: A confidence score between 0 and 1
    private func calculateConfidence(result: String, model: RegisteredModel) -> Double {
        // Simple confidence calculation based on model capabilities and result length
        let baseConfidence = 0.5
        
        // Adjust based on model reasoning ability
        let reasoningBonus: Double
        switch model.capabilities.reasoningAbility {
        case .low:
            reasoningBonus = 0.1
        case .medium:
            reasoningBonus = 0.2
        case .high:
            reasoningBonus = 0.3
        }
        
        // Adjust based on result length (longer answers might indicate more thought)
        let lengthFactor = min(Double(result.count) / 1000.0, 0.2)
        
        // Combine factors
        let confidence = baseConfidence + reasoningBonus + lengthFactor
        
        // Ensure confidence is between 0 and 1
        return min(max(confidence, 0.0), 1.0)
    }
    
    /// Summarize multiple results into a single result
    /// - Parameter results: The results to summarize
    /// - Returns: A summarized result
    private func summarizeResults(results: [String]) -> String {
        // Simple summarization by combining results
        if results.isEmpty {
            return "No results available."
        }
        
        if results.count == 1 {
            return results[0]
        }
        
        var summary = "Summary of \(results.count) responses:\n\n"
        
        for (index, result) in results.enumerated() {
            let truncatedResult = result.prefix(200) + (result.count > 200 ? "..." : "")
            summary += "Response \(index + 1): \(truncatedResult)\n\n"
        }
        
        return summary
    }
    
    /// Vote on multiple results to select the best one
    /// - Parameter results: The results to vote on
    /// - Returns: The result with the most votes
    private func voteOnResults(results: [String]) -> String {
        // Simple voting by selecting the most common result
        if results.isEmpty {
            return "No results available."
        }
        
        if results.count == 1 {
            return results[0]
        }
        
        // Count occurrences of each result
        var resultCounts: [String: Int] = [:]
        for result in results {
            resultCounts[result, default: 0] += 1
        }
        
        // Find the result with the most votes
        if let (mostCommonResult, count) = resultCounts.max(by: { $0.value < $1.value }) {
            return "Selected response (voted by \(count)/\(results.count) models):\n\n\(mostCommonResult)"
        }
        
        // Fallback to the first result
        return results[0]
    }
    
    /// Combine results using an advanced strategy
    /// - Parameters:
    ///   - results: The weighted results from each model
    ///   - strategy: The combination strategy
    /// - Returns: The combined result
    private func combineAdvancedResults(results: [(String, Double)], strategy: AdvancedCombinationStrategy) -> String {
        // If no results, return empty string
        if results.isEmpty {
            return "No results available."
        }
        
        // If only one result, return it
        if results.count == 1 {
            return results[0].0
        }
        
        switch strategy {
        case .weightedAverage:
            // Sort by confidence (highest first)
            let sortedResults = results.sorted { $0.1 > $1.1 }
            
            // Take the top result
            return "Selected response (confidence: \(String(format: "%.2f", sortedResults[0].1))):\n\n\(sortedResults[0].0)"
            
        case .ensemble:
            // Create a combined response that includes all results with their confidence scores
            var combined = "Ensemble of \(results.count) responses:\n\n"
            
            // Sort by confidence (highest first)
            let sortedResults = results.sorted { $0.1 > $1.1 }
            
            for (index, (result, confidence)) in sortedResults.enumerated() {
                let truncatedResult = result.prefix(200) + (result.count > 200 ? "..." : "")
                combined += "Response \(index + 1) (confidence: \(String(format: "%.2f", confidence))):\n\(truncatedResult)\n\n"
            }
            
            return combined
            
        case .debate:
            // For debate, we would implement a more complex strategy
            // This is a simplified implementation
            return "Debate strategy not fully implemented yet. Using top result:\n\n\(results[0].0)"
            
        case .confidenceThreshold(let threshold):
            // Filter results by confidence threshold
            let filteredResults = results.filter { $0.1 >= threshold }
            
            if filteredResults.isEmpty {
                return "No results met the confidence threshold of \(threshold)."
            }
            
            // Sort by confidence (highest first)
            let sortedResults = filteredResults.sorted { $0.1 > $1.1 }
            
            // Take the top result
            return "Selected response above threshold \(threshold) (confidence: \(String(format: "%.2f", sortedResults[0].1))):\n\n\(sortedResults[0].0)"
        }
    }
}

// MARK: - Request Context

/// Context for a request
public struct RequestContext {
    /// The input prompt
    public let prompt: String
    
    /// The type of task
    public let taskType: TaskType
    
    /// Maximum number of tokens to generate
    public let maxTokens: Int
    
    /// Temperature for generation
    public let temperature: Float
    
    /// Top-p sampling parameter
    public let topP: Float
    
    /// Penalty for repetition
    public let repetitionPenalty: Float
    
    /// Initialize a new request context
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - taskType: The type of task
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Temperature for generation
    ///   - topP: Top-p sampling parameter
    ///   - repetitionPenalty: Penalty for repetition
    public init(
        prompt: String,
        taskType: TaskType = .general,
        maxTokens: Int = 1024,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        repetitionPenalty: Float = 1.1
    ) {
        self.prompt = prompt
        self.taskType = taskType
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.repetitionPenalty = repetitionPenalty
    }
}

// MARK: - Execution Errors

/// Errors that can occur in the execution engine
public enum ExecutionError: Error {
    /// No models were provided for execution
    case noModelsProvided
    
    /// The model is not loaded
    case modelNotLoaded
    
    /// The model failed to generate text
    case modelGenerationFailed
    
    /// No suitable model was found
    case noSuitableModel
    
    /// No results were returned
    case noResults
}

// MARK: - Cloud Model Executor

/// Executes queries against cloud-based models
public class CloudModelExecutor: @unchecked Sendable {
    // MARK: - Private Properties
    
    /// Logger for the cloud model executor
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "CloudModelExecutor")
    
    /// API client for cloud model requests
    private let apiClient: CloudAPIClient
    
    /// Queue for rate limiting
    private let requestQueue = DispatchQueue(label: "com.janet.ai.cloudModelExecutor", qos: .userInitiated)
    
    /// Semaphore for rate limiting
    private let rateLimitSemaphore = DispatchSemaphore(value: 3) // Allow 3 concurrent requests
    
    // MARK: - Initialization
    
    /// Initialize a new cloud model executor
    /// - Parameter apiClient: The API client to use
    public init(apiClient: CloudAPIClient = CloudAPIClient()) {
        self.apiClient = apiClient
        logger.info("Initializing CloudModelExecutor")
    }
    
    // MARK: - Public Methods
    
    /// Execute a request using a cloud model
    /// - Parameters:
    ///   - context: The request context
    ///   - modelId: The ID of the cloud model
    ///   - provider: The cloud provider
    /// - Returns: The generated text
    public func executeCloudModel(
        context: RequestContext,
        modelId: String,
        provider: CloudProvider
    ) async throws -> String {
        logger.info("Executing cloud model: \(modelId) from provider: \(provider.rawValue)")
        
        // Create a request
        let request = CloudModelRequest(
            prompt: context.prompt,
            modelId: modelId,
            maxTokens: context.maxTokens,
            temperature: context.temperature,
            topP: context.topP,
            provider: provider
        )
        
        // Execute with rate limiting
        return try await withCheckedThrowingContinuation { continuation in
            requestQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CloudExecutionError.executorDeallocated)
                    return
                }
                
                // Acquire semaphore for rate limiting
                self.rateLimitSemaphore.wait()
                
                // Execute the request
                Task {
                    do {
                        let startTime = Date()
                        let result = try await self.apiClient.executeRequest(request)
                        let executionTime = Date().timeIntervalSince(startTime)
                        
                        self.logger.info("Cloud model \(modelId) generated response in \(executionTime) seconds")
                        
                        // Release semaphore
                        self.rateLimitSemaphore.signal()
                        
                        // Return the result
                        continuation.resume(returning: result)
                    } catch {
                        self.logger.error("Error executing cloud model \(modelId): \(error.localizedDescription)")
                        
                        // Release semaphore
                        self.rateLimitSemaphore.signal()
                        
                        // Return the error
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Check if a cloud model is available
    /// - Parameters:
    ///   - modelId: The ID of the cloud model
    ///   - provider: The cloud provider
    /// - Returns: Whether the model is available
    public func isModelAvailable(modelId: String, provider: CloudProvider) async -> Bool {
        logger.info("Checking availability of cloud model: \(modelId) from provider: \(provider.rawValue)")
        
        do {
            return try await apiClient.checkModelAvailability(modelId: modelId, provider: provider)
        } catch {
            logger.error("Error checking availability of cloud model \(modelId): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get estimated cost for a request
    /// - Parameters:
    ///   - context: The request context
    ///   - modelId: The ID of the cloud model
    ///   - provider: The cloud provider
    /// - Returns: The estimated cost in USD
    public func getEstimatedCost(
        context: RequestContext,
        modelId: String,
        provider: CloudProvider
    ) async -> Double {
        logger.info("Getting estimated cost for cloud model: \(modelId) from provider: \(provider.rawValue)")
        
        do {
            return try await apiClient.getEstimatedCost(
                prompt: context.prompt,
                modelId: modelId,
                maxTokens: context.maxTokens,
                provider: provider
            )
        } catch {
            logger.error("Error getting estimated cost for cloud model \(modelId): \(error.localizedDescription)")
            return 0.0
        }
    }
}

// MARK: - Cloud API Client

/// Client for cloud API requests
public class CloudAPIClient {
    // MARK: - Private Properties
    
    /// Logger for the cloud API client
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "CloudAPIClient")
    
    /// API keys for different providers
    private var apiKeys: [CloudProvider: String] = [:]
    
    /// URL session for network requests
    private let session = URLSession.shared
    
    // MARK: - Initialization
    
    /// Initialize a new cloud API client
    public init() {
        logger.info("Initializing CloudAPIClient")
        
        // Load API keys from keychain or environment
        loadAPIKeys()
    }
    
    // MARK: - Public Methods
    
    /// Execute a cloud model request
    /// - Parameter request: The request to execute
    /// - Returns: The generated text
    public func executeRequest(_ request: CloudModelRequest) async throws -> String {
        logger.info("Executing request for model: \(request.modelId) from provider: \(request.provider.rawValue)")
        
        // Check if we have an API key for the provider
        guard let apiKey = apiKeys[request.provider] else {
            logger.error("No API key found for provider: \(request.provider.rawValue)")
            throw CloudExecutionError.missingAPIKey
        }
        
        // Execute based on the provider
        switch request.provider {
        case .openAI:
            return try await executeOpenAIRequest(request, apiKey: apiKey)
        case .anthropic:
            return try await executeAnthropicRequest(request, apiKey: apiKey)
        case .googleAI:
            return try await executeGoogleAIRequest(request, apiKey: apiKey)
        case .custom:
            return try await executeCustomRequest(request, apiKey: apiKey)
        }
    }
    
    /// Check if a cloud model is available
    /// - Parameters:
    ///   - modelId: The ID of the cloud model
    ///   - provider: The cloud provider
    /// - Returns: Whether the model is available
    public func checkModelAvailability(modelId: String, provider: CloudProvider) async throws -> Bool {
        logger.info("Checking availability of model: \(modelId) from provider: \(provider.rawValue)")
        
        // Check if we have an API key for the provider
        guard apiKeys[provider] != nil else {
            logger.error("No API key found for provider: \(provider.rawValue)")
            throw CloudExecutionError.missingAPIKey
        }
        
        // For now, just return true if we have an API key
        // In a real implementation, we would make an API call to check availability
        return true
    }
    
    /// Get estimated cost for a request
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - modelId: The ID of the cloud model
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - provider: The cloud provider
    /// - Returns: The estimated cost in USD
    public func getEstimatedCost(
        prompt: String,
        modelId: String,
        maxTokens: Int,
        provider: CloudProvider
    ) async throws -> Double {
        logger.info("Getting estimated cost for model: \(modelId) from provider: \(provider.rawValue)")
        
        // Estimate token count (very rough approximation)
        let promptTokens = prompt.count / 4
        let completionTokens = maxTokens
        
        // Get cost per token based on the provider and model
        let (promptCostPerToken, completionCostPerToken) = getCostPerToken(modelId: modelId, provider: provider)
        
        // Calculate total cost
        let promptCost = Double(promptTokens) * promptCostPerToken
        let completionCost = Double(completionTokens) * completionCostPerToken
        
        return promptCost + completionCost
    }
    
    /// Set an API key for a provider
    /// - Parameters:
    ///   - apiKey: The API key
    ///   - provider: The cloud provider
    public func setAPIKey(_ apiKey: String, for provider: CloudProvider) {
        logger.info("Setting API key for provider: \(provider.rawValue)")
        
        apiKeys[provider] = apiKey
        
        // Save to keychain
        saveAPIKey(apiKey, for: provider)
    }
    
    // MARK: - Private Methods
    
    /// Load API keys from keychain or environment
    private func loadAPIKeys() {
        logger.info("Loading API keys")
        
        // Load from keychain
        for provider in CloudProvider.allCases {
            if let apiKey = loadAPIKey(for: provider) {
                apiKeys[provider] = apiKey
                logger.info("Loaded API key for provider: \(provider.rawValue)")
            }
        }
    }
    
    /// Load an API key from keychain
    /// - Parameter provider: The cloud provider
    /// - Returns: The API key, if found
    private func loadAPIKey(for provider: CloudProvider) -> String? {
        // In a real implementation, we would load from keychain
        // For now, just return nil
        return nil
    }
    
    /// Save an API key to keychain
    /// - Parameters:
    ///   - apiKey: The API key
    ///   - provider: The cloud provider
    private func saveAPIKey(_ apiKey: String, for provider: CloudProvider) {
        // In a real implementation, we would save to keychain
        // For now, do nothing
    }
    
    /// Execute an OpenAI request
    /// - Parameters:
    ///   - request: The request to execute
    ///   - apiKey: The API key
    /// - Returns: The generated text
    private func executeOpenAIRequest(_ request: CloudModelRequest, apiKey: String) async throws -> String {
        logger.info("Executing OpenAI request for model: \(request.modelId)")
        
        // Create the request URL
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        // Create the request body
        let body: [String: Any] = [
            "model": request.modelId,
            "messages": [
                ["role": "user", "content": request.prompt]
            ],
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.topP
        ]
        
        // Create the request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Execute the request
        let (data, response) = try await session.data(for: urlRequest)
        
        // Check the response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response from OpenAI API")
            throw CloudExecutionError.invalidResponse
        }
        
        // Check the status code
        guard httpResponse.statusCode == 200 else {
            logger.error("Error from OpenAI API: \(httpResponse.statusCode)")
            throw CloudExecutionError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            logger.error("Invalid response format from OpenAI API")
            throw CloudExecutionError.invalidResponseFormat
        }
        
        return content
    }
    
    /// Execute an Anthropic request
    /// - Parameters:
    ///   - request: The request to execute
    ///   - apiKey: The API key
    /// - Returns: The generated text
    private func executeAnthropicRequest(_ request: CloudModelRequest, apiKey: String) async throws -> String {
        logger.info("Executing Anthropic request for model: \(request.modelId)")
        
        // Create the request URL
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        
        // Create the request body
        let body: [String: Any] = [
            "model": request.modelId,
            "messages": [
                ["role": "user", "content": request.prompt]
            ],
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "top_p": request.topP
        ]
        
        // Create the request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("anthropic-version: 2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Execute the request
        let (data, response) = try await session.data(for: urlRequest)
        
        // Check the response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response from Anthropic API")
            throw CloudExecutionError.invalidResponse
        }
        
        // Check the status code
        guard httpResponse.statusCode == 200 else {
            logger.error("Error from Anthropic API: \(httpResponse.statusCode)")
            throw CloudExecutionError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            logger.error("Invalid response format from Anthropic API")
            throw CloudExecutionError.invalidResponseFormat
        }
        
        return text
    }
    
    /// Execute a Google AI request
    /// - Parameters:
    ///   - request: The request to execute
    ///   - apiKey: The API key
    /// - Returns: The generated text
    private func executeGoogleAIRequest(_ request: CloudModelRequest, apiKey: String) async throws -> String {
        logger.info("Executing Google AI request for model: \(request.modelId)")
        
        // Create the request URL
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(request.modelId):generateContent?key=\(apiKey)")!
        
        // Create the request body
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": request.prompt]]]
            ],
            "generationConfig": [
                "maxOutputTokens": request.maxTokens,
                "temperature": request.temperature,
                "topP": request.topP
            ]
        ]
        
        // Create the request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Execute the request
        let (data, response) = try await session.data(for: urlRequest)
        
        // Check the response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response from Google AI API")
            throw CloudExecutionError.invalidResponse
        }
        
        // Check the status code
        guard httpResponse.statusCode == 200 else {
            logger.error("Error from Google AI API: \(httpResponse.statusCode)")
            throw CloudExecutionError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            logger.error("Invalid response format from Google AI API")
            throw CloudExecutionError.invalidResponseFormat
        }
        
        return text
    }
    
    /// Execute a custom API request
    /// - Parameters:
    ///   - request: The request to execute
    ///   - apiKey: The API key
    /// - Returns: The generated text
    private func executeCustomRequest(_ request: CloudModelRequest, apiKey: String) async throws -> String {
        logger.info("Executing custom request for model: \(request.modelId)")
        
        // In a real implementation, we would execute a custom API request
        // For now, just return a placeholder
        return "Response from custom API"
    }
    
    /// Get cost per token for a model
    /// - Parameters:
    ///   - modelId: The ID of the cloud model
    ///   - provider: The cloud provider
    /// - Returns: The cost per token for prompt and completion
    private func getCostPerToken(modelId: String, provider: CloudProvider) -> (Double, Double) {
        // These are approximate costs as of 2023
        switch provider {
        case .openAI:
            if modelId.contains("gpt-4") {
                return (0.00003, 0.00006)
            } else {
                return (0.000001, 0.000002)
            }
        case .anthropic:
            return (0.000008, 0.000024)
        case .googleAI:
            return (0.000001, 0.000002)
        case .custom:
            return (0.00001, 0.00001)
        }
    }
}

// MARK: - Cloud Model Request

/// A request to a cloud model
public struct CloudModelRequest: Sendable {
    /// The input prompt
    public let prompt: String
    
    /// The ID of the cloud model
    public let modelId: String
    
    /// Maximum number of tokens to generate
    public let maxTokens: Int
    
    /// Temperature for generation
    public let temperature: Float
    
    /// Top-p sampling parameter
    public let topP: Float
    
    /// The cloud provider
    public let provider: CloudProvider
    
    /// Initialize a new cloud model request
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - modelId: The ID of the cloud model
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Temperature for generation
    ///   - topP: Top-p sampling parameter
    ///   - provider: The cloud provider
    public init(
        prompt: String,
        modelId: String,
        maxTokens: Int = 1024,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        provider: CloudProvider
    ) {
        self.prompt = prompt
        self.modelId = modelId
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.provider = provider
    }
}

// MARK: - Cloud Provider

/// A cloud provider for AI models
public enum CloudProvider: String, CaseIterable, Codable, Sendable {
    /// OpenAI (GPT models)
    case openAI = "OpenAI"
    
    /// Anthropic (Claude models)
    case anthropic = "Anthropic"
    
    /// Google AI (Gemini models)
    case googleAI = "GoogleAI"
    
    /// Custom provider
    case custom = "Custom"
}

// MARK: - Cloud Execution Errors

/// Errors that can occur in cloud execution
public enum CloudExecutionError: Error {
    /// No API key was found for the provider
    case missingAPIKey
    
    /// The API returned an error
    case apiError(statusCode: Int)
    
    /// The response was invalid
    case invalidResponse
    
    /// The response format was invalid
    case invalidResponseFormat
    
    /// The executor was deallocated
    case executorDeallocated
}

// MARK: - Update ExecutionEngine

extension ExecutionEngine {
    /// Execute a hybrid request using both local and cloud models
    /// - Parameters:
    ///   - context: The request context
    ///   - localModels: The local models to use
    ///   - cloudModels: The cloud models to use
    ///   - mode: The execution mode
    /// - Returns: The generated text
    public func executeHybrid(
        context: RequestContext,
        localModels: [RegisteredModel],
        cloudModels: [(modelId: String, provider: CloudProvider)],
        mode: ExecutionMode
    ) async throws -> String {
        logger.info("Executing hybrid request with \(localModels.count) local models and \(cloudModels.count) cloud models in mode: \(String(describing: mode))")
        
        // If no models are provided, throw an error
        guard !localModels.isEmpty || !cloudModels.isEmpty else {
            logger.error("No models provided for hybrid execution")
            throw ExecutionError.noModelsProvided
        }
        
        // Execute based on the mode
        switch mode {
        case .auto:
            // Automatically determine the best execution mode
            return try await executeHybridAuto(context: context, localModels: localModels, cloudModels: cloudModels)
        case .single:
            // Use a single model (prefer local)
            if let localModel = localModels.first {
                return try await executeSingle(context: context, model: localModel)
            } else if let cloudModel = cloudModels.first {
                return try await cloudExecutor.executeCloudModel(
                    context: context,
                    modelId: cloudModel.modelId,
                    provider: cloudModel.provider
                )
            } else {
                throw ExecutionError.noModelsProvided
            }
        case .chain:
            // Chain multiple models (local and cloud)
            return try await executeHybridChain(context: context, localModels: localModels, cloudModels: cloudModels)
        case .parallel:
            // Execute models in parallel (local and cloud)
            return try await executeHybridParallel(context: context, localModels: localModels, cloudModels: cloudModels)
        }
    }
    
    /// Execute a hybrid chain of models in sequence
    /// - Parameters:
    ///   - context: The request context
    ///   - localModels: The local models to use
    ///   - cloudModels: The cloud models to use
    /// - Returns: The final result after processing through all models
    private func executeHybridChain(
        context: RequestContext,
        localModels: [RegisteredModel],
        cloudModels: [(modelId: String, provider: CloudProvider)]
    ) async throws -> String {
        logger.info("Executing hybrid chain with \(localModels.count) local models and \(cloudModels.count) cloud models")
        
        // If no models are provided, throw an error
        guard !localModels.isEmpty || !cloudModels.isEmpty else {
            logger.error("No models provided for hybrid chain execution")
            throw ExecutionError.noModelsProvided
        }
        
        // Start with the original prompt
        var currentPrompt = context.prompt
        var currentResult = ""
        
        // Process through local models first
        for (index, model) in localModels.enumerated() {
            logger.info("Chain step \(index + 1): Using local model \(model.modelType.rawValue)")
            
            // Create a new context with the current prompt
            let stepContext = RequestContext(
                prompt: currentPrompt,
                taskType: context.taskType,
                maxTokens: context.maxTokens,
                temperature: context.temperature,
                topP: context.topP,
                repetitionPenalty: context.repetitionPenalty
            )
            
            // Execute the model
            currentResult = try await executeSingle(context: stepContext, model: model)
            
            // Use the result as the prompt for the next model
            currentPrompt = currentResult
        }
        
        // Then process through cloud models
        for (index, cloudModel) in cloudModels.enumerated() {
            logger.info("Chain step \(localModels.count + index + 1): Using cloud model \(cloudModel.modelId) from provider \(cloudModel.provider.rawValue)")
            
            // Create a new context with the current prompt
            let stepContext = RequestContext(
                prompt: currentPrompt,
                taskType: context.taskType,
                maxTokens: context.maxTokens,
                temperature: context.temperature,
                topP: context.topP,
                repetitionPenalty: context.repetitionPenalty
            )
            
            // Execute the model
            currentResult = try await cloudExecutor.executeCloudModel(
                context: stepContext,
                modelId: cloudModel.modelId,
                provider: cloudModel.provider
            )
            
            // Use the result as the prompt for the next model
            currentPrompt = currentResult
        }
        
        return currentResult
    }
    
    /// Execute multiple models in parallel (local and cloud) and combine their results
    /// - Parameters:
    ///   - context: The request context
    ///   - localModels: The local models to use
    ///   - cloudModels: The cloud models to use
    /// - Returns: The combined result
    private func executeHybridParallel(
        context: RequestContext,
        localModels: [RegisteredModel],
        cloudModels: [(modelId: String, provider: CloudProvider)]
    ) async throws -> String {
        logger.info("Executing hybrid parallel with \(localModels.count) local models and \(cloudModels.count) cloud models")
        
        // If no models are provided, throw an error
        guard !localModels.isEmpty || !cloudModels.isEmpty else {
            logger.error("No models provided for hybrid parallel execution")
            throw ExecutionError.noModelsProvided
        }
        
        // Execute all models in parallel
        let results = try await withThrowingTaskGroup(of: (String, String).self) { group in
            // Add local models to the task group
            for model in localModels {
                group.addTask {
                    let result = try await self.executeSingle(context: context, model: model)
                    return (model.modelType.rawValue, result)
                }
            }
            
            // Add cloud models to the task group
            for cloudModel in cloudModels {
                group.addTask {
                    let result = try await self.cloudExecutor.executeCloudModel(
                        context: context,
                        modelId: cloudModel.modelId,
                        provider: cloudModel.provider
                    )
                    return ("\(cloudModel.provider.rawValue)-\(cloudModel.modelId)", result)
                }
            }
            
            // Collect results
            var modelResults: [(String, String)] = []
            for try await result in group {
                modelResults.append(result)
            }
            
            return modelResults
        }
        
        // Combine results
        var combined = ""
        for (modelName, result) in results {
            combined += "=== \(modelName.uppercased()) ===\n\(result)\n\n"
        }
        
        return combined
    }
    
    /// Automatically determine the best execution mode for hybrid execution
    /// - Parameters:
    ///   - context: The request context
    ///   - localModels: The local models to use
    ///   - cloudModels: The cloud models to use
    /// - Returns: The generated text
    private func executeHybridAuto(
        context: RequestContext,
        localModels: [RegisteredModel],
        cloudModels: [(modelId: String, provider: CloudProvider)]
    ) async throws -> String {
        logger.info("Auto-selecting execution mode for hybrid execution")
        
        // If only one model is provided, use single mode
        if localModels.count + cloudModels.count == 1 {
            if let localModel = localModels.first {
                return try await executeSingle(context: context, model: localModel)
            } else if let cloudModel = cloudModels.first {
                return try await cloudExecutor.executeCloudModel(
                    context: context,
                    modelId: cloudModel.modelId,
                    provider: cloudModel.provider
                )
            }
        }
        
        // For complex reasoning tasks, use chain mode
        if context.taskType == .reasoning {
            return try await executeHybridChain(context: context, localModels: localModels, cloudModels: cloudModels)
        }
        
        // For summarization tasks, use parallel mode
        if context.taskType == .summarization {
            return try await executeHybridParallel(context: context, localModels: localModels, cloudModels: cloudModels)
        }
        
        // Default to using the best available model
        if !cloudModels.isEmpty {
            // Prefer cloud models for general tasks
            let cloudModel = cloudModels.first!
            return try await cloudExecutor.executeCloudModel(
                context: context,
                modelId: cloudModel.modelId,
                provider: cloudModel.provider
            )
        } else {
            // Use the highest priority local model
            let bestModel = localModels.min { $0.priority < $1.priority } ?? localModels[0]
            return try await executeSingle(context: context, model: bestModel)
        }
    }
}

// MARK: - Multi-Step Reasoning

extension ExecutionEngine {
    /// Execute a multi-step reasoning process
    /// - Parameters:
    ///   - context: The request context
    ///   - model: The model to use
    ///   - steps: The number of reasoning steps
    /// - Returns: The final result after reasoning
    public func executeMultiStepReasoning(
        context: RequestContext,
        model: RegisteredModel,
        steps: Int = 3
    ) async throws -> String {
        logger.info("Executing multi-step reasoning with \(steps) steps using model: \(model.modelType.rawValue)")
        
        // Start with the original prompt
        var currentPrompt = """
        I need to solve this problem step by step:
        
        \(context.prompt)
        
        Let me think through this carefully:
        """
        
        var intermediateResults: [String] = []
        var finalResult = ""
        
        // Execute each reasoning step
        for step in 1...steps {
            logger.info("Reasoning step \(step) of \(steps)")
            
            // Create a step-specific prompt
            let stepPrompt: String
            if step == 1 {
                // First step
                stepPrompt = currentPrompt
            } else if step < steps {
                // Intermediate step
                stepPrompt = """
                Based on my previous reasoning:
                
                \(intermediateResults.joined(separator: "\n\n"))
                
                Let me continue my step-by-step reasoning:
                """
            } else {
                // Final step
                stepPrompt = """
                Based on my step-by-step reasoning:
                
                \(intermediateResults.joined(separator: "\n\n"))
                
                Now I can provide a final answer to the original question:
                
                \(context.prompt)
                """
            }
            
            // Create a new context with the step prompt
            let stepContext = RequestContext(
                prompt: stepPrompt,
                taskType: .reasoning,
                maxTokens: context.maxTokens,
                temperature: context.temperature,
                topP: context.topP,
                repetitionPenalty: context.repetitionPenalty
            )
            
            // Execute the model
            let stepResult = try await executeSingle(context: stepContext, model: model)
            
            // Store the intermediate result
            intermediateResults.append("Step \(step): \(stepResult)")
            
            // If this is the final step, store the result
            if step == steps {
                finalResult = stepResult
            }
        }
        
        // Return the final result
        return finalResult
    }
    
    /// Execute a chain-of-thought reasoning process
    /// - Parameters:
    ///   - context: The request context
    ///   - model: The model to use
    /// - Returns: The final result after reasoning
    public func executeChainOfThought(
        context: RequestContext,
        model: RegisteredModel
    ) async throws -> String {
        logger.info("Executing chain-of-thought reasoning using model: \(model.modelType.rawValue)")
        
        // Create a chain-of-thought prompt
        var currentPrompt = """
        I need to solve this problem using chain-of-thought reasoning:
        
        \(context.prompt)
        
        Let me work through this step by step:
        1. 
        """
        
        // Create a new context with the chain-of-thought prompt
        let cotContext = RequestContext(
            prompt: currentPrompt,
            taskType: .reasoning,
            maxTokens: context.maxTokens,
            temperature: context.temperature,
            topP: context.topP,
            repetitionPenalty: context.repetitionPenalty
        )
        
        // Execute the model
        return try await executeSingle(context: cotContext, model: model)
    }
    
    /// Execute a tree-of-thought reasoning process
    /// - Parameters:
    ///   - context: The request context
    ///   - model: The model to use
    ///   - branchingFactor: The number of branches to explore at each step
    ///   - depth: The depth of the tree
    /// - Returns: The final result after reasoning
    public func executeTreeOfThought(
        context: RequestContext,
        model: RegisteredModel,
        branchingFactor: Int = 2,
        depth: Int = 2
    ) async throws -> String {
        logger.info("Executing tree-of-thought reasoning with branching factor \(branchingFactor) and depth \(depth) using model: \(model.modelType.rawValue)")
        
        // Start with the original prompt
        var rootPrompt = """
        I need to solve this problem by exploring multiple approaches:
        
        \(context.prompt)
        
        Let me start by generating \(branchingFactor) different initial approaches:
        """
        
        // Create a new context with the root prompt
        let rootContext = RequestContext(
            prompt: rootPrompt,
            taskType: .reasoning,
            maxTokens: context.maxTokens,
            temperature: 0.9, // Higher temperature for diversity
            topP: context.topP,
            repetitionPenalty: context.repetitionPenalty
        )
        
        // Execute the model to get initial approaches
        let initialApproaches = try await executeSingle(context: rootContext, model: model)
        
        // Split the initial approaches (this is a simplification; in a real implementation, we would parse the approaches more carefully)
        let approaches = initialApproaches.split(separator: "\n\n").prefix(branchingFactor).map { String($0) }
        
        // Explore each approach
        var results: [String] = []
        for (index, approach) in approaches.enumerated() {
            logger.info("Exploring approach \(index + 1) of \(approaches.count)")
            
            // Create a prompt for this approach
            var approachPrompt = """
            Based on the following approach:
            
            \(approach)
            
            Let me continue developing this approach to solve the original problem:
            
            \(context.prompt)
            """
            
            // Create a new context with the approach prompt
            let approachContext = RequestContext(
                prompt: approachPrompt,
                taskType: .reasoning,
                maxTokens: context.maxTokens,
                temperature: context.temperature,
                topP: context.topP,
                repetitionPenalty: context.repetitionPenalty
            )
            
            // Execute the model
            let result = try await executeSingle(context: approachContext, model: model)
            results.append(result)
        }
        
        // Combine the results
        let combinedResults = results.enumerated().map { "Approach \($0 + 1):\n\($1)" }.joined(separator: "\n\n")
        
        // Create a final prompt to select the best approach
        var finalPrompt = """
        I've explored multiple approaches to solve this problem:
        
        \(combinedResults)
        
        Based on these approaches, here is my final answer to the original question:
        
        \(context.prompt)
        """
        
        // Create a new context with the final prompt
        let finalContext = RequestContext(
            prompt: finalPrompt,
            taskType: .reasoning,
            maxTokens: context.maxTokens,
            temperature: 0.5, // Lower temperature for more focused output
            topP: context.topP,
            repetitionPenalty: context.repetitionPenalty
        )
        
        // Execute the model
        return try await executeSingle(context: finalContext, model: model)
    }
}

// MARK: - Advanced Combination Strategy

/// Advanced strategies for combining results from multiple models
public enum AdvancedCombinationStrategy {
    /// Use a weighted average of all results
    case weightedAverage
    
    /// Use an ensemble approach to combine results
    case ensemble
    
    /// Use a debate approach to refine results
    case debate
    
    /// Only use results above a confidence threshold
    case confidenceThreshold(Double)
}

// MARK: - Weighting Strategy

/// Strategies for weighting results from multiple models
public enum WeightingStrategy {
    /// All models have equal weight
    case equal
    
    /// Weight by confidence
    case byConfidence
    
    /// Weight by model capability
    case byModelCapability
    
    /// Custom weights for each model
    case custom([JanetModelType: Double])
}