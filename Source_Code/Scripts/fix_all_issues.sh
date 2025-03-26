#!/bin/bash

# Comprehensive Fix Script for Janet App
echo "🔧 Starting comprehensive fixes for Janet app..."

# Define paths
SOURCE_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Source"
JANET_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Janet"
ENTITLEMENTS_FILE="/Volumes/Folk_DAS/Janet_25/Source_Code/Janet.entitlements"
OLLAMA_SERVICE_FILE="$JANET_DIR/Services/OllamaService.swift"
JANET_APP_FILE="$JANET_DIR/JanetApp.swift"
MESSAGE_FILE="$JANET_DIR/Models/Message.swift"
NAV_STATE_FILE="$JANET_DIR/Models/NavigationState.swift"
SPEECH_SERVICE_FILE="$JANET_DIR/Services/SpeechService.swift"
UTILITIES_DIR="$JANET_DIR/Utilities"
MEMORY_MANAGER_FILE="$SOURCE_DIR/Models/MemoryManager.swift"
MODEL_INTERFACE_FILE="$JANET_DIR/Models/ModelInterface.swift"

# Create directories if they don't exist
mkdir -p "$JANET_DIR/Models"
mkdir -p "$JANET_DIR/Services"
mkdir -p "$JANET_DIR/Services/Memory"
mkdir -p "$JANET_DIR/Views"
mkdir -p "$JANET_DIR/Utilities"

# Fix entitlements file
echo "📄 Fixing entitlements file..."
cat > "$ENTITLEMENTS_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.FolkAI.Janet</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>$(TeamIdentifierPrefix)com.FolkAI.Janet</string>
    </array>
</dict>
</plist>
EOF

# Fix NavigationState redeclaration issue
echo "🧭 Fixing NavigationState redeclaration issue..."
if [ -f "$SOURCE_DIR/Models/NavigationState.swift" ]; then
    cp "$SOURCE_DIR/Models/NavigationState.swift" "$JANET_DIR/Models/"
    echo "✅ NavigationState.swift copied successfully"
else
    echo "⚠️ Source NavigationState.swift not found, creating a basic version..."
    cat > "$NAV_STATE_FILE" << 'EOF'
import SwiftUI

// MARK: - NavigationState
public class NavigationState: ObservableObject {
    @Published var activeView: ActiveView = .chat
    @Published var navigationSelection: Int? = nil
    
    public enum ActiveView {
        case chat
        case settings
        case memory
        case meeting
        case vectorMemory
        case speech
    }
    
    public func navigateToHome() {
        activeView = .chat
        navigationSelection = nil
    }
    
    // Helper function to navigate to meeting view
    public func navigateToMeeting() {
        activeView = .meeting
    }
    
    // Helper function to navigate to vector memory view
    public func navigateToVectorMemory() {
        activeView = .vectorMemory
    }
    
    // Helper function to navigate to speech view
    public func navigateToSpeech() {
        activeView = .speech
    }
}
EOF
fi

# Fix Message.swift Janet namespace issue
echo "💬 Fixing Message.swift Janet namespace issue..."
if ! grep -q "public enum Janet" "$MESSAGE_FILE"; then
    # Add Janet namespace if it doesn't exist
    sed -i '' '1,10s/import Foundation/import Foundation\n\n\/\/ MARK: - Janet Namespace\n\/\/ Define the Janet namespace as a public enum to avoid conflicts\npublic enum Janet {\n    \/\/ Empty by design - just used for namespace organization\n}/' "$MESSAGE_FILE"
    echo "✅ Janet namespace added to Message.swift"
else
    echo "✅ Janet namespace already exists in Message.swift"
fi

# Fix JanetApp.swift ambiguous use of 'in'
echo "🚀 Fixing JanetApp.swift ambiguous use of 'in'..."
if grep -q "temporaryDirectory.path in" "$JANET_APP_FILE"; then
    # Fix the ambiguous use of 'in'
    sed -i '' 's/temporaryDirectory.path in/temporaryDirectory.path/' "$JANET_APP_FILE"
    echo "✅ Fixed ambiguous use of 'in' in JanetApp.swift"
else
    echo "✅ No ambiguous use of 'in' found in JanetApp.swift"
fi

# Fix OllamaModel struct in OllamaService.swift
echo "🔄 Fixing OllamaModel struct in OllamaService.swift..."
if ! grep -q "struct OllamaModel: Codable" "$OLLAMA_SERVICE_FILE"; then
    # Find the end of the file to add the OllamaModel struct
    LINE_NUM=$(wc -l < "$OLLAMA_SERVICE_FILE")
    
    # Add the OllamaModel struct
    cat >> "$OLLAMA_SERVICE_FILE" << 'EOF'

// Fix the OllamaModel struct to make it Codable
struct OllamaModel: Codable {
    let name: String
    let modified_at: String
    let size: Int64
}
EOF
    echo "✅ Added OllamaModel struct to OllamaService.swift"
else
    echo "✅ OllamaModel struct already exists in OllamaService.swift"
fi

# Fix logToFile function calls in OllamaService.swift
echo "📝 Fixing logToFile function calls in OllamaService.swift..."
if grep -q "logToFile(message:" "$OLLAMA_SERVICE_FILE"; then
    # Replace logToFile calls with print statements
    sed -i '' 's/logToFile(message: \(.*\))/print(\1)/g' "$OLLAMA_SERVICE_FILE"
    echo "✅ Fixed logToFile function calls in OllamaService.swift"
else
    echo "✅ No logToFile function calls found in OllamaService.swift"
fi

# Ensure SpeechService is properly copied
echo "🎤 Ensuring SpeechService is properly copied..."
if [ -f "$SOURCE_DIR/Services/SpeechService.swift" ]; then
    cp "$SOURCE_DIR/Services/SpeechService.swift" "$JANET_DIR/Services/"
    echo "✅ SpeechService.swift copied successfully"
else
    echo "⚠️ Source SpeechService.swift not found"
fi

# Set proper file permissions
echo "🔒 Setting file permissions..."
find "$JANET_DIR" -type f -name "*.swift" -exec chmod 644 {} \;
chmod 644 "$ENTITLEMENTS_FILE"

echo "✅ All fixes completed! You can now open the Xcode project and build the app."
echo "📝 If you encounter any issues, check the console output for errors."

# Create KeychainHelper.swift
echo "🔐 Creating KeychainHelper.swift..."
mkdir -p "$UTILITIES_DIR"
cat > "$UTILITIES_DIR/KeychainHelper.swift" << 'EOF'
import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    private let serviceName = "com.FolkAI.Janet"
    
    private init() {}
    
    // Store credentials in keychain
    func storeCredential(account: String, password: String) -> Bool {
        // Delete any existing credential
        deleteCredential(account: account)
        
        let passwordData = password.data(using: .utf8)!
        
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Retrieve credentials from keychain
    func retrieveCredential(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let retrievedData = dataTypeRef as? Data {
            return String(data: retrievedData, encoding: .utf8)
        }
        
        return nil
    }
    
    // Delete credentials from keychain
    func deleteCredential(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // Store API key or token
    func storeAPIKey(service: String, key: String) -> Bool {
        return storeCredential(account: "api_\(service)", password: key)
    }
    
    // Retrieve API key or token
    func retrieveAPIKey(service: String) -> String? {
        return retrieveCredential(account: "api_\(service)")
    }
}
EOF
echo "✅ KeychainHelper.swift created"

# Create KeychainAuthorizer.swift
echo "🔐 Creating KeychainAuthorizer.swift..."
cat > "$UTILITIES_DIR/KeychainAuthorizer.swift" << 'EOF'
import Foundation
import Security

class KeychainAuthorizer {
    static let shared = KeychainAuthorizer()
    
    private init() {}
    
    func preauthorizeKeychainAccess() {
        // Create a temporary keychain item to trigger authorization once
        let tempAccount = "janet_temp_auth_\(UUID().uuidString)"
        let tempPassword = "temporary_auth_value"
        
        // Store and immediately delete to trigger authorization
        _ = KeychainHelper.shared.storeCredential(account: tempAccount, password: tempPassword)
        KeychainHelper.shared.deleteCredential(account: tempAccount)
        
        print("✅ Keychain access pre-authorized")
    }
    
    // Call this at app startup to reduce keychain prompts
    func setupKeychainAccess() {
        // Pre-authorize common services
        let commonServices = ["notion", "ollama", "openai", "anthropic", "google", "azure"]
        
        for service in commonServices {
            // Check if we already have credentials
            if KeychainHelper.shared.retrieveAPIKey(service: service) == nil {
                // If not, create a placeholder that can be updated later
                _ = KeychainHelper.shared.storeAPIKey(service: service, key: "placeholder_\(service)")
            }
        }
        
        print("✅ Keychain access setup completed")
    }
}
EOF
echo "✅ KeychainAuthorizer.swift created"

# Create a patch file for JanetApp.swift
echo "📝 Creating patch for JanetApp.swift..."
cat > "/tmp/janet_app_keychain_patch.txt" << 'EOF'
// Add these lines to the init() method in JanetApp.swift:

// Pre-authorize keychain access to reduce prompts
KeychainAuthorizer.shared.preauthorizeKeychainAccess()

// Add these lines to the .onAppear block in the body property:

// Setup keychain access for services
KeychainAuthorizer.shared.setupKeychainAccess()
EOF
echo "✅ JanetApp.swift patch created at /tmp/janet_app_keychain_patch.txt"

echo "✅ All fixes completed!"
echo "📋 Note: To complete the keychain fix, you need to manually update JanetApp.swift"
echo "using the patch at /tmp/janet_app_keychain_patch.txt"

# Fix MemoryManager issues
echo "🧠 Fixing MemoryManager issues..."
if [ -f "$MEMORY_MANAGER_FILE" ]; then
    # Create a fixed version of MemoryManager.swift
    cat > "$JANET_DIR/Models/MemoryManager.swift" << 'EOF'
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
    echo "✅ Fixed MemoryManager.swift"
else
    echo "❌ MemoryManager.swift not found at $MEMORY_MANAGER_FILE"
fi

# Fix ModelInterface issues
echo "🧠 Fixing ModelInterface issues..."
# Create a fixed version of ModelInterface.swift
cat > "$MODEL_INTERFACE_FILE" << 'EOF'
//
//  ModelInterface.swift
//  Janet
//
//  Created by Michael folk on 2/25/25.
//

import Foundation
import os
import AppKit
import Combine

// MARK: - Model Interface
// This protocol defines the interface for AI models

// Renamed from AIModel to JanetAIModel to avoid conflict
public protocol JanetAIModel: ObservableObject {
    var isLoaded: Bool { get }
    func load() async throws
    func generateText(prompt: String, maxTokens: Int, temperature: Float, topP: Float, repetitionPenalty: Float) async throws -> String
}

/// Factory for creating model instances
public class ModelFactory {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "ModelFactory")
    
    /// Create a model of the specified type
    public static func createModel(type: ModelType, modelPath: String, tokenizerPath: String) -> any JanetAIModel {
        logger.info("Creating model of type: \(String(describing: type))")
        
        // Create OllamaModelImpl for all model types
        logger.info("Creating OllamaModelImpl instance for type: \(type.rawValue)")
        return OllamaModelImpl(modelType: type)
    }
    
    /// Create a model from a path
    public static func createModelFromPath(modelPath: String, tokenizerPath: String, type: ModelType) -> any JanetAIModel {
        logger.info("Creating model from path: \(modelPath)")
        return OllamaModelImpl(modelType: type)
    }
}

/// OllamaModelImpl implementation that uses the OllamaService
public class OllamaModelImpl: JanetAIModel {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "OllamaModelImpl")
    // Use the shared service from the app
    private var ollamaService: OllamaService 
    private let modelType: ModelType
    
    // Whether the model is loaded
    public private(set) var isLoaded: Bool = false
    private var connectionAttempts = 0
    private var maxConnectionAttempts = 3
    
    /// Initialize with model type
    public init(modelType: ModelType) {
        self.modelType = modelType
        
        // IMPORTANT: Use the shared singleton instance to ensure shared state
        self.ollamaService = OllamaService.shared
        logger.info("Using shared OllamaService singleton")
        
        logger.info("Initialized OllamaModelImpl with type: \(modelType.rawValue)")
        
        // Print debug information about the service state
        logger.info("OllamaService initial state - isRunning: \(self.ollamaService.isRunning), useMockMode: \(self.ollamaService.useMockMode)")
    }
    
    /// Load the model
    public func load() async throws {
        logger.info("Loading model of type: \(modelType.rawValue)")
        
        // Check if Ollama is running
        if !ollamaService.isRunning {
            logger.warning("Ollama service is not running, attempting to check status")
            
            // Try to check Ollama status
            let isRunning = await ollamaService.checkOllamaStatus()
            if !isRunning {
                logger.error("Failed to connect to Ollama service")
                throw ModelError.modelLoadFailed(reason: "Failed to connect to Ollama service")
            } else {
                logger.info("Successfully connected to Ollama service")
            }
        }
        
        // Load available models
        await ollamaService.loadAvailableModels()
        
        // Find the model that matches our type
        let modelName = modelType.displayName.lowercased()
        let modelExists = ollamaService.availableModels.contains { $0.lowercased().contains(modelName) }
        
        if !modelExists && connectionAttempts < maxConnectionAttempts {
            logger.warning("Model \(modelName) not found in available models: \(ollamaService.availableModels.joined(separator: ", "))")
            logger.info("Attempting to reconnect to Ollama (attempt \(connectionAttempts + 1)/\(maxConnectionAttempts))")
            
            // Increment connection attempts
            connectionAttempts += 1
            
            // Try to check Ollama status again
            let isRunning = await ollamaService.checkOllamaStatus()
            if !isRunning {
                logger.error("Failed to reconnect to Ollama service")
                throw ModelError.modelLoadFailed(reason: "Failed to reconnect to Ollama service")
            } else {
                logger.info("Successfully reconnected to Ollama service")
                
                // Try loading again
                return try await load()
            }
        } else if !modelExists {
            logger.error("Model \(modelName) not found after \(maxConnectionAttempts) attempts")
            throw ModelError.modelNotFound
        }
        
        // Set the model as loaded
        isLoaded = true
        logger.info("Model \(modelName) loaded successfully")
    }
    
    /// Generate text from the model
    public func generateText(prompt: String, maxTokens: Int = 2048, temperature: Float = 0.7, topP: Float = 0.9, repetitionPenalty: Float = 1.1) async throws -> String {
        logger.info("Generating text with prompt: \(prompt.prefix(50))...")
        
        // Check if the model is loaded
        if !isLoaded {
            logger.warning("Model not loaded, attempting to load")
            try await load()
        }
        
        // Generate text using the Ollama service
        do {
            // Use the generateResponse method that's available in OllamaService
            let response = await ollamaService.generateResponse(prompt: prompt)
            
            logger.info("Generated text: \(response.prefix(50))...")
            return response
        } catch {
            logger.error("Failed to generate text: \(error.localizedDescription)")
            throw ModelError.generationFailed(error.localizedDescription)
        }
    }
}
EOF
echo "✅ Fixed ModelInterface.swift"

echo "✅ All fixes completed!"
echo "📋 Note: To complete the keychain fix, you need to manually update JanetApp.swift"
echo "using the patch at /tmp/janet_app_keychain_patch.txt"

echo "✅ All fixes completed!"
echo "📋 Note: To complete the keychain fix, you need to manually update JanetApp.swift"
echo "using the patch at /tmp/janet_app_keychain_patch.txt" 