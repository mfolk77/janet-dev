#!/bin/bash

# Janet Keychain Access Fix Script
echo "🔑 Setting up keychain access for Janet app..."

# Define paths
JANET_DIR="/Volumes/Folk_DAS/Janet_25/Source_Code/Janet"
APP_PATH="/Volumes/Folk_DAS/Janet AI/DerivedData/Build/Products/Debug/Janet.app"
ENTITLEMENTS_FILE="/Volumes/Folk_DAS/Janet_25/Source_Code/Janet.entitlements"

# 1. Update entitlements to include keychain access
echo "📝 Updating entitlements file to include keychain access..."
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

# 2. Create a helper function to add to the app
echo "📄 Creating KeychainHelper.swift..."
mkdir -p "$JANET_DIR/Utilities"
cat > "$JANET_DIR/Utilities/KeychainHelper.swift" << 'EOF'
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

# 3. Create a utility to pre-authorize keychain access
echo "🔐 Creating KeychainAuthorizer.swift..."
cat > "$JANET_DIR/Utilities/KeychainAuthorizer.swift" << 'EOF'
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

# 4. Create a patch for JanetApp.swift to initialize keychain access
echo "🔄 Creating patch for JanetApp.swift..."
cat > "/tmp/janet_keychain_patch.txt" << 'EOF'
import SwiftUI
import Combine
import Foundation

@main
struct JanetApp: App {
    @StateObject private var navigationState = NavigationState()
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var modelManager = ModelManager()
    @StateObject private var ollamaService = OllamaService()
    @StateObject private var audioRecordingService = AudioRecordingService()
    
    init() {
        print("🚀 JANET_DEBUG: JanetApp initializing...")
        
        // Setup directories
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            print("📁 JANET_DEBUG: Documents directory: \(documentsPath)")
        }
        
        let tempPath = FileManager.default.temporaryDirectory.path
        print("📁 JANET_DEBUG: Temporary directory: \(tempPath)")
        
        if let bundleID = Bundle.main.bundleIdentifier {
            print("📦 JANET_DEBUG: Bundle identifier: \(bundleID)")
        }
        
        // Pre-authorize keychain access to reduce prompts
        KeychainAuthorizer.shared.preauthorizeKeychainAccess()
        
        // Initialize online mode by default
        print("Janet initialized in ONLINE MODE by default")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationState)
                .environmentObject(memoryManager)
                .environmentObject(modelManager)
                .environmentObject(ollamaService)
                .environmentObject(audioRecordingService)
                .onAppear {
                    // Setup keychain access for services
                    KeychainAuthorizer.shared.setupKeychainAccess()
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Clear Memory") {
                    memoryManager.clearMemory()
                }
            }
        }
    }
}
EOF

echo "📋 Instructions for implementing keychain fix:"
echo "1. Copy KeychainHelper.swift and KeychainAuthorizer.swift to your Janet/Utilities directory"
echo "2. Update JanetApp.swift to include the keychain initialization code"
echo "3. Rebuild the app with the updated entitlements"
echo ""
echo "✅ Keychain fix script completed!"
echo "You can now implement these changes to reduce keychain prompts." 