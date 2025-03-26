//
//  JanetApp.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import SwiftUI

// Use NavigationState class from Models/NavigationState.swift
// NavigationState is defined in Source/Models/NavigationState.swift

@main
struct JanetApp: App {
    // Initialize model manager first to ensure it's ready for all components
    @StateObject private var modelManager = ModelManager.shared
    
    // Create shared instances of other services
    @StateObject private var ollamaService = OllamaService()
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var commandHandler = CommandHandler()
    @StateObject private var webhookService = WebhookService()
    @StateObject private var notionMemory = NotionMemory()
    @StateObject private var navigationState = NavigationState()
    @StateObject private var speechService = SpeechService()
    
    // Initialize enhanced memory manager
    private let enhancedMemory = EnhancedMemoryManager.shared
    
    init() {
        print("🚀 JANET_DEBUG: JanetApp initializing...")
        
        // Print paths for debugging
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            print("📁 JANET_DEBUG: Documents directory: \(documentsPath.path)")
        }
        
        // Fix for ambiguous use of 'in'
        let tempPath = FileManager.default.temporaryDirectory.path
        print("📁 JANET_DEBUG: Temporary directory: \(tempPath)")
        
        print("📦 JANET_DEBUG: Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // Pre-authorize keychain access to reduce prompts
        KeychainAuthorizer.shared.preauthorizeKeychainAccess()
        
        // Initialize enhanced memory
        print("🧠 JANET_DEBUG: Enhanced memory initialized: \(enhancedMemory.isInitialized)")
        
        // Initialize speech service
        print("🎤 JANET_DEBUG: Speech service initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ollamaService)
                .environmentObject(memoryManager)
                .environmentObject(commandHandler)
                .environmentObject(webhookService)
                .environmentObject(notionMemory)
                .environmentObject(navigationState)
                .environmentObject(modelManager)
                .environmentObject(speechService)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Setup keychain access for services
                    KeychainAuthorizer.shared.setupKeychainAccess()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Chat") {
                    memoryManager.clearConversation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .appInfo) {
                Button("Check for Updates") {
                    // Future implementation
                }
                
                Divider()
                
                Button("Preferences...") {
                    // Future implementation - open settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
