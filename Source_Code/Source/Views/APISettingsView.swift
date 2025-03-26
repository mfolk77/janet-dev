//
//  APISettingsView.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import SwiftUI

struct APISettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var notionMemory = NotionMemory()
    @State private var isNotionEnabled: Bool
    @State private var notionApiKey: String
    @State private var notionDatabaseId: String
    @State private var showingApiKeyInfo = false
    @State private var showingDatabaseIdInfo = false
    @State private var isSaved = false
    @State private var errorMessage = ""
    
    // Additional API placeholders
    @State private var isOpenAIEnabled = false
    @State private var openAIApiKey = ""
    @State private var isSlackEnabled = false
    @State private var slackApiToken = ""
    @State private var isGoogleEnabled = false
    @State private var googleApiKey = ""
    
    init() {
        let notionMemoryInstance = NotionMemory()
        self._isNotionEnabled = State(initialValue: notionMemoryInstance.isEnabled)
        self._notionApiKey = State(initialValue: notionMemoryInstance.apiKey)
        self._notionDatabaseId = State(initialValue: notionMemoryInstance.databaseId)
        self.notionMemory = notionMemoryInstance
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notion Integration")) {
                    Toggle("Enable Notion", isOn: $isNotionEnabled)
                    
                    if isNotionEnabled {
                        HStack {
                            SecureField("Notion API Key", text: $notionApiKey)
                            Button(action: {
                                showingApiKeyInfo.toggle()
                            }) {
                                Image(systemName: "info.circle")
                            }
                        }
                        
                        HStack {
                            TextField("Notion Database ID", text: $notionDatabaseId)
                            Button(action: {
                                showingDatabaseIdInfo.toggle()
                            }) {
                                Image(systemName: "info.circle")
                            }
                        }
                        
                        Button("Test Connection") {
                            testNotionConnection()
                        }
                    }
                }
                
                Section(header: Text("OpenAI Integration")) {
                    Toggle("Enable OpenAI", isOn: $isOpenAIEnabled)
                    
                    if isOpenAIEnabled {
                        SecureField("OpenAI API Key", text: $openAIApiKey)
                    }
                }
                
                Section(header: Text("Slack Integration")) {
                    Toggle("Enable Slack", isOn: $isSlackEnabled)
                    
                    if isSlackEnabled {
                        SecureField("Slack API Token", text: $slackApiToken)
                    }
                }
                
                Section(header: Text("Google Integration")) {
                    Toggle("Enable Google APIs", isOn: $isGoogleEnabled)
                    
                    if isGoogleEnabled {
                        SecureField("Google API Key", text: $googleApiKey)
                    }
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                if isSaved {
                    Section {
                        Text("Settings saved successfully!")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("API Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Save") {
                        saveSettings()
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingApiKeyInfo, content: {
                NotionAPIKeyInfoView()
                    .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity, minHeight: 500, idealHeight: 600, maxHeight: .infinity)
                    .interactiveDismissDisabled(false)
            })
            .sheet(isPresented: $showingDatabaseIdInfo, content: {
                NotionDatabaseIDInfoView()
                    .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity, minHeight: 500, idealHeight: 600, maxHeight: .infinity)
                    .interactiveDismissDisabled(false)
            })
        }
    }
    
    private func saveSettings() {
        // Save Notion settings
        notionMemory.isEnabled = isNotionEnabled
        notionMemory.apiKey = notionApiKey
        notionMemory.databaseId = notionDatabaseId
        
        // For now, just saving Notion settings
        // In the future, save other API settings here
        
        isSaved = true
        errorMessage = ""
        
        // Hide the saved message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSaved = false
        }
    }
    
    private func testNotionConnection() {
        // Create a temporary NotionMemory instance with the current values
        let testNotionMemory = NotionMemory()
        testNotionMemory.isEnabled = true
        testNotionMemory.apiKey = notionApiKey
        testNotionMemory.databaseId = notionDatabaseId
        
        Task {
            // Clear any previous error message
            await MainActor.run {
                errorMessage = ""
            }
            
            // Try to fetch items - fetchNotionItems doesn't actually throw
            do {
                try await testNotionMemory.fetchNotionItems()
                
                // If we get here, the connection was successful
                await MainActor.run {
                    isSaved = true
                    errorMessage = "Connection successful! Found \(testNotionMemory.notionItems.count) items."
                }
            } catch {
                // This catch block is now reachable since we added try
                await MainActor.run {
                    errorMessage = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct NotionAPIKeyInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Notion API Key")
                    .font(.system(size: 28))
                    .bold()
                    .padding(.bottom, 10)
                
                Text("To get your Notion API key:")
                    .font(.headline)
                    .font(.system(size: 18))
                
                // Instructions with appropriate text size
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Go to notion.so/my-integrations")
                        .font(.system(size: 16))
                    Text("2. Click 'New integration'")
                        .font(.system(size: 16))
                    Text("3. Give it a name (e.g., 'Janet')")
                        .font(.system(size: 16))
                    Text("4. Select the workspace where your database is")
                        .font(.system(size: 16))
                    Text("5. Click 'Submit'")
                        .font(.system(size: 16))
                    Text("6. Copy the 'Internal Integration Token'")
                        .font(.system(size: 16))
                }
                .padding(.bottom, 10)
                
                Text("⚠️ Keep your API key secure and never share it.")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                    .padding(.top)
                
                Spacer()
                
                // Properly sized close button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Spacer()
                        Text("Close")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .padding(30)
            .navigationTitle("Notion API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct NotionDatabaseIDInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Notion Database ID")
                    .font(.system(size: 28))
                    .bold()
                    .padding(.bottom, 10)
                
                Text("To get your Notion Database ID:")
                    .font(.headline)
                    .font(.system(size: 18))
                
                // Instructions with appropriate text size
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Open your Notion database in your browser")
                        .font(.system(size: 16))
                    Text("2. Look at the URL in your browser")
                        .font(.system(size: 16))
                    Text("3. Find the part after the last slash and before the question mark")
                        .font(.system(size: 16))
                    Text("Example: notion.so/workspace/[DATABASE_ID]?...")
                        .font(.system(size: 16))
                    Text("4. Copy the Database ID")
                        .font(.system(size: 16))
                }
                .padding(.bottom, 10)
                
                Text("Don't forget to share your database with your integration:")
                    .font(.system(size: 16))
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Open your database")
                        .font(.system(size: 16))
                    Text("2. Click 'Share' in the top right")
                        .font(.system(size: 16))
                    Text("3. Under 'Invite', find your integration name")
                        .font(.system(size: 16))
                    Text("4. Select it and click 'Invite'")
                        .font(.system(size: 16))
                }
                
                Spacer()
                
                // Properly sized close button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Spacer()
                        Text("Close")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .padding(30)
            .navigationTitle("Database ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct APISettingsView_Previews: PreviewProvider {
    static var previews: some View {
        APISettingsView()
    }
}