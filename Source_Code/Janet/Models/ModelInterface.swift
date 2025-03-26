//
//  ModelInterface.swift
//  Janet
//
//  Created by Michael folk on 2/25/25.
//

import Foundation
import os
import AppKit
import Combine

// MARK: - Model Interface
// This protocol defines the interface for AI models

// Renamed from AIModel to JanetAIModel to avoid conflict
public protocol JanetAIModel: ObservableObject {
    var isLoaded: Bool { get }
    func load() async throws
    func generateText(prompt: String, maxTokens: Int, temperature: Float, topP: Float, repetitionPenalty: Float) async throws -> String
}

/// Factory for creating model instances
public class ModelFactory {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "ModelFactory")
    
    /// Create a model of the specified type
    public static func createModel(type: JanetModelType, modelPath: String, tokenizerPath: String) -> any JanetAIModel {
        logger.info("Creating model of type: \(String(describing: type))")
        
        // Create OllamaModelImpl for all model types
        logger.info("Creating OllamaModelImpl instance for type: \(type.rawValue)")
        return OllamaModelImpl(modelType: type)
    }
    
    /// Create a model from a path
    public static func createModelFromPath(modelPath: String, tokenizerPath: String, type: JanetModelType) -> any JanetAIModel {
        logger.info("Creating model from path: \(modelPath)")
        return OllamaModelImpl(modelType: type)
    }
}

/// OllamaModelImpl implementation that uses the OllamaService
public class OllamaModelImpl: JanetAIModel {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "OllamaModelImpl")
    // Use the shared service from the app
    private var ollamaService: OllamaService 
    private let modelType: JanetModelType
    
    // Whether the model is loaded
    public private(set) var isLoaded: Bool = false
    private var connectionAttempts = 0
    private var maxConnectionAttempts = 3
    
    /// Initialize with model type
    public init(modelType: JanetModelType) {
        self.modelType = modelType
        
        // IMPORTANT: Use the shared singleton instance to ensure shared state
        self.ollamaService = OllamaService.shared
        logger.info("Using shared OllamaService singleton")
        
        logger.info("Initialized OllamaModelImpl with type: \(modelType.rawValue)")
        
        // Print debug information about the service state
        logger.info("OllamaService initial state - isRunning: \(self.ollamaService.isRunning)")
    }
    
    /// Load the model
    public func load() async throws {
        logger.info("Loading Ollama model: \(self.modelType.rawValue)")
        
        // Check if the model is already loaded
        if isLoaded {
            logger.info("Model already loaded")
            return
        }
        
        // Check if the Ollama service is running
        let maxConnectionAttempts = 3
        var isRunning = false
        
        // Try to connect to Ollama service multiple times
        for attempt in 1...maxConnectionAttempts {
            isRunning = await ollamaService.checkOllamaStatus()
            if isRunning {
                break
            }
            
            logger.warning("Ollama service not running (attempt \(attempt)/\(maxConnectionAttempts))")
            try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retrying
        }
        
        if !isRunning {
            logger.error("Ollama service is not running after \(maxConnectionAttempts) attempts")
            throw ModelError.modelLoadFailed(reason: "Ollama service is not running. Please start Ollama and try again.")
        }
        
        // Load available models
        await ollamaService.loadAvailableModels()
        
        // Mark the model as loaded
        isLoaded = true
        logger.info("Model loaded successfully")
    }
    
    /// Generate text from the model
    public func generateText(prompt: String, maxTokens: Int = 2048, temperature: Float = 0.7, topP: Float = 0.9, repetitionPenalty: Float = 1.1) async throws -> String {
        logger.info("Generating text with prompt: \(prompt.prefix(50))...")
        
        // Check if the model is loaded
        if !isLoaded {
            logger.warning("Model not loaded, attempting to load")
            try await load()
        }
        
        // Check if Ollama is running
        let isRunning = await ollamaService.checkOllamaStatus()
        if !isRunning {
            logger.error("Ollama service is not running")
            throw ModelError.generationFailed("Ollama service is not running. Please start Ollama and try again.")
        }
        
        // Generate text using the Ollama service
        do {
            // Use the generateResponse method that's available in OllamaService
            let response = await ollamaService.generateResponse(prompt: prompt)
            
            // Check if the response contains an error message
            if response.starts(with: "Error:") {
                logger.error("Error in response: \(response)")
                throw ModelError.generationFailed(response)
            }
            
            logger.info("Generated text: \(response.prefix(50))...")
            return response
        } catch {
            logger.error("Failed to generate text: \(error.localizedDescription)")
            throw ModelError.generationFailed(error.localizedDescription)
        }
    }
}

// Define the ModelInterface protocol properly
public protocol ModelInterface {
    func generateResponse(for prompt: String) async throws -> String
    func isModelAvailable() async -> Bool
}

// Extension to provide default implementation
extension ModelInterface {
    /// Initialize the model interface
    init(modelType: JanetModelType, ollamaService: OllamaService) {
        fatalError("This initializer must be implemented by conforming types")
    }
}
