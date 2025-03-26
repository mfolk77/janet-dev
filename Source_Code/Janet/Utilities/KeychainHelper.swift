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
