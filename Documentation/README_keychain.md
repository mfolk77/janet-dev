# Janet Keychain Access Fix

This document explains how to reduce the number of keychain prompts when running the Janet app.

## Problem

When running the Janet app, you may encounter multiple keychain access prompts for various services like Notion, Ollama, OpenAI, etc. This happens because:

1. The app is requesting access to keychain items individually
2. The entitlements file doesn't properly configure keychain access groups
3. The app doesn't pre-authorize keychain access at startup

## Solution

The `keychain_fix.sh` script implements several improvements to reduce keychain prompts:

1. **Updated Entitlements**: Adds proper keychain access groups to the app's entitlements
2. **KeychainHelper**: A utility class for securely storing and retrieving credentials
3. **KeychainAuthorizer**: Pre-authorizes keychain access at app startup
4. **JanetApp Integration**: Updates the main app to initialize keychain access early

## How to Implement

1. Run the keychain fix script:
   ```bash
   cd /Volumes/Folk_DAS/Janet_Clean
   ./keychain_fix.sh
   ```

2. The script will:
   - Update the entitlements file with keychain access groups
   - Create KeychainHelper.swift and KeychainAuthorizer.swift in the Janet/Utilities directory
   - Generate a patch for JanetApp.swift

3. After running the script, you need to:
   - Make sure the new Swift files are included in your Xcode project
   - Update JanetApp.swift with the code from the patch
   - Rebuild the app

## How It Works

### 1. Entitlements Update

The script adds keychain access groups to the entitlements file:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.FolkAI.Janet</string>
</array>
```

### 2. KeychainHelper

This class provides a secure interface for storing and retrieving credentials:

- `storeCredential(account:password:)`: Securely stores credentials
- `retrieveCredential(account:)`: Retrieves stored credentials
- `deleteCredential(account:)`: Removes credentials
- `storeAPIKey(service:key:)` and `retrieveAPIKey(service:)`: Convenience methods for API keys

### 3. KeychainAuthorizer

This class handles pre-authorization of keychain access:

- `preauthorizeKeychainAccess()`: Triggers a single keychain authorization at app startup
- `setupKeychainAccess()`: Pre-authorizes common services used by Janet

### 4. JanetApp Integration

The app initialization is updated to:

- Call `KeychainAuthorizer.shared.preauthorizeKeychainAccess()` during init
- Call `KeychainAuthorizer.shared.setupKeychainAccess()` when the app appears

## Benefits

After implementing this fix:

1. You'll see significantly fewer keychain prompts
2. The app will handle credentials more securely
3. API keys and tokens will be stored in a consistent way
4. The user experience will be smoother with fewer interruptions

## Troubleshooting

If you still experience keychain prompts:

1. Make sure the entitlements file is properly applied during the build
2. Check that KeychainHelper and KeychainAuthorizer are correctly integrated
3. Verify that JanetApp.swift includes the initialization code
4. Try deleting and reinstalling the app to reset keychain permissions

## Security Considerations

This implementation follows Apple's security best practices:

- Uses `kSecAttrAccessibleAfterFirstUnlock` to balance security and usability
- Properly handles keychain item creation, retrieval, and deletion
- Uses unique service and account identifiers to avoid conflicts
- Implements proper error handling for keychain operations 