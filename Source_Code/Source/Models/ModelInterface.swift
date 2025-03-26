//
//  ModelInterface.swift
//  Janet
//
//  Created by Michael folk on 2/25/25.
//

import Foundation
import os
import AppKit

// MARK: - Model Interface
// This protocol defines the interface for AI models

// Renamed from AIModel to JanetAIModel to avoid conflict
public protocol JanetAIModel {
    var isLoaded: Bool { get }
    func load() async throws
    func generateText(prompt: String, maxTokens: Int, temperature: Float, topP: Float, repetitionPenalty: Float) async throws -> String
}

/// Factory for creating model instances
public class ModelFactory {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "ModelFactory")
    
    /// Create a model of the specified type
    public static func createModel(type: ModelType, modelPath: String, tokenizerPath: String) -> JanetAIModel {
        logger.info("Creating model of type: \(String(describing: type))")
        
        // Create OllamaModel for all model types
        logger.info("Creating OllamaModel instance for type: \(type.rawValue)")
        return OllamaModel(modelType: type)
    }
    
    /// Create a model from a path
    public static func createModelFromPath(modelPath: String, tokenizerPath: String, type: ModelType) -> JanetAIModel {
        logger.info("Creating model from path: \(modelPath)")
        return OllamaModel(modelType: type)
    }
}

/// OllamaModel implementation that uses the OllamaService
public class OllamaModel: JanetAIModel {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "OllamaModel")
    // Use the shared service from the app
    private var ollamaService: OllamaService 
    private let modelType: ModelType
    
    // Whether the model is loaded
    public private(set) var isLoaded: Bool = false
    
    /// Initialize with model type
    public init(modelType: ModelType) {
        self.modelType = modelType
        
        // IMPORTANT: Use the shared singleton instance to ensure shared state
        self.ollamaService = OllamaService.shared
        logger.info("Using shared OllamaService singleton")
        
        logger.info("Initialized OllamaModel with type: \(modelType.rawValue)")
        
        // Print debug information about the service state
        logger.info("OllamaService initial state - isRunning: \(self.ollamaService.isRunning), useMockMode: \(self.ollamaService.useMockMode)")
    }
    
    /// Load the model
    public func load() async throws {
        logger.info("Loading Ollama model")
        
        // Force checking Ollama status several times to ensure a connection
        var retryCount = 0
        var isRunning = false
        
        while retryCount < 3 && !isRunning {
            isRunning = await self.ollamaService.checkOllamaStatus()
            if !isRunning {
                logger.warning("Ollama connection attempt \(retryCount + 1) failed, retrying...")
                try await Task.sleep(nanoseconds: 1_000_000_000) // wait 1 second
                retryCount += 1
            }
        }
        
        if !isRunning && !self.ollamaService.useMockMode {
            logger.error("Ollama is not running after \(retryCount) attempts")
            // Don't throw an error, just switch to mock mode
            await MainActor.run {
                self.ollamaService.useMockMode = true
            }
        }
        
        if isRunning {
            logger.info("Successfully connected to Ollama")
            // Load available models
            await self.ollamaService.loadAvailableModels()
            
            // Set the model based on the model type
            switch modelType {
            case .llama:
                if let llamaModel = self.ollamaService.availableModels.first(where: { $0.contains("llama") }) {
                    await MainActor.run {
                        self.ollamaService.currentModel = llamaModel
                    }
                }
            case .mistral:
                if let mistralModel = self.ollamaService.availableModels.first(where: { $0.contains("mistral") }) {
                    await MainActor.run {
                        self.ollamaService.currentModel = mistralModel
                    }
                }
            default:
                // For other types, try to find a matching model or use the default
                if let matchingModel = self.ollamaService.availableModels.first(where: { $0.contains(modelType.rawValue) }) {
                    await MainActor.run {
                        self.ollamaService.currentModel = matchingModel
                    }
                } else if !self.ollamaService.availableModels.isEmpty {
                    // Use the first available model if no matching model found
                    await MainActor.run {
                        self.ollamaService.currentModel = self.ollamaService.availableModels[0]
                    }
                    logger.info("Using model: \(self.ollamaService.currentModel)")
                }
            }
        }
        
        // Mark as loaded regardless of connection status
        self.isLoaded = true
        logger.info("Ollama model loaded successfully")
    }
    
    /// Generate text based on the given prompt
    public func generateText(prompt: String, maxTokens: Int = 1024, temperature: Float = 0.7, topP: Float = 0.9, repetitionPenalty: Float = 1.1) async throws -> String {
        logger.info("Generating text for prompt: \(prompt)")
        
        // Check if model is loaded
        guard isLoaded else {
            logger.error("Model not loaded")
            throw ModelError.modelNotLoaded
        }
        
        // Generate response using OllamaService
        let response = await self.ollamaService.generateResponse(prompt: prompt)
        
        logger.info("Generated text of length: \(response.count)")
        return response
    }
}