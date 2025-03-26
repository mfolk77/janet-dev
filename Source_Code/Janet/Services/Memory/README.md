# Vector Memory Implementation for Janet

This directory contains the implementation of a vector-based memory system for Janet, using SQLite for storage and simple vector operations for similarity search.

## Components

1. **SQLiteMemoryService**: Core service that manages the SQLite database for storing and retrieving vector memories.
2. **EnhancedMemoryManager**: Integration layer that connects the vector memory with existing memory systems.
3. **SQLiteExtensions**: Utility functions for vector operations in SQLite.
4. **VectorMemoryView**: UI for viewing and managing vector memories.

## Dependencies

This implementation requires the SQLite.swift package. To add it to your Xcode project:

1. In Xcode, select File > Add Packages...
2. Enter the package URL: https://github.com/stephencelis/SQLite.swift.git
3. Select the version: ~> 0.14.1
4. Click Add Package

## Memory Item Structure

Each memory item contains:
- **id**: Unique identifier
- **content**: The text content of the memory
- **timestamp**: When the memory was created
- **embedding**: Vector representation of the content
- **source**: Where the memory came from (user, assistant, notion, manual)
- **tags**: Array of tags for categorization

## Vector Operations

The current implementation uses a simple hash-based approach to generate embeddings. In a production environment, you would replace this with a proper embedding model like:

- OpenAI's text-embedding-ada-002
- Local embedding models via Ollama
- Apple's NaturalLanguage framework

## Usage

```swift
// Add a memory
EnhancedMemoryManager.shared.addMemoryItem(
    content: "Important information to remember",
    source: "manual",
    tags: ["important", "reference"]
)

// Search for relevant memories
let memories = EnhancedMemoryManager.shared.searchRelevantMemories(
    query: "What was that important information?",
    limit: 5
)

// Get formatted context for a query
let context = EnhancedMemoryManager.shared.getMemoryContext(
    for: "What was that important information?"
)
```

## Future Improvements

1. Replace the simple hash-based embeddings with a proper embedding model
2. Add support for chunking long documents
3. Implement more sophisticated retrieval methods (hybrid search, re-ranking)
4. Add memory persistence across app restarts
5. Implement memory pruning and management strategies 