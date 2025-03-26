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
