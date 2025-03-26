// KeychainManager.swift
// Janet
//
// Created by Michael folk on 3/1/2025.
//

import Foundation
import Security

enum KeychainError: Error {
    case securityError(status: OSStatus)
    case itemNotFound
    case unexpectedData
    case dataConversionError
    case unhandledError(message: String)
}

class KeychainManager {
    // Singleton instance
    static let shared = KeychainManager()
    
    // Service name for the keychain items
    private let serviceName = "com.janet.api.credentials"
    
    private init() {}
    
    // MARK: - Saving Credentials
    
    /// Save a string value to the keychain
    func saveString(_ value: String, forKey key: String) throws {
        // Convert string to data
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        // Create a query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: valueData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // Check for errors
        if status != errSecSuccess {
            throw KeychainError.securityError(status: status)
        }
    }
    
    // MARK: - Retrieving Credentials
    
    /// Retrieve a string value from the keychain
    func getString(forKey key: String) throws -> String {
        // Create a query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Perform the query
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Handle the result
        if status == errSecItemNotFound {
            throw KeychainError.itemNotFound
        } else if status != errSecSuccess {
            throw KeychainError.securityError(status: status)
        }
        
        // Convert the result to data
        guard let resultData = result as? Data else {
            throw KeychainError.unexpectedData
        }
        
        // Convert data to string
        guard let resultString = String(data: resultData, encoding: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        return resultString
    }
    
    // MARK: - Updating Credentials
    
    /// Update an existing string value in the keychain
    func updateString(_ value: String, forKey key: String) throws {
        // Convert string to data
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        // Create query dictionary to find the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Create dictionary with the new value
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: valueData
        ]
        
        // Attempt to update the item
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        
        // If item doesn't exist, try to add it
        if status == errSecItemNotFound {
            try saveString(value, forKey: key)
        } else if status != errSecSuccess {
            throw KeychainError.securityError(status: status)
        }
    }
    
    // MARK: - Deleting Credentials
    
    /// Delete a keychain item
    func deleteItem(forKey key: String) throws {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Delete the item
        let status = SecItemDelete(query as CFDictionary)
        
        // Check for errors (ignore "item not found" as that's not actually an error in this context)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.securityError(status: status)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Save or update a value
    func saveOrUpdateString(_ value: String, forKey key: String) {
        do {
            try updateString(value, forKey: key)
        } catch KeychainError.itemNotFound {
            try? saveString(value, forKey: key)
        } catch {
            print("Error saving to keychain: \(error)")
        }
    }
    
    /// Get a string value or nil if not found
    func getStringOrNil(forKey key: String) -> String? {
        do {
            return try getString(forKey: key)
        } catch {
            return nil
        }
    }
    
    /// Check if a key exists in the keychain
    func keyExists(forKey key: String) -> Bool {
        do {
            _ = try getString(forKey: key)
            return true
        } catch {
            return false
        }
    }
}