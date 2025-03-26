//
//  JanetApp.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import SwiftUI
import os.log

// Use NavigationState class from Models/NavigationState.swift
// NavigationState is defined in Source/Models/NavigationState.swift

@main
struct JanetApp: App {
    // Initialize model manager first to ensure it's ready for all components
    @StateObject private var modelManager = ModelManager.shared
    
    // Initialize the model orchestrator
    @StateObject private var modelOrchestrator = ModelOrchestrator.shared
    
    // Create shared instances of other services
    @StateObject private var ollamaService = OllamaService()
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var commandHandler = CommandHandler()
    @StateObject private var webhookService = WebhookService()
    @StateObject private var notionMemory = NotionMemory()
    @StateObject private var navigationState = NavigationState()
    @StateObject private var speechService = SpeechService()
    @StateObject private var mcpBridge = MCPBridge.shared
    
    // Initialize enhanced memory manager
    private let enhancedMemory = EnhancedMemoryManager.shared
    
    // Logger for debugging
    private let logger = Logger(subsystem: "com.janet.app", category: "initialization")
    
    // Initialization queue to prevent threading issues
    private let initQueue = DispatchQueue(label: "com.janet.initialization", qos: .userInitiated)
    
    init() {
        logger.info("🚀 JanetApp initializing...")
        
        // Print paths for debugging
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            logger.info("📁 Documents directory: \(documentsPath.path)")
        }
        
        // Fix for ambiguous use of 'in'
        let tempPath = FileManager.default.temporaryDirectory.path
        logger.info("📁 Temporary directory: \(tempPath)")
        
        logger.info("📦 Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // Pre-authorize keychain access to reduce prompts - do this synchronously
        initQueue.sync {
            KeychainAuthorizer.shared.preauthorizeKeychainAccess()
        }
        
        // Initialize enhanced memory
        let isMemoryInitialized = enhancedMemory.isInitialized
        logger.info("🧠 Enhanced memory initialized: \(isMemoryInitialized)")
        
        // Initialize speech service
        logger.info("🎤 Speech service initialized")
        
        // Initialize model orchestrator
        logger.info("🎭 Model orchestrator initialized")
        
        // Initialize model manager with phi model - do this asynchronously
        let appLogger = logger
        Task {
            do {
                appLogger.info("🤖 Loading phi model...")
                try await ModelManager.shared.loadModel(type: .phi)
                appLogger.info("🤖 Phi model loaded successfully")
                
                // Register the loaded model with the orchestrator
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .modelLoadStateChanged,
                        object: nil,
                        userInfo: ["modelType": JanetModelType.phi.rawValue, "isLoaded": true]
                    )
                }
            } catch {
                appLogger.error("❌ Failed to load phi model: \(error.localizedDescription)")
                // Fallback to default model if phi fails
                do {
                    appLogger.info("🤖 Falling back to default model...")
                    try await ModelManager.shared.loadModel()
                    
                    // Register the loaded model with the orchestrator
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .modelLoadStateChanged,
                            object: nil,
                            userInfo: ["modelType": JanetModelType.ollama.rawValue, "isLoaded": true]
                        )
                    }
                } catch {
                    appLogger.error("❌ Failed to load default model: \(error.localizedDescription)")
                }
            }
        }
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
                .environmentObject(modelOrchestrator)
                .environmentObject(mcpBridge)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Setup keychain access for services on the main thread
                    KeychainAuthorizer.shared.setupKeychainAccess()
                    
                    // Start the MCP if it's not already running
                    if !MCPBridge.shared.isRunning {
                        Task {
                            await MCPBridge.shared.startMCP()
                        }
                    }
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
                    navigationState.activeView = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Button("Orchestrator Settings...") {
                    // Navigate to orchestrator settings
                    navigationState.navigateToOrchestrator()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}
