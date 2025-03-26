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
    public static func createModel(type: ModelType, modelPath: String, tokenizerPath: String) -> any JanetAIModel {
        logger.info("Creating model of type: \(String(describing: type))")
        
        // Create OllamaModelImpl for all model types
        logger.info("Creating OllamaModelImpl instance for type: \(type.rawValue)")
        return OllamaModelImpl(modelType: type)
    }
    
    /// Create a model from a path
    public static func createModelFromPath(modelPath: String, tokenizerPath: String, type: ModelType) -> any JanetAIModel {
        logger.info("Creating model from path: \(modelPath)")
        return OllamaModelImpl(modelType: type)
    }
}

/// OllamaModelImpl implementation that uses the OllamaService
public class OllamaModelImpl: JanetAIModel {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "OllamaModelImpl")
    // Use the shared service from the app
    private var ollamaService: OllamaService 
    private let modelType: ModelType
    
    // Whether the model is loaded
    public private(set) var isLoaded: Bool = false
    private var connectionAttempts = 0
    private var maxConnectionAttempts = 3
    
    /// Initialize with model type
    public init(modelType: ModelType) {
        self.modelType = modelType
        
        // IMPORTANT: Use the shared singleton instance to ensure shared state
        self.ollamaService = OllamaService.shared
        logger.info("Using shared OllamaService singleton")
        
        logger.info("Initialized OllamaModelImpl with type: \(modelType.rawValue)")
        
        // Print debug information about the service state
        logger.info("OllamaService initial state - isRunning: \(self.ollamaService.isRunning), useMockMode: \(self.ollamaService.useMockMode)")
    }
    
    /// Load the model
    public func load() async throws {
        logger.info("Loading model of type: \(modelType.rawValue)")
        
        // Check if Ollama is running
        if !ollamaService.isRunning {
            logger.warning("Ollama service is not running, attempting to check status")
            
            // Try to check Ollama status
            let isRunning = await ollamaService.checkOllamaStatus()
            if !isRunning {
                logger.error("Failed to connect to Ollama service")
                throw ModelError.modelLoadFailed(reason: "Failed to connect to Ollama service")
            } else {
                logger.info("Successfully connected to Ollama service")
            }
        }
        
        // Load available models
        await ollamaService.loadAvailableModels()
        
        // Find the model that matches our type
        let modelName = modelType.displayName.lowercased()
        let modelExists = ollamaService.availableModels.contains { $0.lowercased().contains(modelName) }
        
        if !modelExists && connectionAttempts < maxConnectionAttempts {
            logger.warning("Model \(modelName) not found in available models: \(ollamaService.availableModels.joined(separator: ", "))")
            logger.info("Attempting to reconnect to Ollama (attempt \(connectionAttempts + 1)/\(maxConnectionAttempts))")
            
            // Increment connection attempts
            connectionAttempts += 1
            
            // Try to check Ollama status again
            let isRunning = await ollamaService.checkOllamaStatus()
            if !isRunning {
                logger.error("Failed to reconnect to Ollama service")
                throw ModelError.modelLoadFailed(reason: "Failed to reconnect to Ollama service")
            } else {
                logger.info("Successfully reconnected to Ollama service")
                
                // Try loading again
                return try await load()
            }
        } else if !modelExists {
            logger.error("Model \(modelName) not found after \(maxConnectionAttempts) attempts")
            throw ModelError.modelNotFound
        }
        
        // Set the model as loaded
        isLoaded = true
        logger.info("Model \(modelName) loaded successfully")
    }
    
    /// Generate text from the model
    public func generateText(prompt: String, maxTokens: Int = 2048, temperature: Float = 0.7, topP: Float = 0.9, repetitionPenalty: Float = 1.1) async throws -> String {
        logger.info("Generating text with prompt: \(prompt.prefix(50))...")
        
        // Check if the model is loaded
        if !isLoaded {
            logger.warning("Model not loaded, attempting to load")
            try await load()
        }
        
        // Generate text using the Ollama service
        do {
            // Use the generateResponse method that's available in OllamaService
            let response = await ollamaService.generateResponse(prompt: prompt)
            
            logger.info("Generated text: \(response.prefix(50))...")
            return response
        } catch {
            logger.error("Failed to generate text: \(error.localizedDescription)")
            throw ModelError.generationFailed(error.localizedDescription)
        }
    }
}
