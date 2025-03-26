//
//  ModelInfo.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation

/// Information about a model
public struct ModelInfo: Identifiable {
    /// Unique identifier
    public let id: String
    
    /// Display name
    public let name: String
    
    /// Model provider
    public let provider: ModelProvider
    
    /// Model type
    public let type: JanetModelType
    
    /// Model capabilities
    public let capabilities: [ModelCapability]
    
    /// Context window size in tokens
    public let contextWindow: Int
    
    /// Maximum tokens to generate
    public let maxTokens: Int
    
    /// Default temperature
    public let temperature: Double
    
    /// Cost per token in USD
    public let costPerToken: Double
    
    /// Whether the model is available
    public var isAvailable: Bool
    
    /// Additional metadata
    public var metadata: [String: Any]
    
    /// Initialize a new model info
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - name: Display name
    ///   - provider: Model provider
    ///   - type: Model type
    ///   - capabilities: Model capabilities
    ///   - contextWindow: Context window size in tokens
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Default temperature
    ///   - costPerToken: Cost per token in USD
    ///   - isAvailable: Whether the model is available
    ///   - metadata: Additional metadata
    public init(
        id: String,
        name: String,
        provider: ModelProvider,
        type: JanetModelType,
        capabilities: [ModelCapability],
        contextWindow: Int,
        maxTokens: Int,
        temperature: Double,
        costPerToken: Double,
        isAvailable: Bool,
        metadata: [String: Any] = [:]
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.type = type
        self.capabilities = capabilities
        self.contextWindow = contextWindow
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.costPerToken = costPerToken
        self.isAvailable = isAvailable
        self.metadata = metadata
    }
}

/// Model provider
public enum ModelProvider: String, Codable, CaseIterable {
    /// OpenAI
    case openai = "openai"
    
    /// Anthropic
    case anthropic = "anthropic"
    
    /// Ollama
    case ollama = "ollama"
    
    /// Hugging Face
    case huggingFace = "huggingface"
    
    /// Local
    case local = "local"
    
    /// Custom
    case custom = "custom"
}

/// Model capability
public enum ModelCapability: String, Codable, CaseIterable {
    /// Text generation
    case textGeneration = "text_generation"
    
    /// Chat
    case chat = "chat"
    
    /// Code generation
    case codeGeneration = "code_generation"
    
    /// Code completion
    case codeCompletion = "code_completion"
    
    /// Code explanation
    case codeExplanation = "code_explanation"
    
    /// Summarization
    case summarization = "summarization"
    
    /// Translation
    case translation = "translation"
    
    /// Question answering
    case questionAnswering = "question_answering"
    
    /// Classification
    case classification = "classification"
    
    /// Image generation
    case imageGeneration = "image_generation"
    
    /// Image captioning
    case imageCaptioning = "image_captioning"
    
    /// Audio transcription
    case audioTranscription = "audio_transcription"
    
    /// Audio generation
    case audioGeneration = "audio_generation"
    
    /// Embeddings
    case embeddings = "embeddings"
    
    /// Function calling
    case functionCalling = "function_calling"
    
    /// Tool use
    case toolUse = "tool_use"
    
    /// Reasoning
    case reasoning = "reasoning"
    
    /// Planning
    case planning = "planning"
    
    /// Memory
    case memory = "memory"
    
    /// Financial analysis
    case financialAnalysis = "financial_analysis"
    
    /// Business intelligence
    case businessIntelligence = "business_intelligence"
    
    /// Healthcare
    case healthcare = "healthcare"
    
    /// Legal
    case legal = "legal"
    
    /// Scientific research
    case scientificResearch = "scientific_research"
    
    /// Education
    case education = "education"
    
    /// Creative writing
    case creativeWriting = "creative_writing"
    
    /// Content moderation
    case contentModeration = "content_moderation"
    
    /// Personalization
    case personalization = "personalization"
    
    /// Multimodal
    case multimodal = "multimodal"
}