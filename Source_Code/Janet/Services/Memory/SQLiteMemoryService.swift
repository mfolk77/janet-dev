import Foundation
import SQLite

/// Memory item structure for vector-based memory
struct VectorMemoryItem: Codable, Identifiable {
    let id: String
    let content: String
    let timestamp: Date
    let embedding: [Double]  // Changed from Float to Double for consistency with VectorMath
    let source: String
    let tags: [String]
    
    init(id: String = UUID().uuidString, 
         content: String, 
         timestamp: Date = Date(), 
         embedding: [Double] = [], 
         source: String = "chat", 
         tags: [String] = []) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.embedding = embedding
        self.source = source
        self.tags = tags
    }
}

/// SQLite-based memory service with vector storage and cosine similarity search
class SQLiteMemoryService: ObservableObject {
    // Singleton instance
    static let shared = SQLiteMemoryService()
    
    // Published properties
    @Published var isInitialized: Bool = false
    @Published var memoryItems: [VectorMemoryItem] = []
    @Published var errorMessage: String = ""
    
    // SQLite connection
    private var db: Connection?
    
    // SQLite tables
    private let memories = Table("memories")
    
    // SQLite columns
    private let id = Expression<String>(value: "id")
    private let content = Expression<String>(value: "content")
    private let timestamp = Expression<String>(value: "timestamp") // Changed from Date to String
    private let embedding = Expression<String>(value: "embedding") // Store embeddings as JSON strings
    private let source = Expression<String>(value: "source")
    private let tags = Expression<String>(value: "tags") // Store tags as JSON strings
    
    // Date formatter for timestamp conversion
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // Mutex for thread safety
    private let dbMutex = NSLock()
    
    // Private initializer for singleton
    private init() {
        setupDatabase()
    }
    
    /// Set up the SQLite database
    private func setupDatabase() {
        print("🔍 JANET_DEBUG: Setting up SQLite memory database...")
        
        // Get path to documents directory
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("🔍 JANET_DEBUG: Error getting documents directory")
            return
        }
        
        let dbPath = documentsPath.appendingPathComponent("janet_memory.sqlite").path
        print("🔍 JANET_DEBUG: Database path: \(dbPath)")
        
        do {
            // Open connection with thread safety
            db = try Connection(dbPath, readonly: false)
            db?.busyTimeout = 5.0
            
            // Register cosine similarity function
            db?.createCosineSimilarityFunction()
            
            // Create table if it doesn't exist
            try db?.run(memories.create(ifNotExists: true) { table in
                table.column(id, primaryKey: true)
                table.column(content)
                table.column(timestamp)
                table.column(embedding)
                table.column(source)
                table.column(tags)
            })
            
            // Load initial data
            loadMemoryItems()
            
            isInitialized = true
            print("🔍 JANET_DEBUG: SQLite memory database initialized successfully")
        } catch {
            print("🔍 JANET_DEBUG: Error setting up database: \(error)")
        }
    }
    
    /// Load all memory items from the database
    func loadMemoryItems() {
        guard let db = db else { return }
        
        dbMutex.lock()
        defer { dbMutex.unlock() }
        
        do {
            let items = try db.prepare(memories.order(timestamp.desc))
            var loadedItems: [VectorMemoryItem] = []
            
            for item in items {
                if let embeddingData = item[embedding].data(using: .utf8),
                   let embeddingArray = try? JSONDecoder().decode([Double].self, from: embeddingData),
                   let tagsData = item[tags].data(using: .utf8),
                   let tagsArray = try? JSONDecoder().decode([String].self, from: tagsData) {
                    
                    let memoryItem = VectorMemoryItem(
                        id: item[id],
                        content: item[content],
                        timestamp: self.dateFormatter.date(from: item[timestamp]) ?? Date(),
                        embedding: embeddingArray,
                        source: item[source],
                        tags: tagsArray
                    )
                    
                    loadedItems.append(memoryItem)
                }
            }
            
            DispatchQueue.main.async {
                self.memoryItems = loadedItems
                print("🔍 JANET_DEBUG: Loaded \(loadedItems.count) memory items")
            }
        } catch {
            print("🔍 JANET_DEBUG: Error loading memory items: \(error)")
        }
    }
    
    /// Add a memory item to the database
    func addMemoryItem(_ item: VectorMemoryItem) {
        guard let db = db else { return }
        
        // Convert embedding to JSON string
        let embeddingData: Data
        let tagsData: Data
        
        do {
            embeddingData = try JSONEncoder().encode(item.embedding)
            tagsData = try JSONEncoder().encode(item.tags)
        } catch {
            print("🔍 JANET_DEBUG: Error encoding data: \(error)")
            return
        }
        
        guard let embeddingString = String(data: embeddingData, encoding: .utf8),
              let tagsString = String(data: tagsData, encoding: .utf8) else {
            print("🔍 JANET_DEBUG: Error converting data to string")
            return
        }
        
        // Use mutex for thread safety
        dbMutex.lock()
        defer { dbMutex.unlock() }
        
        do {
            // Begin transaction for atomic write
            try db.transaction {
                try db.run(memories.insert(or: .replace,
                    self.id <- item.id,
                    self.content <- item.content,
                    self.timestamp <- self.dateFormatter.string(from: item.timestamp),
                    self.embedding <- embeddingString,
                    self.source <- item.source,
                    self.tags <- tagsString
                ))
            }
            
            print("🔍 JANET_DEBUG: Added memory item: \(item.id)")
            
            // Update the published property
            DispatchQueue.main.async {
                self.memoryItems.append(item)
                self.memoryItems.sort { $0.timestamp > $1.timestamp }
            }
        } catch {
            print("🔍 JANET_DEBUG: Error adding memory item: \(error)")
        }
    }
    
    /// Generate an embedding for text using VectorMath utilities
    func generateEmbedding(for text: String, dimensions: Int = 128) -> [Double] {
        return VectorMath.generateSimpleEmbedding(for: text, dimensions: dimensions)
    }
    
    /// Search for similar memories using cosine similarity
    func searchSimilarMemories(query: String, limit: Int = 5) -> [VectorMemoryItem] {
        // Generate embedding for query
        let queryEmbedding = generateEmbedding(for: query)
        
        // Calculate cosine similarity for all memories
        let scoredMemories = memoryItems.map { item -> (VectorMemoryItem, Double) in
            let similarity = VectorMath.cosineSimilarity(vector1: queryEmbedding, vector2: item.embedding)
            return (item, similarity)
        }
        
        // Sort by similarity and return top results
        return scoredMemories
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
    
    /// Calculate cosine similarity between two vectors (kept for backward compatibility)
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        return VectorMath.cosineSimilarity(vector1: a, vector2: b)
    }
    
    /// Delete a memory item
    func deleteMemoryItem(withID id: String) {
        guard let db = db else { return }
        
        dbMutex.lock()
        defer { dbMutex.unlock() }
        
        do {
            try db.run(memories.filter(self.id == id).delete())
            
            // Update the published property
            DispatchQueue.main.async {
                self.memoryItems.removeAll { $0.id == id }
            }
            
            print("🔍 JANET_DEBUG: Deleted memory item: \(id)")
        } catch {
            print("🔍 JANET_DEBUG: Error deleting memory item: \(error)")
        }
    }
    
    /// Clear all memory items
    func clearAllMemories() {
        guard let db = db else { return }
        
        dbMutex.lock()
        defer { dbMutex.unlock() }
        
        do {
            try db.run(memories.delete())
            
            // Update the published property
            DispatchQueue.main.async {
                self.memoryItems.removeAll()
            }
            
            print("🔍 JANET_DEBUG: Cleared all memory items")
        } catch {
            print("🔍 JANET_DEBUG: Error clearing memory items: \(error)")
        }
    }
} 