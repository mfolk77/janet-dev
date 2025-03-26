#!/bin/bash

# Fix script for Memory Manager issues
echo "🧠 Starting Memory Manager fixes..."

# Define paths
SOURCE_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Source"
JANET_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Janet"
MODELS_DIR="$JANET_DIR/Models"
MEMORY_MANAGER_FILE="$MODELS_DIR/MemoryManager.swift"
MESSAGE_FILE="$MODELS_DIR/Message.swift"

# Ensure directories exist
mkdir -p "$MODELS_DIR"

# 1. Fix Janet namespace issues
echo "🔄 Fixing Janet namespace issues..."

# Create a consistent Janet namespace declaration in Message.swift
cat > "$MESSAGE_FILE" << 'EOF'
//
//  Message.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import Foundation

// MARK: - Janet Namespace
// This is the primary namespace for the Janet app
public enum Janet {
    // Empty by design - used for organizational purposes
}

// MARK: - Models Namespace
extension Janet {
    public enum Models {
        // Empty by design - used for organizational purposes
    }
}

// MARK: - Legacy Message
// This is kept for backward compatibility
public struct Message: Identifiable, Equatable, Codable {
    public var id: UUID
    public var content: String
    public var isUser: Bool
    public var timestamp: Date
    
    public init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
    
    // Convert to MemoryManager message format
    public func toMemoryMessage() -> Janet.Models.Message {
        return Janet.Models.Message(
            id: self.id.uuidString,
            content: self.content,
            timestamp: self.timestamp,
            isUserMessage: self.isUser
        )
    }
    
    // Create from MemoryManager message format
    public static func fromMemoryMessage(_ message: Janet.Models.Message) -> Message {
        return Message(
            id: UUID(uuidString: message.id) ?? UUID(),
            content: message.content,
            isUser: message.isUserMessage,
            timestamp: message.timestamp
        )
    }
}

// Type aliases for backward compatibility
public typealias LegacyMessage = Message
public extension Janet.Models {
    typealias LegacyMessage = Message
}
EOF

# 2. Fix Conversation struct to conform to Codable
echo "🔄 Fixing Conversation struct to conform to Codable..."

# Create a fixed version of MemoryManager.swift
cat > "$MEMORY_MANAGER_FILE" << 'EOF'
//
//  MemoryManager.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Message
extension Janet.Models {
    public struct Message: Identifiable, Codable {
        public var id: String
        public var content: String
        public var timestamp: Date
        public var isUserMessage: Bool
        
        enum CodingKeys: String, CodingKey {
            case id
            case content
            case timestamp
            case isUserMessage
        }
        
        public init(id: String = UUID().uuidString, content: String, timestamp: Date = Date(), isUserMessage: Bool) {
            self.id = id
            self.content = content
            self.timestamp = timestamp
            self.isUserMessage = isUserMessage
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            content = try container.decode(String.self, forKey: .content)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            isUserMessage = try container.decode(Bool.self, forKey: .isUserMessage)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(content, forKey: .content)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(isUserMessage, forKey: .isUserMessage)
        }
    }
}

// MARK: - Conversation
public struct Conversation: Codable, Identifiable {
    public var id: String
    public var title: String
    public var messages: [Janet.Models.Message]
    public var createdAt: Date
    public var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case messages
        case createdAt
        case updatedAt
    }
    
    public init(id: String = UUID().uuidString, title: String = "New Conversation", messages: [Janet.Models.Message] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Memory Manager
public class MemoryManager: ObservableObject {
    // Singleton instance
    public static let shared = MemoryManager()
    
    // Published properties
    @Published public var conversations: [Conversation] = []
    @Published public var currentConversation: Conversation
    @Published public var searchQuery: String = ""
    @Published public var isSearching: Bool = false
    
    // File URL for storing conversations
    private let conversationsURL: URL
    
    // Initialize with default conversation
    public init() {
        // Set up file URL
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.conversationsURL = documentsDirectory.appendingPathComponent("janet_conversations.json")
        
        // Initialize with empty conversation
        self.currentConversation = Conversation()
        
        // Load conversations from disk
        self.loadConversations()
        
        // If no conversations, create a default one
        if self.conversations.isEmpty {
            self.conversations = [self.currentConversation]
        } else {
            // Use the most recent conversation as current
            self.currentConversation = self.conversations.sorted { $0.updatedAt > $1.updatedAt }.first!
        }
        
        print("MemoryManager initialized with \(self.conversations.count) conversations")
    }
    
    // MARK: - Conversation Management
    
    // Add a message to the current conversation
    public func addMessage(_ content: String, isUser: Bool) {
        let message = Janet.Models.Message(content: content, isUserMessage: isUser)
        self.currentConversation.messages.append(message)
        self.currentConversation.updatedAt = Date()
        
        // Update the conversation in the list
        if let index = self.conversations.firstIndex(where: { $0.id == self.currentConversation.id }) {
            self.conversations[index] = self.currentConversation
        } else {
            self.conversations.append(self.currentConversation)
        }
        
        // Save to disk
        self.saveConversations()
    }
    
    // Create a new conversation
    public func newConversation() {
        self.currentConversation = Conversation()
        self.conversations.append(self.currentConversation)
        self.saveConversations()
    }
    
    // Switch to a different conversation
    public func switchConversation(to conversationId: String) {
        if let conversation = self.conversations.first(where: { $0.id == conversationId }) {
            self.currentConversation = conversation
        }
    }
    
    // Delete a conversation
    public func deleteConversation(_ conversationId: String) {
        self.conversations.removeAll(where: { $0.id == conversationId })
        
        // If we deleted the current conversation, switch to another one
        if self.currentConversation.id == conversationId {
            if let firstConversation = self.conversations.first {
                self.currentConversation = firstConversation
            } else {
                // If no conversations left, create a new one
                self.newConversation()
            }
        }
        
        self.saveConversations()
    }
    
    // Clear the current conversation
    public func clearConversation() {
        self.currentConversation.messages = []
        self.currentConversation.updatedAt = Date()
        
        // Update in the list
        if let index = self.conversations.firstIndex(where: { $0.id == self.currentConversation.id }) {
            self.conversations[index] = self.currentConversation
        }
        
        self.saveConversations()
    }
    
    // MARK: - Persistence
    
    // Save conversations to disk
    private func saveConversations() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self.conversations)
            
            // Write atomically to prevent data corruption
            try data.write(to: self.conversationsURL, options: .atomicWrite)
            print("Saved \(self.conversations.count) conversations to disk")
        } catch {
            print("Error saving conversations: \(error.localizedDescription)")
        }
    }
    
    // Load conversations from disk
    private func loadConversations() {
        do {
            if FileManager.default.fileExists(atPath: self.conversationsURL.path) {
                let data = try Data(contentsOf: self.conversationsURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                self.conversations = try decoder.decode([Conversation].self, from: data)
                print("Loaded \(self.conversations.count) conversations from disk")
            }
        } catch {
            print("Error loading conversations: \(error.localizedDescription)")
            // If there's an error loading, start with empty conversations
            self.conversations = []
        }
    }
    
    // MARK: - Search
    
    // Search for messages containing the query
    public func searchMessages() -> [Janet.Models.Message] {
        guard !self.searchQuery.isEmpty else { return [] }
        
        let query = self.searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Search across all conversations
        var results: [Janet.Models.Message] = []
        
        for conversation in self.conversations {
            let matchingMessages = conversation.messages.filter { 
                $0.content.lowercased().contains(query) 
            }
            results.append(contentsOf: matchingMessages)
        }
        
        // Sort by recency
        return results.sorted { $0.timestamp > $1.timestamp }
    }
}
EOF

# 3. Set proper permissions
echo "🔒 Setting file permissions..."
chmod 644 "$MESSAGE_FILE" "$MEMORY_MANAGER_FILE"

# 4. Copy files to Source directory for consistency
echo "📋 Copying fixed files to Source directory..."
mkdir -p "$SOURCE_DIR/Models"
cp "$MESSAGE_FILE" "$SOURCE_DIR/Models/"
cp "$MEMORY_MANAGER_FILE" "$SOURCE_DIR/Models/"

echo "✅ Memory Manager fixes completed!"
echo "You can now build the app with the fixed Memory Manager implementation." 