//
//  CodeAssistantManager.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os
import Combine

/// Manager for code generation model integration
public class CodeAssistantManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether a code model is available
    @Published public var isModelAvailable: Bool = false
    
    /// Whether the model is currently processing a request
    @Published public var isProcessing: Bool = false
    
    /// Current model version
    @Published public var modelVersion: String = "phi:latest"
    
    /// Recent code generations
    @Published public var recentGenerations: [CodeGeneration] = []
    
    /// Performance metrics
    @Published public var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = CodeAssistantManager()
    
    // MARK: - Private Properties
    
    /// Logger for the code assistant manager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "CodeAssistantManager")
    
    /// Queue for thread safety
    private let queue = DispatchQueue(label: "com.janet.ai.codeAssistantManager", qos: .userInitiated)
    
    /// Ollama service
    private let ollamaService = OllamaService.shared
    
    /// Model orchestrator
    private let modelOrchestrator = ModelOrchestrator.shared
    
    /// Code model tester
    private let codeModelTester = CodeModelTester.shared
    
    /// Available code models
    private let availableCodeModels = ["phi:latest", "llama3:latest", "mistral:latest", "deepseek-coder:6.7b", "codellama:latest"]
    
    /// Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize a new code assistant manager
    private init() {
        logger.info("Initializing CodeAssistantManager")
        
        // Check if a model is available
        Task {
            await checkModelAvailability()
        }
        
        // Set up observers
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Generate code based on a prompt
    /// - Parameters:
    ///   - prompt: The prompt to generate code from
    ///   - language: The programming language to generate code in
    ///   - maxTokens: The maximum number of tokens to generate
    /// - Returns: The generated code
    public func generateCode(prompt: String, language: String, maxTokens: Int = 2048) async throws -> String {
        logger.info("Generating code for prompt: \(prompt)")
        
        // Check if a model is available
        if !isModelAvailable {
            logger.error("No code model is available")
            throw CodeAssistantError.modelNotAvailable
        }
        
        // Set processing state
        await MainActor.run {
            isProcessing = true
        }
        
        // Start timing
        let startTime = Date()
        
        do {
            // Format the prompt for code generation
            let formattedPrompt = formatPrompt(prompt: prompt, language: language)
            
            // Use the orchestrator to generate code with the appropriate model
            let output = try await modelOrchestrator.generateText(
                prompt: formattedPrompt,
                taskType: .code,
                maxTokens: maxTokens,
                temperature: 0.2,
                topP: 0.95,
                repetitionPenalty: 1.1
            )
            
            // Calculate execution time
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Store the generation
            let generation = CodeGeneration(
                prompt: prompt,
                language: language,
                output: output,
                timestamp: Date(),
                executionTime: executionTime
            )
            
            await MainActor.run {
                // Add to recent generations
                recentGenerations.insert(generation, at: 0)
                
                // Limit to 10 recent generations
                if recentGenerations.count > 10 {
                    recentGenerations.removeLast()
                }
                
                // Update performance metrics
                performanceMetrics.totalRequests += 1
                performanceMetrics.totalExecutionTime += executionTime
                performanceMetrics.averageExecutionTime = performanceMetrics.totalExecutionTime / Double(performanceMetrics.totalRequests)
                
                // Set processing state
                isProcessing = false
            }
            
            logger.info("Code generation successful in \(executionTime) seconds")
            return output
        } catch {
            // Set processing state
            await MainActor.run {
                isProcessing = false
                
                // Update performance metrics
                performanceMetrics.totalRequests += 1
                performanceMetrics.failedRequests += 1
            }
            
            logger.error("Failed to generate code: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Generate code with auto-retry
    /// - Parameters:
    ///   - prompt: The prompt to generate code from
    ///   - language: The programming language to generate code in
    ///   - maxTokens: The maximum number of tokens to generate
    ///   - maxRetries: The maximum number of retries
    /// - Returns: The generated code
    public func generateCodeWithRetry(prompt: String, language: String, maxTokens: Int = 2048, maxRetries: Int = 3) async throws -> String {
        logger.info("Generating code with retry for prompt: \(prompt)")
        
        var lastError: Error?
        
        // Try up to maxRetries times
        for retryCount in 0..<maxRetries {
            do {
                // Generate code
                let result = try await generateCode(prompt: prompt, language: language, maxTokens: maxTokens)
                
                // If successful, return the result
                return result
            } catch {
                // Log the error
                logger.warning("Retry \(retryCount + 1) failed: \(error.localizedDescription)")
                
                // Store the error
                lastError = error
                
                // Wait before retrying
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * (retryCount + 1)))
            }
        }
        
        // If we get here, all retries failed
        logger.error("All retries failed")
        throw lastError ?? CodeAssistantError.allRetriesFailed
    }
    
    /// Run tests on the code models
    /// - Returns: Test results
    public func runTests() async -> [CodeTestResult] {
        logger.info("Running tests on code models")
        
        // Run the tests
        let results = await codeModelTester.runCodeModelTests()
        
        // Log the results
        let successRate = Double(results.filter { $0.passed }.count) / Double(results.count)
        logger.info("Test success rate: \(successRate * 100)%")
        
        return results
    }
    
    /// Compare different code models
    /// - Returns: Comparison results
    public func compareWithOtherModels() async -> [ModelComparisonResult] {
        logger.info("Comparing code models")
        
        // Run the comparison
        let results = await codeModelTester.compareCodeModels()
        
        // Log the results
        for result in results {
            if let bestModel = result.bestModel {
                logger.info("Best model for \(result.testCase.name): \(bestModel)")
            } else {
                logger.warning("No model passed the test: \(result.testCase.name)")
            }
        }
        
        return results
    }
    
    /// Check if a code model is available
    /// - Returns: Whether a model is available
    public func checkModelAvailability() async {
        logger.info("Checking code model availability")
        
        // First check if the orchestrator has any models loaded
        let loadedModels = modelOrchestrator.modelRegistry.getAllRegisteredModels().filter { $0.isLoaded }
        
        if !loadedModels.isEmpty {
            await MainActor.run {
                isModelAvailable = true
            }
            logger.info("Code models are available through the orchestrator")
            return
        }
        
        // If no models are loaded in the orchestrator, check Ollama
        do {
            // Create the request
            let url = URL(string: "\(ollamaService.apiURL)/tags")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Send the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response from Ollama API")
                await MainActor.run {
                    isModelAvailable = false
                }
                return
            }
            
            let success = httpResponse.statusCode == 200
            
            if success {
                // Parse the response
                if let responseDict = try? JSONDecoder().decode(OllamaTagsResponse.self, from: data) {
                    // Check if any code model is available
                    let modelNames = responseDict.models.map { $0.name }
                    let isAvailable = modelNames.contains { name in
                        availableCodeModels.contains { name.contains($0) }
                    }
                    
                    await MainActor.run {
                        isModelAvailable = isAvailable
                    }
                    
                    logger.info("Code models are \(isAvailable ? "available" : "not available")")
                } else {
                    logger.error("Failed to parse response from Ollama API")
                    await MainActor.run {
                        isModelAvailable = false
                    }
                }
            } else {
                logger.error("Failed to check model availability: HTTP \(httpResponse.statusCode)")
                await MainActor.run {
                    isModelAvailable = false
                }
            }
        } catch {
            logger.error("Failed to check model availability: \(error.localizedDescription)")
            await MainActor.run {
                isModelAvailable = false
            }
        }
    }
    
    /// Pull the selected model
    /// - Returns: Whether the pull was successful
    public func pullModel() async -> Bool {
        logger.info("Pulling model: \(self.modelVersion)")
        
        do {
            // Create the request
            let url = URL(string: "\(ollamaService.apiURL)/pull")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Create the request body
            let body: [String: Any] = [
                "name": modelVersion,
                "stream": false
            ]
            
            // Serialize the body
            guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
                logger.error("Failed to serialize request body")
                return false
            }
            
            request.httpBody = httpBody
            
            // Send the request
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response from Ollama API")
                return false
            }
            
            let success = httpResponse.statusCode == 200
            
            if success {
                logger.info("Model pull successful")
                
                // Check if the model is available
                await checkModelAvailability()
                
                return true
            } else {
                logger.error("Failed to pull model: HTTP \(httpResponse.statusCode)")
                return false
            }
        } catch {
            logger.error("Failed to pull model: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Clear recent generations
    public func clearRecentGenerations() {
        logger.info("Clearing recent generations")
        
        recentGenerations = []
    }
    
    /// Reset performance metrics
    public func resetPerformanceMetrics() {
        logger.info("Resetting performance metrics")
        
        performanceMetrics = PerformanceMetrics()
    }
    
    // MARK: - Private Methods
    
    /// Set up observers
    private func setupObservers() {
        logger.info("Setting up observers")
        
        // Observe model availability changes
        $isModelAvailable
            .dropFirst()
            .sink { [weak self] isAvailable in
                self?.logger.info("Code model availability changed: \(isAvailable)")
            }
            .store(in: &cancellables)
        
        // Observe model version changes
        $modelVersion
            .dropFirst()
            .sink { [weak self] version in
                self?.logger.info("Code model version changed: \(version)")
                
                // Check if the model is available
                Task {
                    await self?.checkModelAvailability()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Format a prompt for code generation
    /// - Parameters:
    ///   - prompt: The prompt to format
    ///   - language: The programming language
    /// - Returns: The formatted prompt
    private func formatPrompt(prompt: String, language: String) -> String {
        return """
        You are an expert programmer specializing in \(language) development.
        
        Write clean, efficient, and well-documented code in \(language) for the following task:
        
        \(prompt)
        
        Only provide the code without explanations unless specifically asked for in the prompt.
        """
    }
}

// MARK: - Code Generation

/// A code generation
public struct CodeGeneration: Identifiable {
    /// Unique identifier
    public let id = UUID()
    
    /// Prompt for the generation
    public let prompt: String
    
    /// Programming language
    public let language: String
    
    /// Generated output
    public let output: String
    
    /// Timestamp of the generation
    public let timestamp: Date
    
    /// Execution time in seconds
    public let executionTime: TimeInterval
    
    /// Initialize a new code generation
    /// - Parameters:
    ///   - prompt: Prompt for the generation
    ///   - language: Programming language
    ///   - output: Generated output
    ///   - timestamp: Timestamp of the generation
    ///   - executionTime: Execution time in seconds
    public init(
        prompt: String,
        language: String,
        output: String,
        timestamp: Date,
        executionTime: TimeInterval
    ) {
        self.prompt = prompt
        self.language = language
        self.output = output
        self.timestamp = timestamp
        self.executionTime = executionTime
    }
}

// MARK: - Performance Metrics

/// Performance metrics for code generation
public struct PerformanceMetrics {
    /// Total number of requests
    public var totalRequests: Int = 0
    
    /// Number of failed requests
    public var failedRequests: Int = 0
    
    /// Total execution time in seconds
    public var totalExecutionTime: TimeInterval = 0
    
    /// Average execution time in seconds
    public var averageExecutionTime: TimeInterval = 0
    
    /// Initialize new performance metrics
    public init() {}
}

// MARK: - Code Assistant Error

/// Errors that can occur when using code generation
public enum CodeAssistantError: Error, LocalizedError {
    /// The model is not available
    case modelNotAvailable
    
    /// Failed to serialize the request
    case requestSerializationFailed
    
    /// Invalid response from the API
    case invalidResponse
    
    /// Failed to parse the response
    case responseParsingFailed
    
    /// HTTP error
    case httpError(statusCode: Int)
    
    /// All retries failed
    case allRetriesFailed
    
    /// Error description
    public var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "No code generation model is available"
        case .requestSerializationFailed:
            return "Failed to serialize the request"
        case .invalidResponse:
            return "Invalid response from the API"
        case .responseParsingFailed:
            return "Failed to parse the response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .allRetriesFailed:
            return "All retries failed"
        }
    }
} 