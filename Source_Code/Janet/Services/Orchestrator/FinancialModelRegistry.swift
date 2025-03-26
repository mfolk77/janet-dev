//
//  FinancialModelRegistry.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os

/// Registry for financial models
public class FinancialModelRegistry: ObservableObject {
    // MARK: - Published Properties
    
    /// Registered financial models
    @Published public private(set) var financialModels: [FinancialModel] = []
    
    // MARK: - Private Properties
    
    /// Logger for the financial model registry
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "FinancialModelRegistry")
    
    /// Queue for thread safety
    private let queue = DispatchQueue(label: "com.janet.ai.financialModelRegistry", qos: .userInitiated)
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = FinancialModelRegistry()
    
    // MARK: - Initialization
    
    /// Initialize a new financial model registry
    private init() {
        logger.info("Initializing FinancialModelRegistry")
        
        // Register default financial models
        registerDefaultModels()
    }
    
    // MARK: - Public Methods
    
    /// Register a financial model
    /// - Parameter model: The model to register
    public func registerModel(_ model: FinancialModel) {
        logger.info("Registering financial model: \(model.name)")
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Check if the model is already registered
            if self.financialModels.contains(where: { $0.id == model.id }) {
                self.logger.warning("Financial model \(model.name) is already registered")
                return
            }
            
            // Add the model
            Task { @MainActor in
                self.financialModels.append(model)
            }
            
            // Register with the main model registry
            let modelType = JanetModelType(rawValue: "custom_\(model.id)")!
            
            // Create default capabilities for financial models
            let capabilities = ModelCapabilities(
                supportedTasks: [.general, .reasoning],
                reasoningAbility: .high,
                contextWindow: 4096,
                isLocalOnly: false
            )
            
            // Create a RegisteredModel instance
            _ = RegisteredModel(
                modelType: modelType,
                capabilities: capabilities,
                priority: 50,  // Medium priority
                isLoaded: true,
                customName: model.name
            )
            
            // Note: ModelRegistry doesn't have a shared instance, this needs to be handled differently
            // ModelRegistry.shared?.registerModel(registeredModel)
            
            self.logger.info("Financial model \(model.name) registered successfully")
        }
        
        queue.async(execute: workItem)
    }
    
    /// Unregister a financial model
    /// - Parameter modelId: The ID of the model to unregister
    public func unregisterModel(modelId: String) {
        logger.info("Unregistering financial model with ID: \(modelId)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if the model is registered
            guard let index = self.financialModels.firstIndex(where: { $0.id == modelId }) else {
                self.logger.warning("Financial model with ID \(modelId) is not registered")
                return
            }
            
            // Remove the model
            Task { @MainActor in
                self.financialModels.remove(at: index)
            }
            
            // Unregister from the main model registry
            // if let modelType = JanetModelType.custom(modelId) {
            //     ModelRegistry.shared?.unregisterModel(type: modelType)
            // }
            // Note: ModelRegistry doesn't have a shared instance, this needs to be handled differently
            
            self.logger.info("Financial model with ID \(modelId) unregistered successfully")
        }
    }
    
    /// Get a financial model by ID
    /// - Parameter modelId: The ID of the model
    /// - Returns: The model, if found
    public func getModel(modelId: String) -> FinancialModel? {
        return queue.sync {
            return financialModels.first { $0.id == modelId }
        }
    }
    
    /// Get all registered financial models
    /// - Returns: All registered financial models
    public func getAllModels() -> [FinancialModel] {
        return queue.sync {
            return financialModels
        }
    }
    
    /// Get financial models suitable for a specific task
    /// - Parameter task: The financial task
    /// - Returns: Models suitable for the task
    public func getModelsForTask(task: FinancialTask) -> [FinancialModel] {
        return queue.sync {
            return financialModels.filter { $0.supportedTasks.contains(task) }
        }
    }
    
    // MARK: - Private Methods
    
    /// Register default financial models
    private func registerDefaultModels() {
        logger.info("Registering default financial models")
        
        // FinGPT model
        let finGPT = FinancialModel(
            id: "fingpt-v3",
            name: "FinGPT-v3",
            description: "Specialized model for financial analysis and forecasting",
            version: "3.0",
            provider: "FinGPT",
            contextWindow: 8192,
            supportedTasks: [.marketAnalysis, .stockPrediction, .financialReporting, .sentimentAnalysis],
            dataSourcesSupported: [.marketData, .financialStatements, .newsArticles],
            isCloudBased: true,
            apiEndpoint: "https://api.fingpt.ai/v1/completions",
            priority: 1
        )
        
        // BloombergGPT model
        let bloombergGPT = FinancialModel(
            id: "bloomberggpt",
            name: "BloombergGPT",
            description: "Financial model trained on Bloomberg's extensive market data",
            version: "1.0",
            provider: "Bloomberg",
            contextWindow: 16384,
            supportedTasks: [.marketAnalysis, .stockPrediction, .financialReporting, .sentimentAnalysis, .riskAssessment],
            dataSourcesSupported: [.marketData, .financialStatements, .newsArticles, .economicIndicators],
            isCloudBased: true,
            apiEndpoint: "https://api.bloomberg.ai/v1/completions",
            priority: 2
        )
        
        // Local financial model
        let localFinancialModel = FinancialModel(
            id: "local-finance-model",
            name: "Local Finance Model",
            description: "Lightweight financial model for local execution",
            version: "1.0",
            provider: "Janet",
            contextWindow: 4096,
            supportedTasks: [.financialReporting, .sentimentAnalysis],
            dataSourcesSupported: [.financialStatements, .newsArticles],
            isCloudBased: false,
            apiEndpoint: nil,
            priority: 3
        )
        
        // Register the models
        registerModel(finGPT)
        registerModel(bloombergGPT)
        registerModel(localFinancialModel)
    }
}

// MARK: - Financial Model

/// A model specialized for financial tasks
public struct FinancialModel: Identifiable, Codable {
    /// Unique identifier for the model
    public let id: String
    
    /// Name of the model
    public let name: String
    
    /// Description of the model
    public let description: String
    
    /// Version of the model
    public let version: String
    
    /// Provider of the model
    public let provider: String
    
    /// Context window size in tokens
    public let contextWindow: Int
    
    /// Financial tasks supported by the model
    public let supportedTasks: [FinancialTask]
    
    /// Data sources supported by the model
    public let dataSourcesSupported: [FinancialDataSource]
    
    /// Whether the model is cloud-based
    public let isCloudBased: Bool
    
    /// API endpoint for cloud-based models
    public let apiEndpoint: String?
    
    /// Priority of the model (lower is higher priority)
    public let priority: Int
    
    /// Initialize a new financial model
    /// - Parameters:
    ///   - id: Unique identifier for the model
    ///   - name: Name of the model
    ///   - description: Description of the model
    ///   - version: Version of the model
    ///   - provider: Provider of the model
    ///   - contextWindow: Context window size in tokens
    ///   - supportedTasks: Financial tasks supported by the model
    ///   - dataSourcesSupported: Data sources supported by the model
    ///   - isCloudBased: Whether the model is cloud-based
    ///   - apiEndpoint: API endpoint for cloud-based models
    ///   - priority: Priority of the model (lower is higher priority)
    public init(
        id: String,
        name: String,
        description: String,
        version: String,
        provider: String,
        contextWindow: Int,
        supportedTasks: [FinancialTask],
        dataSourcesSupported: [FinancialDataSource],
        isCloudBased: Bool,
        apiEndpoint: String?,
        priority: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.provider = provider
        self.contextWindow = contextWindow
        self.supportedTasks = supportedTasks
        self.dataSourcesSupported = dataSourcesSupported
        self.isCloudBased = isCloudBased
        self.apiEndpoint = apiEndpoint
        self.priority = priority
    }
}

// MARK: - Financial Task

/// Types of financial tasks
public enum FinancialTask: String, CaseIterable, Codable {
    /// Market analysis
    case marketAnalysis = "Market Analysis"
    
    /// Stock prediction
    case stockPrediction = "Stock Prediction"
    
    /// Financial reporting
    case financialReporting = "Financial Reporting"
    
    /// Sentiment analysis
    case sentimentAnalysis = "Sentiment Analysis"
    
    /// Risk assessment
    case riskAssessment = "Risk Assessment"
}

// MARK: - Financial Data Source

/// Types of financial data sources
public enum FinancialDataSource: String, CaseIterable, Codable {
    /// Market data
    case marketData = "Market Data"
    
    /// Financial statements
    case financialStatements = "Financial Statements"
    
    /// News articles
    case newsArticles = "News Articles"
    
    /// Economic indicators
    case economicIndicators = "Economic Indicators"
}

// MARK: - Financial Model Executor

/// Executor for financial models
public class FinancialModelExecutor {
    // MARK: - Private Properties
    
    /// Logger for the financial model executor
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "FinancialModelExecutor")
    
    /// Cloud executor for cloud-based models
    private let cloudExecutor = CloudModelExecutor()
    
    // MARK: - Initialization
    
    /// Initialize a new financial model executor
    public init() {
        logger.info("Initializing FinancialModelExecutor")
    }
    
    // MARK: - Public Methods
    
    /// Execute a financial model
    /// - Parameters:
    ///   - context: The request context
    ///   - modelId: The ID of the financial model
    ///   - financialContext: Additional financial context
    /// - Returns: The generated text
    public func executeFinancialModel(
        context: RequestContext,
        modelId: String,
        financialContext: FinancialContext? = nil
    ) async throws -> String {
        logger.info("Executing financial model: \(modelId)")
        
        // Get the financial model
        guard let model = FinancialModelRegistry.shared.getModel(modelId: modelId) else {
            logger.error("Financial model with ID \(modelId) not found")
            throw FinancialModelError.modelNotFound
        }
        
        // Create a prompt with financial context
        let enhancedPrompt = createFinancialPrompt(
            originalPrompt: context.prompt,
            financialContext: financialContext
        )
        
        // Create a new context with the enhanced prompt
        let enhancedContext = RequestContext(
            prompt: enhancedPrompt,
            taskType: .financial,
            maxTokens: context.maxTokens,
            temperature: context.temperature,
            topP: context.topP,
            repetitionPenalty: context.repetitionPenalty
        )
        
        // Execute based on whether the model is cloud-based
        if model.isCloudBased {
            // Execute cloud-based model
            guard model.apiEndpoint != nil else {
                logger.error("Cloud-based financial model \(modelId) has no API endpoint")
                throw FinancialModelError.missingAPIEndpoint
            }
            
            // Determine the cloud provider based on the model provider
            let provider: CloudProvider
            switch model.provider.lowercased() {
            case "fingpt":
                provider = .custom
            case "bloomberg":
                provider = .custom
            default:
                provider = .custom
            }
            
            return try await cloudExecutor.executeCloudModel(
                context: enhancedContext,
                modelId: model.id,
                provider: provider
            )
        } else {
            // Execute local model
            // Get the model from the model manager
            guard let modelType = JanetModelType.custom(model.id),
                  let modelInstance = ModelManager.shared.getModel(type: modelType) else {
                logger.error("Local financial model \(modelId) not loaded or invalid")
                throw FinancialModelError.modelNotLoaded
            }
            
            // Generate text
            return try await modelInstance.generateText(
                prompt: enhancedPrompt,
                maxTokens: enhancedContext.maxTokens,
                temperature: enhancedContext.temperature,
                topP: enhancedContext.topP,
                repetitionPenalty: enhancedContext.repetitionPenalty
            )
        }
    }
    
    // MARK: - Private Methods
    
    /// Create a prompt with financial context
    /// - Parameters:
    ///   - originalPrompt: The original prompt
    ///   - financialContext: Additional financial context
    /// - Returns: An enhanced prompt with financial context
    private func createFinancialPrompt(
        originalPrompt: String,
        financialContext: FinancialContext?
    ) -> String {
        var enhancedPrompt = originalPrompt
        
        // Add financial context if provided
        if let financialContext = financialContext {
            enhancedPrompt = """
            Financial Context:
            
            """
            
            // Add market data if available
            if let marketData = financialContext.marketData {
                enhancedPrompt += """
                Market Data:
                \(marketData)
                
                """
            }
            
            // Add financial statements if available
            if let financialStatements = financialContext.financialStatements {
                enhancedPrompt += """
                Financial Statements:
                \(financialStatements)
                
                """
            }
            
            // Add news articles if available
            if let newsArticles = financialContext.newsArticles {
                enhancedPrompt += """
                News Articles:
                \(newsArticles)
                
                """
            }
            
            // Add economic indicators if available
            if let economicIndicators = financialContext.economicIndicators {
                enhancedPrompt += """
                Economic Indicators:
                \(economicIndicators)
                
                """
            }
            
            enhancedPrompt += """
            
            Based on the above financial context, please respond to the following:
            
            \(originalPrompt)
            """
        }
        
        return enhancedPrompt
    }
}

// MARK: - Financial Context

/// Context for financial tasks
public struct FinancialContext {
    /// Market data
    public let marketData: String?
    
    /// Financial statements
    public let financialStatements: String?
    
    /// News articles
    public let newsArticles: String?
    
    /// Economic indicators
    public let economicIndicators: String?
    
    /// Initialize a new financial context
    /// - Parameters:
    ///   - marketData: Market data
    ///   - financialStatements: Financial statements
    ///   - newsArticles: News articles
    ///   - economicIndicators: Economic indicators
    public init(
        marketData: String? = nil,
        financialStatements: String? = nil,
        newsArticles: String? = nil,
        economicIndicators: String? = nil
    ) {
        self.marketData = marketData
        self.financialStatements = financialStatements
        self.newsArticles = newsArticles
        self.economicIndicators = economicIndicators
    }
}

// MARK: - Financial Model Error

/// Errors that can occur in financial models
public enum FinancialModelError: Error {
    /// The model was not found
    case modelNotFound
    
    /// The model is not loaded
    case modelNotLoaded
    
    /// The cloud-based model has no API endpoint
    case missingAPIEndpoint
} 