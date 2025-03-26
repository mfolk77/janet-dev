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
