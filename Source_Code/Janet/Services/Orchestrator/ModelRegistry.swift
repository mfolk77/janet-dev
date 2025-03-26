//
//  ModelRegistry.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os
import Combine

/// Registry for managing available models and their capabilities
public class ModelRegistry {
    // MARK: - Private Properties
    
    /// Logger for the registry
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "ModelRegistry")
    
    /// Dictionary of registered models
    private var registeredModels: [JanetModelType: RegisteredModel] = [:]
    
    /// Set of cancellables for Combine
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Initialization
    
    /// Initialize a new model registry
    public init() {
        logger.info("Initializing ModelRegistry")
        
        // Register default models
        registerDefaultModels()
        
        // Set up observers
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Register a model with the registry
    /// - Parameter model: The model to register
    public func registerModel(_ model: RegisteredModel) {
        logger.info("Registering model: \(model.modelType.rawValue)")
        registeredModels[model.modelType] = model
    }
    
    /// Unregister a model from the registry
    /// - Parameter modelType: The type of model to unregister
    public func unregisterModel(_ modelType: JanetModelType) {
        logger.info("Unregistering model: \(modelType.rawValue)")
        registeredModels.removeValue(forKey: modelType)
    }
    
    /// Check if a model is registered
    /// - Parameter modelType: The type of model to check
    /// - Returns: Whether the model is registered
    public func isModelRegistered(_ modelType: JanetModelType) -> Bool {
        return registeredModels[modelType] != nil
    }
    
    /// Get a registered model by type
    /// - Parameter modelType: The type of model to get
    /// - Returns: The registered model, or nil if not found
    public func getRegisteredModel(_ modelType: JanetModelType) -> RegisteredModel? {
        return registeredModels[modelType]
    }
    
    /// Get the capabilities of a model
    /// - Parameter modelType: The type of model
    /// - Returns: The capabilities of the model, or nil if not found
    public func getModelCapabilities(_ modelType: JanetModelType) -> ModelCapabilities? {
        return registeredModels[modelType]?.capabilities
    }
    
    /// Get all registered models
    /// - Returns: Array of all registered models
    public func getAllRegisteredModels() -> [RegisteredModel] {
        return Array(registeredModels.values).sorted { $0.priority < $1.priority }
    }
    
    /// Get all registered models that support a specific task
    /// - Parameter taskType: The type of task
    /// - Returns: Array of models that support the task
    public func getModelsForTask(_ taskType: TaskType) -> [RegisteredModel] {
        return getAllRegisteredModels().filter { model in
            model.capabilities.supportedTasks.contains(taskType)
        }
    }
    
    /// Update the load state of a model
    /// - Parameters:
    ///   - modelType: The type of model
    ///   - isLoaded: Whether the model is loaded
    public func updateModelLoadState(modelType: JanetModelType, isLoaded: Bool) {
        logger.info("Updating load state for model \(modelType.rawValue): \(isLoaded)")
        
        if var model = registeredModels[modelType] {
            model.isLoaded = isLoaded
            registeredModels[modelType] = model
        }
    }
    
    /// Get all loaded models
    /// - Returns: Array of all loaded models
    public func getLoadedModels() -> [RegisteredModel] {
        return getAllRegisteredModels().filter { $0.isLoaded }
    }
    
    /// Get all models that support a specific task and are loaded
    /// - Parameter taskType: The type of task
    /// - Returns: Array of loaded models that support the task
    public func getLoadedModelsForTask(_ taskType: TaskType) -> [RegisteredModel] {
        return getModelsForTask(taskType).filter { $0.isLoaded }
    }
    
    /// Register a model
    /// - Parameter model: The model to register
    public func registerModel(_ model: ModelInfo) {
        logger.info("Registering model: \(model.id)")
        
        // Convert ModelInfo to RegisteredModel
        guard let modelType = JanetModelType(rawValue: "custom_\(model.id)") else { logger.error("Failed to create model type for \(model.id)"); return }
        
        // Convert capabilities
        let capabilities = ModelCapabilities(
            supportedTasks: convertCapabilitiesToTasks(model.capabilities),
            reasoningAbility: .medium,
            contextWindow: model.contextWindow,
            isLocalOnly: model.provider == .local
        )
        
        let registeredModel = RegisteredModel(
            modelType: modelType,
            capabilities: capabilities,
            priority: 100
        )
        
        // Check if the model is already registered
        if registeredModels[modelType] != nil {
            logger.warning("Model already registered: \(model.id)")
            return
        }
        
        // Register the model
        registeredModels[modelType] = registeredModel
        
        // Notify observers
        NotificationCenter.default.post(
            name: NSNotification.Name("modelRegistered"),
            object: nil,
            userInfo: ["modelId": model.id]
        )
    }
    
    // MARK: - Private Methods
    
    /// Register default models
    private func registerDefaultModels() {
        logger.info("Registering default models")
        
        // Register local models
        registerLocalModels()
        
        // Register cloud models
        registerCloudModels()
        
        // Register DeepSeek Coder model
        registerDeepSeekCoderModel()
    }
    
    /// Register DeepSeek Coder model
    private func registerDeepSeekCoderModel() {
        logger.info("Registering DeepSeek Coder model")
        
        // Default values in case the manager isn't fully initialized
        let isAvailable = CodeAssistantManager.shared.isModelAvailable
        let modelVersion = CodeAssistantManager.shared.modelVersion.isEmpty ? "unknown" : CodeAssistantManager.shared.modelVersion
        
        let deepSeekCoder = ModelInfo(
            id: "deepseek-coder",
            name: "DeepSeek Coder",
            provider: .ollama,
            type: .code,
            capabilities: [.codeGeneration, .codeCompletion, .codeExplanation],
            contextWindow: 16384,
            maxTokens: 4096,
            temperature: 0.2,
            costPerToken: 0.0,
            isAvailable: isAvailable,
            metadata: [
                "version": modelVersion,
                "repository": "https://github.com/deepseek-ai/DeepSeek-Coder",
                "license": "Apache 2.0"
            ]
        )
        
        registerModel(deepSeekCoder)
        
        // Observe model availability changes
        CodeAssistantManager.shared.$isModelAvailable
            .dropFirst()
            .sink { [weak self] isAvailable in
                self?.updateModelAvailability("deepseek-coder", isAvailable: isAvailable)
            }
            .store(in: &cancellables)
        
        // Observe model version changes
        CodeAssistantManager.shared.$modelVersion
            .dropFirst()
            .sink { [weak self] version in
                if !version.isEmpty {
                    self?.updateModelMetadata("deepseek-coder", key: "version", value: version)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Update model availability
    /// - Parameters:
    ///   - modelId: The model ID
    ///   - isAvailable: Whether the model is available
    private func updateModelAvailability(_ modelId: String, isAvailable: Bool) {
        logger.info("Updating model availability: \(modelId) -> \(isAvailable)")
        
        // Find the model
        guard let modelType = JanetModelType(rawValue: "custom_\(modelId)") else { logger.warning("Model not found: \(modelId)"); return }
        guard var model = registeredModels[modelType] else {
            logger.warning("Model not found: \(modelId)")
            return
        }
        
        // Update availability
        model.isLoaded = isAvailable
        registeredModels[modelType] = model
        
        // Notify observers
        NotificationCenter.default.post(
            name: NSNotification.Name("modelAvailabilityChanged"),
            object: nil,
            userInfo: ["modelId": modelId, "isAvailable": isAvailable]
        )
    }
    
    /// Update model metadata
    /// - Parameters:
    ///   - modelId: The model ID
    ///   - key: The metadata key
    ///   - value: The metadata value
    private func updateModelMetadata(_ modelId: String, key: String, value: Any) {
        let logMessage = "Updating model metadata: \(modelId) -> \(key): \(value)"
        logger.info("\(logMessage)")
        
        // Find the model
        guard let modelType = JanetModelType(rawValue: "custom_\(modelId)") else { logger.warning("Model not found: \(modelId)"); return }
        guard registeredModels[modelType] != nil else {
            logger.warning("Model not found: \(modelId)")
            return
        }
        
        // For now, we don't have a metadata dictionary in RegisteredModel
        // This would need to be added to the RegisteredModel struct
        
        // Notify observers
        NotificationCenter.default.post(
            name: NSNotification.Name("modelMetadataChanged"),
            object: nil,
            userInfo: ["modelId": modelId, "key": key, "value": value]
        )
    }
    
    /// Set up observers
    private func setupObservers() {
        // Implementation of setupObservers method
    }
    
    /// Register local models
    private func registerLocalModels() {
        logger.info("Registering local models")
        
        // Register Ollama model
        let ollamaModel = RegisteredModel(
            modelType: .ollama,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .code, .summarization, .reasoning],
                reasoningAbility: .medium,
                contextWindow: 8192,
                isLocalOnly: true
            ),
            priority: 1,
            isLoaded: true,
            customName: "Ollama"
        )
        
        registerModel(ollamaModel)
        
        // Register Phi model
        let phiModel = RegisteredModel(
            modelType: .phi,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .code, .summarization],
                reasoningAbility: .medium,
                contextWindow: 4096,
                isLocalOnly: true
            ),
            priority: 2,
            isLoaded: false,
            customName: "Phi"
        )
        
        registerModel(phiModel)
        
        // Register Llama model
        let llamaModel = RegisteredModel(
            modelType: .llama,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .summarization, .reasoning],
                reasoningAbility: .high,
                contextWindow: 8192,
                isLocalOnly: true
            ),
            priority: 3,
            isLoaded: false,
            customName: "Llama"
        )
        
        registerModel(llamaModel)
        
        // Register Mistral model
        let mistralModel = RegisteredModel(
            modelType: .mistral,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .summarization, .reasoning],
                reasoningAbility: .high,
                contextWindow: 8192,
                isLocalOnly: true
            ),
            priority: 4,
            isLoaded: false,
            customName: "Mistral"
        )
        
        registerModel(mistralModel)
        
        // Register DeepSeek Coder model
        let deepSeekCoderModel = RegisteredModel(
            modelType: .deepseekCoder,
            capabilities: ModelCapabilities(
                supportedTasks: [.code, .reasoning],
                reasoningAbility: .high,
                contextWindow: 16384,
                isLocalOnly: true
            ),
            priority: 5,
            isLoaded: CodeAssistantManager.shared.isModelAvailable,
            customName: "DeepSeek Coder"
        )
        
        registerModel(deepSeekCoderModel)
        
        // Set up observers for DeepSeek Coder
        CodeAssistantManager.shared.$isModelAvailable
            .dropFirst()
            .sink { [weak self] isAvailable in
                self?.updateModelLoadState(modelType: .deepseekCoder, isLoaded: isAvailable)
            }
            .store(in: &cancellables)
    }
    
    /// Register cloud models
    private func registerCloudModels() {
        logger.info("Registering cloud models")
        
        // Register OpenAI GPT-4 model
        let gpt4Model = RegisteredModel(
            modelType: JanetModelType.custom("gpt4") ?? .gpt4,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .code, .summarization, .reasoning],
                reasoningAbility: .high,
                contextWindow: 8192,
                isLocalOnly: false
            ),
            priority: 90,
            isLoaded: true,
            customName: "GPT-4"
        )
        
        registerModel(gpt4Model)
        
        // Register Claude model
        let claudeModel = RegisteredModel(
            modelType: JanetModelType.custom("claude") ?? .claude,
            capabilities: ModelCapabilities(
                supportedTasks: [.general, .chat, .code, .summarization, .reasoning],
                reasoningAbility: .high,
                contextWindow: 8192,
                isLocalOnly: false
            ),
            priority: 85,
            isLoaded: true,
            customName: "Claude"
        )
        
        registerModel(claudeModel)
    }
    
    private func convertCapabilitiesToTasks(_ capabilities: [ModelCapability]) -> [TaskType] {
        var tasks: [TaskType] = []
        
        for capability in capabilities {
            switch capability {
            case .textGeneration:
                tasks.append(.general)
            case .chat:
                tasks.append(.chat)
            case .codeGeneration, .codeCompletion, .codeExplanation:
                tasks.append(.code)
            case .summarization:
                tasks.append(.summarization)
            case .translation:
                tasks.append(.general)
            case .questionAnswering:
                tasks.append(.general)
            case .classification:
                tasks.append(.general)
            case .functionCalling:
                tasks.append(.general)
            case .toolUse:
                tasks.append(.general)
            case .imageGeneration:
                tasks.append(.general)
            case .imageCaptioning:
                tasks.append(.general)
            case .audioTranscription:
                tasks.append(.general)
            case .audioGeneration:
                tasks.append(.general)
            case .embeddings:
                tasks.append(.general)
            case .reasoning:
                tasks.append(.reasoning)
            case .planning:
                tasks.append(.general)
            case .memory:
                tasks.append(.general)
            case .financialAnalysis:
                tasks.append(.general)
            case .businessIntelligence:
                tasks.append(.general)
            case .healthcare:
                tasks.append(.general)
            case .legal:
                tasks.append(.general)
            case .scientificResearch:
                tasks.append(.general)
            case .education:
                tasks.append(.general)
            case .creativeWriting:
                tasks.append(.general)
            case .contentModeration:
                tasks.append(.general)
            case .personalization:
                tasks.append(.general)
            case .multimodal:
                tasks.append(.general)
            }
        }
        
        return tasks
    }
}

// MARK: - Model Type

/// Types of models that can be used
public enum RegistryModelType: String, Codable, CaseIterable {
    /// Ollama model
    case ollama = "ollama"
    
    /// Phi model
    case phi = "phi"
    
    /// Llama model
    case llama = "llama"
    
    /// Mistral model
    case mistral = "mistral"
    
    /// FinGPT model
    case finGPT = "finGPT"
    
    /// DeepSeek Coder model
    case deepseekCoder = "deepseek-coder"
    
    /// Custom model
    case custom = "custom"
}

// MARK: - Registered Model

/// A model registered with the orchestrator
public struct RegisteredModel: Identifiable, Equatable, Sendable {
    /// Unique identifier for the model
    public var id: String { modelType.rawValue }
    
    /// The type of model
    public let modelType: JanetModelType
    
    /// The capabilities of the model
    public let capabilities: ModelCapabilities
    
    /// Priority of the model (lower is higher priority)
    public let priority: Int
    
    /// Whether the model is currently loaded
    public var isLoaded: Bool = false
    
    /// Custom name for the model (optional)
    public var customName: String?
    
    /// Initialize a new registered model
    /// - Parameters:
    ///   - modelType: The type of model
    ///   - capabilities: The capabilities of the model
    ///   - priority: Priority of the model (lower is higher priority)
    ///   - isLoaded: Whether the model is currently loaded
    ///   - customName: Custom name for the model (optional)
    public init(
        modelType: JanetModelType,
        capabilities: ModelCapabilities,
        priority: Int,
        isLoaded: Bool = false,
        customName: String? = nil
    ) {
        self.modelType = modelType
        self.capabilities = capabilities
        self.priority = priority
        self.isLoaded = isLoaded
        self.customName = customName
    }
    
    /// Get the display name for the model
    public var displayName: String {
        return customName ?? modelType.rawValue.capitalized
    }
    
    /// Equatable implementation
    public static func == (lhs: RegisteredModel, rhs: RegisteredModel) -> Bool {
        return lhs.modelType == rhs.modelType
    }
}

// MARK: - Model Capabilities

/// Capabilities of a model
public struct ModelCapabilities: Codable, Sendable {
    /// Tasks that the model supports
    public let supportedTasks: [TaskType]
    
    /// Reasoning ability of the model
    public let reasoningAbility: ReasoningAbility
    
    /// Context window size in tokens
    public let contextWindow: Int
    
    /// Whether the model can only be used locally
    public let isLocalOnly: Bool
    
    /// Initialize new model capabilities
    /// - Parameters:
    ///   - supportedTasks: Tasks that the model supports
    ///   - reasoningAbility: Reasoning ability of the model
    ///   - contextWindow: Context window size in tokens
    ///   - isLocalOnly: Whether the model can only be used locally
    public init(
        supportedTasks: [TaskType],
        reasoningAbility: ReasoningAbility,
        contextWindow: Int,
        isLocalOnly: Bool
    ) {
        self.supportedTasks = supportedTasks
        self.reasoningAbility = reasoningAbility
        self.contextWindow = contextWindow
        self.isLocalOnly = isLocalOnly
    }
}

// MARK: - Task Type

/// Types of tasks that can be performed
public enum TaskType: String, Codable, CaseIterable, Sendable {
    /// General purpose task
    case general = "general"
    
    /// Chat conversation
    case chat = "chat"
    
    /// Code generation
    case code = "code"
    
    /// Summarization
    case summarization = "summarization"
    
    /// Reasoning
    case reasoning = "reasoning"
    
    /// Financial analysis
    case financial = "financial"
    
    /// Healthcare
    case healthcare = "healthcare"
    
    /// Business intelligence
    case business = "business"
    
    /// System command execution
    case systemCommand = "system_command"
    
    /// File system operations
    case fileSystem = "file_system"
}

// MARK: - Reasoning Ability

/// Level of reasoning ability
public enum ReasoningAbility: String, Codable, CaseIterable, Sendable {
    /// Low reasoning ability
    case low = "low"
    
    /// Medium reasoning ability
    case medium = "medium"
    
    /// High reasoning ability
    case high = "high"
} 