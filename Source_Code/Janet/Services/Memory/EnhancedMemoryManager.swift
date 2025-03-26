import Foundation
import Combine

/// Enhanced memory manager that integrates SQLite vector memory with existing memory systems
class EnhancedMemoryManager: ObservableObject, @unchecked Sendable {
    // Singleton instance
    static let shared = EnhancedMemoryManager()
    
    // Memory services
    private let memoryManager: MemoryManager
    private let notionMemory: NotionMemory
    private let sqliteMemory: SQLiteMemoryService
    
    // Published properties
    @Published var isInitialized: Bool = false
    @Published var lastSearchQuery: String = ""
    @Published var lastSearchResults: [VectorMemoryItem] = []
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Private initializer for singleton
    private init() {
        print("🧠 JANET_DEBUG: Creating EnhancedMemoryManager instance")
        
        // Get references to existing services
        self.memoryManager = MemoryManager.shared
        self.notionMemory = NotionMemory.shared
        self.sqliteMemory = SQLiteMemoryService.shared
        
        // Set up observers
        setupObservers()
        
        // Initialize
        initialize()
    }
    
    /// Initialize the enhanced memory manager
    private func initialize() {
        print("🧠 JANET_DEBUG: Initializing EnhancedMemoryManager...")
        
        // Wait for SQLite memory service to initialize
        if !sqliteMemory.isInitialized {
            print("🧠 JANET_DEBUG: Waiting for SQLiteMemoryService to initialize...")
            // In a real app, we would use a completion handler or async/await
            // For now, we'll just continue and rely on the observers
        }
        
        // Import existing memories
        Task {
            await importExistingMemories()
            
            DispatchQueue.main.async {
                self.isInitialized = true
                print("🧠 JANET_DEBUG: EnhancedMemoryManager initialized with \(self.sqliteMemory.memoryItems.count) items")
            }
        }
    }
    
    /// Set up observers for memory changes
    private func setupObservers() {
        print("🧠 JANET_DEBUG: Setting up memory observers")
        
        // Observe changes to the current conversation
        memoryManager.$currentConversation
            .dropFirst() // Skip initial value
            .sink { [weak self] conversation in
                // When conversation changes, store new messages in vector memory
                guard let self = self else { return }
                
                // Only process if there are messages
                if !conversation.messages.isEmpty {
                    // Get the last message
                    if let lastMessage = conversation.messages.last {
                        print("🧠 JANET_DEBUG: New message detected, storing in vector memory")
                        self.storeMessageInVectorMemory(lastMessage)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe changes to Notion items
        notionMemory.$notionItems
            .dropFirst() // Skip initial value
            .sink { [weak self] items in
                // When Notion items change, store them in vector memory
                guard let self = self else { return }
                
                // Only process if there are items
                if !items.isEmpty {
                    print("🧠 JANET_DEBUG: Notion items updated, storing in vector memory")
                    self.storeNotionItemsInVectorMemory(items)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Import existing memories from MemoryManager and NotionMemory
    private func importExistingMemories() async {
        print("🧠 JANET_DEBUG: Importing existing memories...")
        
        // Import from current conversation
        let currentMessages = memoryManager.currentConversation.messages
        print("🧠 JANET_DEBUG: Importing \(currentMessages.count) messages from current conversation")
        for message in currentMessages {
            storeMessageInVectorMemory(message)
        }
        
        // Import from saved conversations
        // Use the conversations property from MemoryManager
        let savedConversations = memoryManager.conversations
        print("🧠 JANET_DEBUG: Importing messages from \(savedConversations.count) saved conversations")
        for conversation in savedConversations {
            for message in conversation.messages {
                storeMessageInVectorMemory(message)
            }
        }
        
        // Import from Notion
        let notionItems = notionMemory.notionItems
        print("🧠 JANET_DEBUG: Importing \(notionItems.count) Notion items")
        storeNotionItemsInVectorMemory(notionItems)
        
        print("🧠 JANET_DEBUG: Finished importing existing memories")
    }
    
    /// Store a message in vector memory
    private func storeMessageInVectorMemory(_ message: Janet.Models.Message) {
        // Generate embedding using VectorMath
        let embedding = VectorMath.generateSimpleEmbedding(for: message.content)
        
        // Create vector memory item
        let item = VectorMemoryItem(
            id: message.id,
            content: message.content,
            timestamp: message.timestamp,
            embedding: embedding,
            source: message.isUserMessage ? "user" : "assistant",
            tags: ["chat"]
        )
        
        // Store in SQLite
        sqliteMemory.addMemoryItem(item)
    }
    
    /// Store Notion items in vector memory
    private func storeNotionItemsInVectorMemory(_ items: [NotionItem]) {
        for item in items {
            // Generate embedding for title + content using VectorMath
            let combinedText = "\(item.title): \(item.content)"
            let embedding = VectorMath.generateSimpleEmbedding(for: combinedText)
            
            // Create vector memory item
            let vectorItem = VectorMemoryItem(
                id: item.id,
                content: combinedText,
                timestamp: item.createdTime,
                embedding: embedding,
                source: "notion",
                tags: item.tags
            )
            
            // Store in SQLite
            sqliteMemory.addMemoryItem(vectorItem)
        }
    }
    
    /// Search for relevant memories based on a query
    func searchRelevantMemories(query: String, limit: Int = 5) -> [VectorMemoryItem] {
        print("🧠 JANET_DEBUG: Searching for memories relevant to: \"\(query)\"")
        
        // Store the query for debugging
        self.lastSearchQuery = query
        
        // Get results
        let results = sqliteMemory.searchSimilarMemories(query: query, limit: limit)
        
        // Store results for debugging
        self.lastSearchResults = results
        
        print("🧠 JANET_DEBUG: Found \(results.count) relevant memories")
        return results
    }
    
    /// Add a memory item directly
    func addMemoryItem(content: String, source: String = "manual", tags: [String] = []) {
        print("🧠 JANET_DEBUG: Adding new memory item with source: \(source)")
        
        // Generate embedding using VectorMath
        let embedding = VectorMath.generateSimpleEmbedding(for: content)
        
        // Create vector memory item
        let item = VectorMemoryItem(
            id: UUID().uuidString,
            content: content,
            timestamp: Date(),
            embedding: embedding,
            source: source,
            tags: tags
        )
        
        // Store in SQLite
        sqliteMemory.addMemoryItem(item)
    }
    
    /// Get memory context for a query
    func getMemoryContext(for query: String, limit: Int = 3) -> String {
        print("🧠 JANET_DEBUG: Getting memory context for: \"\(query)\"")
        
        let relevantMemories = searchRelevantMemories(query: query, limit: limit)
        
        if relevantMemories.isEmpty {
            print("🧠 JANET_DEBUG: No relevant memories found")
            return ""
        }
        
        // Format memories as context
        var context = "Here is some relevant information from my memory:\n\n"
        
        for (index, memory) in relevantMemories.enumerated() {
            context += "[\(index + 1)] \(memory.content)\n"
            print("🧠 JANET_DEBUG: Memory [\(index + 1)]: \(memory.content.prefix(50))...")
        }
        
        context += "\nPlease use this information to help answer the question."
        
        return context
    }
    
    /// Clear all vector memories
    func clearAllVectorMemories() {
        print("🧠 JANET_DEBUG: Clearing all vector memories")
        sqliteMemory.clearAllMemories()
    }
} 