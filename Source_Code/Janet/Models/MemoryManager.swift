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
