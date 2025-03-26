# Janet Clean

This is a cleaned-up version of the Janet app.

## Running the App

You can run the app in two ways:

1. Double-click the "Launch Janet.command" file
2. Open Terminal and run: `cd /Volumes/Folk_DAS/Janet_Clean && ./run_janet.sh`

## Setting Up in Xcode

To set up the project in Xcode:

1. Open Xcode
2. Select "Create a new Xcode project"
3. Choose "App" under macOS
4. Name the project "Janet" and set the organization identifier to "com.FolkAI"
5. Choose Swift as the language and SwiftUI as the interface
6. Save the project in the `/Volumes/Folk_DAS/Janet_Clean` directory
7. Delete the auto-generated files (ContentView.swift, etc.)
8. Right-click on the project in the navigator and select "Add Files to Janet..."
9. Navigate to `/Volumes/Folk_DAS/Janet_Clean/Source` and select all files and folders
10. Make sure "Copy items if needed" is NOT checked and "Create groups" is selected
11. Click "Add"
12. Open the project settings, select the "Janet" target, and go to the "Signing & Capabilities" tab
13. Add the following entitlements:
   - App Sandbox
   - Outgoing Connections (Client)
   - Incoming Connections (Server)
   - User Selected File (Read Only)

## Cleaning Up Old Directories

To clean up old Janet directories:

1. Open Terminal
2. Run: `cd /Volumes/Folk_DAS/Janet_Clean && ./cleanup_old_janet.sh`
3. Follow the prompts to confirm which directories you want to delete

## Vector Memory Implementation

The vector memory implementation is located in the `Source/Services/Memory` directory. It includes:

1. SQLiteMemoryService.swift - Manages the SQLite database
2. EnhancedMemoryManager.swift - Connects vector memory with existing systems
3. SQLiteExtensions.swift - Provides utility functions for vector operations

To use the vector memory implementation, you need to add the SQLite.swift package to your Xcode project:

1. In Xcode, select File > Add Packages...
2. Enter the package URL: https://github.com/stephencelis/SQLite.swift.git
3. Select the version: ~> 0.14.1
4. Click Add Package

## Speech Capabilities

Janet now includes speech capabilities that allow you to:

1. Convert your spoken words to text (Speech-to-Text)
2. Have Janet speak responses aloud (Text-to-Speech)

### Using Speech Features

- **Speech Interface**: Access the dedicated speech interface by clicking the "Speech" tab in the sidebar.
- **Voice Commands**: Use the microphone button to start recording your voice, then send the transcribed text to Janet.
- **Text-to-Speech**: Have Janet read responses aloud by clicking the speaker button next to any assistant message.
- **Voice Settings**: Customize the voice, speech rate, and pitch in the Voice Settings panel.

### Required Permissions

When using speech features for the first time, you'll need to grant Janet permission to:
- Access your microphone
- Use speech recognition

These permissions are necessary for the speech-to-text functionality to work properly.

## Troubleshooting

### Entitlements Issues

If you encounter an error related to the Janet.entitlements file when building in Xcode, follow these steps:

1. Run the automated fix script:
   ```
   cd /Volumes/Folk_DAS/Janet_Clean && ./fix_entitlements.sh
   ```

2. If the automated script doesn't resolve the issue, try these manual steps:
   - Make sure the Janet.entitlements file is properly located in the Janet directory
   - If the file is missing, you can copy it from the root directory:
     ```
     cp /Volumes/Folk_DAS/Janet_Clean/Janet.entitlements /Volumes/Folk_DAS/Janet_Clean/Janet/
     ```
   - Verify that the entitlements file has the correct permissions by checking the project settings:
     - Open the project settings
     - Select the "Janet" target
     - Go to the "Signing & Capabilities" tab
     - Ensure the entitlements file is correctly referenced

If you continue to have issues, try cleaning the build folder (Product > Clean Build Folder) and rebuilding the project.
