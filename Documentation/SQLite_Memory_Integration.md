# SQLite Memory Integration in Janet

This document outlines the implementation of SQLite memory integration in the Janet application, focusing on stable and efficient memory management.

## Overview

Janet uses SQLite for persistent storage of conversation history and vector memories. The implementation prioritizes:

1. Efficient storage and retrieval
2. Query optimization
3. Caching mechanisms
4. Prevention of duplicate entries
5. Stable memory management

## Implementation Details

### Memory Manager

The `MemoryManager` class handles the core memory functionality:

- **Storage**: Conversations are stored in SQLite tables with proper indexing
- **Retrieval**: Optimized queries fetch relevant conversation history
- **Context Management**: Maintains conversation context for the AI assistant

### Vector Memory

The vector memory system enhances recall capabilities:

- **Embedding Storage**: Stores vector embeddings of messages for semantic search
- **Similarity Search**: Finds related memories based on semantic similarity
- **Caching**: Implements a basic LRU cache to speed up frequent queries

### Optimization Techniques

Several optimizations have been implemented:

1. **Prepared Statements**: Pre-compiled SQL statements improve query performance
2. **Transaction Batching**: Groups multiple operations into transactions
3. **Indexing**: Strategic indexes on frequently queried columns
4. **Connection Pooling**: Reuses database connections to reduce overhead

### Duplicate Prevention

To prevent duplicate memory entries:

- **Unique Constraints**: Database schema includes unique constraints
- **Deduplication Logic**: Application-level checks before insertion
- **Hash-based Comparison**: Quick comparison of message content

## Code Structure

The SQLite integration spans several files:

- `MemoryManager.swift`: Core memory management functionality
- `Services/Memory/*.swift`: Specialized memory services
- `EnhancedMemoryManager.swift`: Advanced memory features

## Usage Guidelines

When working with the memory system:

1. Always use transactions for multiple operations
2. Close database connections when no longer needed
3. Handle potential SQLite errors gracefully
4. Use parameterized queries to prevent SQL injection

## Future Improvements

Planned enhancements (not yet implemented):

1. Advanced caching strategies
2. Memory pruning for very long conversations
3. Improved vector search algorithms
4. Memory compression techniques

## Troubleshooting

Common issues and solutions:

- **Database Locked**: Ensure all connections are properly closed
- **Slow Queries**: Check for missing indexes or inefficient query patterns
- **Memory Leaks**: Verify proper resource management in database operations

## Conclusion

The SQLite memory integration in Janet provides a robust foundation for storing and retrieving conversation history. The focus on efficiency, stability, and preventing duplicates ensures reliable operation even with extensive usage. 