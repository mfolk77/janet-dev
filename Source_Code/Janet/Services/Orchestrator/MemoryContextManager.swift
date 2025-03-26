//
//  MemoryContextManager.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os
import Combine

/// Manages memory context for models
public class MemoryContextManager: ObservableObject, @unchecked Sendable {
    // MARK: - Published Properties
    
    /// Recent interactions with models
    @Published public private(set) var recentInteractions: [ModelInteraction] = []
    
    /// Whether vector memory is enabled
    @Published public var useVectorMemory: Bool = true
    
    /// Whether external knowledge sources are enabled
    @Published public var useExternalSources: Bool = true
    
    // MARK: - Private Properties
    
    /// Logger for the memory context manager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "MemoryContextManager")
    
    /// Maximum number of interactions to store
    private let maxInteractions = 100
    
    /// Queue for thread safety
    private let queue = DispatchQueue(label: "com.janet.ai.memoryContextManager", qos: .userInitiated)
    
    /// Model-specific context storage
    private var modelContexts: [JanetModelType: [ModelInteraction]] = [:]
    
    /// SQLite memory service for vector storage
    private let sqliteMemory: SQLiteMemoryService
    
    /// Enhanced memory manager for integration with other memory systems
    private let enhancedMemory: EnhancedMemoryManager?
    
    /// Notion memory service for external knowledge
    private let notionMemory: NotionMemory?
    
    // MARK: - Initialization
    
    /// Initialize a new memory context manager
    public init() {
        logger.info("Initializing MemoryContextManager")
        
        // Initialize model contexts for all model types
        for modelType in JanetModelType.allCases {
            modelContexts[modelType] = []
        }
        
        // Initialize memory services
        self.sqliteMemory = SQLiteMemoryService.shared
        
        // Try to get references to other memory services if available
        self.enhancedMemory = (NSClassFromString("EnhancedMemoryManager") != nil) ? EnhancedMemoryManager.shared : nil
        self.notionMemory = (NSClassFromString("NotionMemory") != nil) ? NotionMemory.shared : nil
        
        logger.info("Memory services initialized - Vector: \(self.sqliteMemory.isInitialized), Enhanced: \(self.enhancedMemory != nil), Notion: \(self.notionMemory != nil)")
    }
    
    // MARK: - Public Methods
    
    /// Store a result from model execution
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - result: The generated result
    ///   - models: The models used
    public func storeResult(prompt: String, result: String, models: [RegisteredModel]) async {
        logger.info("Storing result from \(models.count) models")
        
        // Create a new interaction
        let interaction = ModelInteraction(
            prompt: prompt,
            response: result,
            models: models.map { $0.modelType },
            timestamp: Date()
        )
        
        // Store the interaction
        await MainActor.run {
            // Add to recent interactions
            recentInteractions.insert(interaction, at: 0)
            
            // Trim if needed
            if recentInteractions.count > maxInteractions {
                recentInteractions = Array(recentInteractions.prefix(maxInteractions))
            }
        }
        
        // Store in model-specific contexts
        queue.async { [weak self] in
            guard let self = self else { return }
            
            for model in models {
                self.modelContexts[model.modelType]?.insert(interaction, at: 0)
                
                // Trim if needed
                if let contextCount = self.modelContexts[model.modelType]?.count, contextCount > self.maxInteractions {
                    self.modelContexts[model.modelType] = Array(self.modelContexts[model.modelType]?.prefix(self.maxInteractions) ?? [])
                }
            }
        }
        
        // Store in vector memory if enabled
        if useVectorMemory {
            await storeInVectorMemory(prompt: prompt, result: result)
        }
        
        // Save to disk
        Task {
            try? await saveInteractions()
        }
    }
    
    /// Get the context for a specific model
    /// - Parameter modelType: The model type
    /// - Returns: The model's context
    public func getModelContext(modelType: JanetModelType) -> [ModelInteraction] {
        return queue.sync {
            return modelContexts[modelType] ?? []
        }
    }
    
    /// Get recent interactions for all models
    /// - Returns: Recent interactions for all models
    public func getAllContexts() -> [ModelInteraction] {
        return recentInteractions
    }
    
    /// Clear the context for a specific model
    /// - Parameter modelType: The model type
    public func clearModelContext(modelType: JanetModelType) {
        logger.info("Clearing context for model: \(modelType.rawValue)")
        
        queue.async { [weak self] in
            self?.modelContexts[modelType] = []
        }
    }
    
    /// Clear all contexts
    public func clearAllContexts() {
        logger.info("Clearing all contexts")
        
        // Clear recent interactions
        Task { @MainActor in
            recentInteractions = []
        }
        
        // Clear model-specific contexts
        queue.async { [weak self] in
            guard let self = self else { return }
            
            for modelType in JanetModelType.allCases {
                self.modelContexts[modelType] = []
            }
        }
        
        // Clear vector memory if enabled
        if useVectorMemory {
            sqliteMemory.clearAllMemories()
        }
    }
    
    /// Generate a context-aware prompt for a model
    /// - Parameters:
    ///   - prompt: The original prompt
    ///   - modelType: The type of model
    ///   - maxContextItems: Maximum number of context items to include
    /// - Returns: A context-aware prompt
    public func generateContextAwarePrompt(
        prompt: String,
        modelType: JanetModelType,
        maxContextItems: Int = 5
    ) async -> String {
        logger.info("Generating context-aware prompt for model: \(modelType.rawValue)")
        
        var contextPrompt = prompt
        
        // Add vector memory context if enabled
        if useVectorMemory {
            let vectorContext = await retrieveRelevantVectorMemory(query: prompt, limit: maxContextItems)
            if !vectorContext.isEmpty {
                contextPrompt = "Here is some relevant information from my memory:\n\n\(vectorContext)\n\nUser query: \(prompt)"
            }
        }
        
        // Add external knowledge if enabled
        if useExternalSources {
            let externalContext = await retrieveExternalKnowledge(query: prompt, limit: maxContextItems)
            if !externalContext.isEmpty {
                contextPrompt = "Here is some relevant external information:\n\n\(externalContext)\n\nWith this context, please respond to: \(contextPrompt)"
            }
        }
        
        // Add conversation history context
        let modelContext = queue.sync {
            return Array(modelContexts[modelType]?.prefix(maxContextItems) ?? [])
        }
        
        // If there's conversation history, add it
        if !modelContext.isEmpty {
            var historyContext = "Previous interactions:\n\n"
            
            for (index, interaction) in modelContext.enumerated() {
                historyContext += "Interaction \(index + 1):\n"
                historyContext += "User: \(interaction.prompt)\n"
                historyContext += "Assistant: \(interaction.response)\n\n"
            }
            
            contextPrompt = "\(historyContext)Current request: \(contextPrompt)"
        }
        
        return contextPrompt
    }
    
    /// Search for interactions containing a query
    /// - Parameter query: The search query
    /// - Returns: Matching interactions
    public func searchInteractions(query: String) -> [ModelInteraction] {
        logger.info("Searching interactions for query: \(query)")
        
        let lowercaseQuery = query.lowercased()
        
        return recentInteractions.filter { interaction in
            interaction.prompt.lowercased().contains(lowercaseQuery) ||
            interaction.response.lowercased().contains(lowercaseQuery)
        }
    }
    
    /// Export all interactions to a JSON file
    /// - Parameter url: The URL to save to
    /// - Throws: An error if the export fails
    public func exportInteractions(to url: URL) throws {
        logger.info("Exporting interactions to: \(url.path)")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(recentInteractions)
        
        // Write to a temporary file first
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL)
        
        // Then move to the final location
        try FileManager.default.moveItem(at: tempURL, to: url)
    }
    
    /// Import interactions from a JSON file
    /// - Parameter url: The URL to import from
    /// - Throws: An error if the import fails
    public func importInteractions(from url: URL) throws {
        logger.info("Importing interactions from: \(url.path)")
        
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let interactions = try decoder.decode([ModelInteraction].self, from: data)
        
        // Update recent interactions
        Task { @MainActor in
            recentInteractions = interactions
        }
        
        // Update model-specific contexts
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Clear existing contexts
            for modelType in JanetModelType.allCases {
                self.modelContexts[modelType] = []
            }
            
            // Add imported interactions to model-specific contexts
            for interaction in interactions {
                for modelType in interaction.models {
                    self.modelContexts[modelType]?.append(interaction)
                }
            }
            
            // Sort model-specific contexts by timestamp
            for modelType in JanetModelType.allCases {
                self.modelContexts[modelType]?.sort { $0.timestamp > $1.timestamp }
            }
        }
        
        // Store in vector memory if enabled
        if useVectorMemory {
            Task {
                for interaction in interactions {
                    await storeInVectorMemory(prompt: interaction.prompt, result: interaction.response)
                }
            }
        }
    }
    
    /// Store an interaction in memory
    /// - Parameters:
    ///   - prompt: The prompt
    ///   - response: The response
    ///   - models: The models used to generate the response
    public func storeInteraction(prompt: String, response: String, models: [JanetModelType]) async {
        logger.info("Storing interaction with \(models.count) models")
        
        // Create a new interaction
        let interaction = ModelInteraction(
            prompt: prompt,
            response: response,
            models: models,
            timestamp: Date()
        )
        
        // Add to model contexts
        await withTaskGroup(of: Void.self) { group in
            for modelType in models {
                group.addTask {
                    self.addModelInteraction(modelType: modelType, interaction: interaction)
                }
            }
        }
        
        // Store in vector memory if enabled
        if useVectorMemory {
            Task {
                await storeInVectorMemory(interaction: interaction)
            }
        }
        
        // Update recent interactions
        await MainActor.run {
            // Add to the beginning of the array
            recentInteractions.insert(interaction, at: 0)
            
            // Limit the number of recent interactions
            if recentInteractions.count > maxInteractions {
                recentInteractions = Array(recentInteractions.prefix(maxInteractions))
            }
        }
        
        // Save to disk
        Task {
            try? await saveInteractions()
        }
    }
    
    // MARK: - RAG & Advanced Memory Methods
    
    /// Store prompt and result in vector memory
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - result: The generated result
    private func storeInVectorMemory(prompt: String, result: String) async {
        logger.info("Storing in vector memory")
        
        // Store in SQLite vector memory
        let promptEmbedding = VectorMath.generateSimpleEmbedding(for: prompt)
        let resultEmbedding = VectorMath.generateSimpleEmbedding(for: result)
        
        let promptItem = VectorMemoryItem(
            content: "User: \(prompt)",
            embedding: promptEmbedding,
            source: "user",
            tags: ["prompt"]
        )
        
        let resultItem = VectorMemoryItem(
            content: "Assistant: \(result)",
            embedding: resultEmbedding,
            source: "assistant",
            tags: ["response"]
        )
        
        sqliteMemory.addMemoryItem(promptItem)
        sqliteMemory.addMemoryItem(resultItem)
        
        // Also store in enhanced memory if available
        enhancedMemory?.addMemoryItem(content: "User: \(prompt)", source: "user", tags: ["prompt"])
        enhancedMemory?.addMemoryItem(content: "Assistant: \(result)", source: "assistant", tags: ["response"])
    }
    
    /// Store an interaction in vector memory
    /// - Parameter interaction: The interaction to store
    private func storeInVectorMemory(interaction: ModelInteraction) async {
        await storeInVectorMemory(prompt: interaction.prompt, result: interaction.response)
    }
    
    /// Retrieve relevant memories from vector storage
    /// - Parameters:
    ///   - query: The search query
    ///   - limit: Maximum number of items to retrieve
    /// - Returns: Formatted context string with relevant memories
    private func retrieveRelevantVectorMemory(query: String, limit: Int = 3) async -> String {
        logger.info("Retrieving relevant vector memory for query")
        
        // Search in SQLite vector memory
        let relevantItems = sqliteMemory.searchSimilarMemories(query: query, limit: limit)
        
        if relevantItems.isEmpty {
            return ""
        }
        
        // Format as context
        var context = ""
        for (index, item) in relevantItems.enumerated() {
            context += "[\(index + 1)] \(item.content)\n"
        }
        
        return context
    }
    
    /// Retrieve knowledge from external sources
    /// - Parameters:
    ///   - query: The search query
    ///   - limit: Maximum number of items to retrieve
    /// - Returns: Formatted context string with external knowledge
    private func retrieveExternalKnowledge(query: String, limit: Int = 3) async -> String {
        logger.info("Retrieving external knowledge for query")
        
        var context = ""
        
        // Get context from enhanced memory if available
        if let enhancedMemory = enhancedMemory {
            let enhancedContext = enhancedMemory.getMemoryContext(for: query, limit: limit)
            if !enhancedContext.isEmpty {
                context += enhancedContext + "\n\n"
            }
        }
        
        // Get context from Notion if available
        if let notionMemory = notionMemory {
            let notionItems = notionMemory.findRelevantNotionItems(query: query, limit: limit)
            if !notionItems.isEmpty {
                context += "Relevant Notion items:\n"
                for (index, item) in notionItems.enumerated() {
                    context += "[\(index + 1)] \(item.title): \(item.content)\n"
                }
            }
        }
        
        return context
    }
    
    /// Add an interaction to a model's context
    /// - Parameters:
    ///   - modelType: The model type
    ///   - interaction: The interaction to add
    public func addModelInteraction(
        modelType: JanetModelType,
        interaction: ModelInteraction
    ) {
        // ... existing code ...
    }
}

// MARK: - Model Interaction

/// An interaction with a model
public struct ModelInteraction: Codable, Identifiable, Sendable {
    /// Unique identifier for the interaction
    public var id = UUID()
    
    /// The input prompt
    public let prompt: String
    
    /// The model's response
    public let response: String
    
    /// The models used
    public let models: [JanetModelType]
    
    /// When the interaction occurred
    public let timestamp: Date
    
    /// Initialize a new model interaction
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - response: The model's response
    ///   - models: The models used
    ///   - timestamp: When the interaction occurred
    public init(
        prompt: String,
        response: String,
        models: [JanetModelType],
        timestamp: Date
    ) {
        self.prompt = prompt
        self.response = response
        self.models = models
        self.timestamp = timestamp
    }
    
    /// Coding keys for JSON encoding/decoding
    private enum CodingKeys: String, CodingKey {
        case id, prompt, response, models, timestamp
    }
    
    /// Initialize from a decoder
    /// - Parameter decoder: The decoder
    /// - Throws: An error if decoding fails
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        prompt = try container.decode(String.self, forKey: .prompt)
        response = try container.decode(String.self, forKey: .response)
        models = try container.decode([JanetModelType].self, forKey: .models)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    /// Encode to an encoder
    /// - Parameter encoder: The encoder
    /// - Throws: An error if encoding fails
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(response, forKey: .response)
        try container.encode(models, forKey: .models)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

extension MemoryContextManager {
    /// Save interactions to disk
    func saveInteractions() async throws {
        // Create a logger
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.folk.janet", category: "MemoryContextManager")
        
        // Log saving interactions to disk
        logger.info("Saving interactions to disk")
        
        // Get the path to the interactions file
        let fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("interactions.json")
        
        // Encode the interactions
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Get the interactions to save
        let interactions = await MainActor.run { self.recentInteractions }
        
        // Encode the interactions
        let data = try encoder.encode(interactions)
        
        // Write to a temporary file first
        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent("temp_interactions.json")
        try data.write(to: tempURL)
        
        // Replace the original file
        try FileManager.default.replaceItem(at: fileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
        
        // Log the number of interactions saved
        logger.info("Saved \(interactions.count) interactions to disk")
    }
} 