//
//  ModelManager.swift
//  Janet
//
//  Created by Michael folk on 2/25/25.
//

import Foundation
import os

/// Manages AI models
public class ModelManager: ObservableObject {
    // Singleton instance
    public static let shared = ModelManager()
    
    // Model instance
    private var model: JanetAIModel?
    
    // Current model type
    private var modelType: ModelType = .ollama
    
    // Whether the model is loaded
    @Published public private(set) var isLoaded: Bool = false
    
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "ModelManager")
    
    // Private initializer for singleton
    private init() {
        logger.info("Initializing ModelManager")
    }
    
    /// Load a model of the specified type
    public func loadModel(type: ModelType = .ollama) async throws {
        logger.info("Loading model of type: \(String(describing: type))")
        
        // Check if the model files exist at the default paths
        if !type.modelFilesExist {
            logger.warning("Model files do not exist at default paths, searching for alternatives")
            
            // Try to find a valid model path
            guard let validModelPath = type.firstValidModelPath else {
                logger.error("No valid model path found for type: \(String(describing: type))")
                throw ModelError.modelNotFound
            }
            
            // Construct the tokenizer path
            let tokenizerPath = "\(validModelPath)/tokenizer.json"
            
            // Check if the tokenizer exists
            if !FileManager.default.fileExists(atPath: tokenizerPath) {
                logger.error("Tokenizer not found at path: \(tokenizerPath)")
                throw ModelError.tokenizerNotFound
            }
            
            // Load the model with the valid paths
            logger.info("Found valid model path: \(validModelPath)")
            logger.info("Using tokenizer path: \(tokenizerPath)")
            
            return try await loadModelWithCustomPaths(type: type, modelPath: validModelPath, tokenizerPath: tokenizerPath)
        }
        
        // Get the model and tokenizer paths
        let modelPath = type.defaultModelPath
        let tokenizerPath = type.defaultTokenizerPath
        
        logger.info("Using default model path: \(modelPath)")
        logger.info("Using default tokenizer path: \(tokenizerPath)")
        
        // Print debug information about the paths
        print("DEBUG: Model path: \(modelPath)")
        print("DEBUG: Tokenizer path: \(tokenizerPath)")
        print("DEBUG: Model path exists: \(FileManager.default.fileExists(atPath: modelPath))")
        print("DEBUG: Tokenizer path exists: \(FileManager.default.fileExists(atPath: tokenizerPath))")
        
        // For Ollama models, we don't need to verify file existence
        if type != .ollama {
            // Verify that the model and tokenizer paths exist
            if !FileManager.default.fileExists(atPath: modelPath) {
                logger.error("Model path does not exist: \(modelPath)")
                throw ModelError.invalidModelPath(path: modelPath)
            }
            
            if !FileManager.default.fileExists(atPath: tokenizerPath) {
                logger.error("Tokenizer path does not exist: \(tokenizerPath)")
                throw ModelError.invalidTokenizerPath(path: tokenizerPath)
            }
            
            logger.info("Model and tokenizer paths verified")
        }
        
        // Create the model
        model = ModelFactory.createModel(type: type, modelPath: modelPath, tokenizerPath: tokenizerPath) as JanetAIModel
        logger.info("Model created successfully")
        
        // Load the model
        do {
            try await model?.load()
            logger.info("Model loaded successfully")
            print("DEBUG: Model loaded successfully")
        } catch {
            logger.error("Failed to load model: \(error.localizedDescription)")
            print("DEBUG: Failed to load model: \(error)")
            throw ModelError.modelLoadFailed(reason: "Failed to load model: \(error.localizedDescription)")
        }
        
        // Update the model type and loaded state
        modelType = type
        
        // Update published property on main thread
        await MainActor.run {
            isLoaded = model?.isLoaded ?? false
        }
        
        logger.info("Model loaded successfully: \(self.isLoaded)")
        print("DEBUG: Model loaded state: \(self.isLoaded)")
    }
    
    /// Load a model with custom paths
    public func loadModelWithCustomPaths(type: ModelType = .ollama, modelPath: String, tokenizerPath: String) async throws {
        logger.info("Loading model of type: \(String(describing: type)) with custom paths")
        logger.info("Custom model path: \(modelPath)")
        logger.info("Custom tokenizer path: \(tokenizerPath)")
        
        // For Ollama models, we don't need to verify file existence
        if type != .ollama {
            // Verify that the model and tokenizer paths exist
            if !FileManager.default.fileExists(atPath: modelPath) {
                logger.error("Custom model path does not exist: \(modelPath)")
                throw ModelError.invalidModelPath(path: modelPath)
            }
            
            if !FileManager.default.fileExists(atPath: tokenizerPath) {
                logger.error("Custom tokenizer path does not exist: \(tokenizerPath)")
                throw ModelError.invalidTokenizerPath(path: tokenizerPath)
            }
            
            logger.info("Custom model and tokenizer paths verified")
        }
        
        // Create the model
        model = ModelFactory.createModel(type: type, modelPath: modelPath, tokenizerPath: tokenizerPath) as JanetAIModel
        logger.info("Model created successfully with custom paths")
        
        // Load the model
        do {
            try await model?.load()
            logger.info("Model loaded successfully with custom paths")
        } catch {
            logger.error("Failed to load model with custom paths: \(error.localizedDescription)")
            throw ModelError.modelLoadFailed(reason: "Failed to load model with custom paths: \(error.localizedDescription)")
        }
        
        // Update the model type and loaded state
        modelType = type
        
        // Update published property on main thread
        await MainActor.run {
            isLoaded = model?.isLoaded ?? false
        }
        
        logger.info("Model loaded successfully with custom paths: \(self.isLoaded)")
    }
    
    /// Generate text based on the given prompt
    public func generateText(prompt: String, maxTokens: Int = 1024, temperature: Float = 0.7, topP: Float = 0.9, repetitionPenalty: Float = 1.1) async throws -> String {
        logger.info("Generating text for prompt: \(prompt)")
        print("🔍 JANET_DEBUG: Generating text for prompt: \(prompt)")
        print("🔍 JANET_DEBUG: Model loaded state: \(self.isLoaded)")
        
        // Check if the model is loaded and try to load if not
        if model == nil || !isLoaded {
            logger.error("Model not loaded")
            print("🔍 JANET_DEBUG: Model not loaded, attempting to load now")
            
            // Try to load the model
            do {
                try await loadModel()
                print("🔍 JANET_DEBUG: Model loaded successfully on demand")
            } catch {
                logger.error("Failed to load model on demand: \(error.localizedDescription)")
                print("🔍 JANET_DEBUG: Failed to load model on demand: \(error)")
                throw ModelError.modelLoadFailed(reason: "Failed to load model on demand: \(error.localizedDescription)")
            }
            
            // Verify model loaded successfully
            if model == nil || !isLoaded {
                logger.error("Failed to load model on demand")
                print("🔍 JANET_DEBUG: Failed to load model on demand after attempt")
                throw ModelError.modelNotLoaded
            }
            
            logger.info("Model loaded on demand")
            print("🔍 JANET_DEBUG: Model loaded on demand")
        }
        
        // At this point, model should be non-nil, but let's check again to be safe
        guard let model = self.model else {
            print("🔍 JANET_DEBUG: Model is still nil after loading attempt")
            throw ModelError.modelNotLoaded
        }
        
        // Generate text
        do {
            print("🔍 JANET_DEBUG: Starting text generation with parameters: maxTokens=\(maxTokens), temperature=\(temperature), topP=\(topP), repetitionPenalty=\(repetitionPenalty)")
            
            let startTime = Date()
            let result = try await model.generateText(
                prompt: prompt,
                maxTokens: maxTokens,
                temperature: temperature,
                topP: topP,
                repetitionPenalty: repetitionPenalty
            )
            let duration = Date().timeIntervalSince(startTime)
            
            logger.info("Text generated successfully in \(duration) seconds")
            print("🔍 JANET_DEBUG: Text generated successfully with length: \(result.count) in \(String(format: "%.2f", duration)) seconds")
            
            // If result is empty, return a fallback message
            if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("🔍 JANET_DEBUG: Generated text was empty, returning fallback message")
                return "I'm sorry, I couldn't generate a response. Please try again with a different question."
            }
            
            return result
        } catch {
            logger.error("Failed to generate text: \(error.localizedDescription)")
            print("🔍 JANET_DEBUG: Failed to generate text: \(error)")
            
            // Provide a more user-friendly error message
            let errorMessage: String
            if let modelError = error as? ModelError {
                switch modelError {
                case .modelNotLoaded:
                    errorMessage = "The AI model is not loaded. Please try again in a moment."
                case .modelLoadFailed(let reason):
                    errorMessage = "Failed to load the AI model: \(reason)"
                case .modelNotFound:
                    errorMessage = "The AI model could not be found. Please check your installation."
                case .tokenizerNotFound:
                    errorMessage = "The tokenizer could not be found. Please check your installation."
                case .invalidModelPath(let path):
                    errorMessage = "Invalid model path: \(path)"
                case .invalidTokenizerPath(let path):
                    errorMessage = "Invalid tokenizer path: \(path)"
                case .generationFailed(let reason):
                    errorMessage = "Failed to generate text: \(reason)"
                case .invalidModelConfiguration:
                    errorMessage = "Invalid model configuration. Please check your settings."
                case .invalidPrompt:
                    errorMessage = "Invalid prompt provided. Please try again with a different prompt."
                @unknown default:
                    errorMessage = "An unknown error occurred: \(modelError.localizedDescription)"
                }
            } else {
                errorMessage = "An error occurred while generating text: \(error.localizedDescription)"
            }
            
            throw ModelError.modelLoadFailed(reason: errorMessage)
        }
    }
    
    /// Get the current model type
    public func getModelType() -> ModelType {
        return modelType
    }
    
    /// Get the current model path
    public func getModelPath() -> String {
        return modelType.defaultModelPath
    }
    
    /// Get the current tokenizer path
    public func getTokenizerPath() -> String {
        return modelType.defaultTokenizerPath
    }
} 
