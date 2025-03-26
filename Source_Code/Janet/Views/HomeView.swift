import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject private var ollamaService: OllamaService
    @EnvironmentObject private var memoryManager: MemoryManager
    @EnvironmentObject private var commandHandler: CommandHandler
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    @EnvironmentObject private var speechService: SpeechService
    
    // State variables
    @State private var userInput: String = ""
    @State private var isProcessing: Bool = false
    @State private var showVoiceInput: Bool = false
    @State private var isListening: Bool = false
    @State private var recentCommands: [String] = []
    
    // UI State
    @State private var selectedQuickAction: QuickAction? = nil
    @State private var showSidebar: Bool = true
    
    // Theme and appearance
    @AppStorage("usesDarkMode") private var usesDarkMode: Bool = true
    @State private var accentColor: Color = .blue
    
    // Quick actions enum
    enum QuickAction: String, CaseIterable, Identifiable {
        case voiceInput = "Voice Input"
        case meetingSummary = "Meeting Summary"
        case transcription = "Transcription"
        case codeAssistant = "Code Assistant"
        case vectorSearch = "Vector Search"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .voiceInput: return "waveform"
            case .meetingSummary: return "person.2.wave.2"
            case .transcription: return "text.bubble"
            case .codeAssistant: return "chevron.left.forwardslash.chevron.right"
            case .vectorSearch: return "magnifyingglass.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .voiceInput: return .blue
            case .meetingSummary: return .green
            case .transcription: return .orange
            case .codeAssistant: return .purple
            case .vectorSearch: return .red
            }
        }
    }
    
    var body: some View {
        bodyContent
    }
    
    private var bodyContent: some View {
        VStack(spacing: 0) {
            // Header with app title and settings
            headerView
            
            // Main content area
            HStack(spacing: 0) {
                // Sidebar (collapsible)
                if showSidebar {
                    sidebarView
                        .frame(width: 250)
                        .background(Color.secondary.opacity(0.2))
                        .transition(.move(edge: .leading))
                }
                
                // Main content
                mainContentView
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    usesDarkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.8),
                    usesDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.6)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onChange(of: selectedQuickAction) { oldValue, newValue in
            handleQuickAction(newValue)
        }
        .onAppear {
            // Ensure orchestrator is in auto mode when HomeView appears
            modelOrchestrator.executionMode = .auto
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 20) {
            // Chat history display area
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(memoryManager.currentConversation.messages, id: \.id) { message in
                        MessageView(message: message)
                    }
                }
                .padding()
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            
            // Quick actions panel
            quickActionsPanel
            
            // Input area
            inputArea
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        HStack {
            // Toggle sidebar button
            Button(action: {
                withAnimation {
                    showSidebar.toggle()
                }
            }) {
                Image(systemName: showSidebar ? "sidebar.left" : "sidebar.right")
                    .foregroundColor(accentColor)
                    .padding(8)
                    .background(Color.secondary.opacity(0.5))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle sidebar")
            
            Text("Janet AI")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(usesDarkMode ? .white : .black)
            
            Spacer()
            
            // Theme toggle
            Button(action: {
                usesDarkMode.toggle()
            }) {
                Image(systemName: usesDarkMode ? "sun.max.fill" : "moon.fill")
                    .foregroundColor(usesDarkMode ? .yellow : .indigo)
                    .padding(8)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle dark/light mode")
            
            // Settings button
            Button(action: {
                navigationState.activeView = .settings
            }) {
                Image(systemName: "gear")
                    .foregroundColor(accentColor)
                    .padding(8)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Open settings")
        }
        .padding()
        .background(Color.secondary.opacity(0.2))
    }
    
    private var sidebarView: some View {
        VStack(spacing: 16) {
            // Recent conversations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Conversations")
                    .font(.headline)
                    .padding(.horizontal)
                
                Divider()
                
                if memoryManager.conversations.isEmpty {
                    Text("No saved conversations")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(memoryManager.conversations, id: \.id) { conversation in
                                Button(action: {
                                    memoryManager.switchConversation(to: conversation.id)
                                }) {
                                    HStack {
                                        Text(conversation.title)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(formatDate(conversation.createdAt))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(memoryManager.currentConversation.id == conversation.id ? 
                                                  accentColor.opacity(0.2) : Color.clear)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Divider()
            
            // Quick navigation
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Navigation")
                    .font(.headline)
                    .padding(.horizontal)
                
                Divider()
                
                Button(action: {
                    navigationState.navigateToVectorMemory()
                }) {
                    Label("Memory", systemImage: "brain.head.profile")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    navigationState.navigateToMeeting()
                }) {
                    Label("Meeting Recorder", systemImage: "person.2.wave.2")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    navigationState.navigateToSpeech()
                }) {
                    Label("Speech Recognition", systemImage: "waveform")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    navigationState.navigateToMCP()
                }) {
                    Label("MCP Status", systemImage: "server.rack")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    navigationState.navigateToCodeAssistant()
                }) {
                    Label("Code Assistant", systemImage: "chevron.left.forwardslash.chevron.right")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
            
            // Model selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Model")
                    .font(.headline)
                    .padding(.horizontal)
                
                Picker("Model", selection: $ollamaService.currentModel) {
                    ForEach(ollamaService.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                
                // Model status indicator
                HStack {
                    Circle()
                        .fill(modelOrchestrator.executionMode == .auto ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(modelOrchestrator.executionMode == .auto ? "Auto Mode" : "Manual Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .padding(.vertical)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.1))
    }
    
    private var quickActionsPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(QuickAction.allCases) { action in
                    Button(action: {
                        selectedQuickAction = action
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: action.icon)
                                .font(.system(size: 24))
                                .foregroundColor(action.color)
                            
                            Text(action.rawValue)
                                .font(.caption)
                                .foregroundColor(usesDarkMode ? .white : .black)
                        }
                        .padding()
                        .frame(width: 100, height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.windowBackgroundColor).opacity(0.5))
                                .shadow(color: action.color.opacity(0.3), radius: 5, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 120)
    }
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            // Voice input button
            Button(action: {
                toggleVoiceInput()
            }) {
                Image(systemName: isListening ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 24))
                    .foregroundColor(isListening ? .red : accentColor)
                    .animation(.easeInOut(duration: 0.2), value: isListening)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Voice input")
            
            // Text input field
            TextField("Ask Janet anything...", text: $userInput, onCommit: sendMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isProcessing)
                .overlay(
                    Group {
                        if isProcessing {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing ? .gray : accentColor)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .help("Send message")
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func sendMessage() {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let input = userInput
        userInput = ""
        isProcessing = true
        
        // Add user message to conversation
        let userMessage = Message(content: input, isUser: true)
        memoryManager.addMessage(userMessage.content, isUser: true)
        
        // Process with orchestrator (which handles model selection automatically)
        Task {
            do {
                let response = try await modelOrchestrator.processPrompt(input)
                
                // Add assistant response to conversation
                let assistantMessage = Message(content: response, isUser: false)
                
                // Check if this is a command
                let isCommand = await commandHandler.isCommand(input)
                
                // Ensure UI updates happen on the main thread
                await MainActor.run {
                    memoryManager.addMessage(assistantMessage.content, isUser: false)
                    
                    // Add to recent commands if needed
                    if isCommand {
                        addToRecentCommands(input)
                    }
                    
                    isProcessing = false
                }
            } catch {
                // Handle error
                await MainActor.run {
                    let errorMessage = Message(content: "Error: \(error.localizedDescription)", isUser: false)
                    memoryManager.addMessage(errorMessage.content, isUser: false)
                    isProcessing = false
                }
            }
        }
    }
    
    private func toggleVoiceInput() {
        // Prevent toggling while already processing
        if isProcessing {
            return
        }
        
        // Toggle state
        isListening.toggle()
        
        if isListening {
            // Start listening
            speechService.startListening { result in
                // Always update UI on main thread
                DispatchQueue.main.async {
                    switch result {
                    case .success(let transcription):
                        self.userInput = transcription
                        self.isListening = false
                        
                        // Automatically send if not empty
                        if !transcription.isEmpty {
                            self.sendMessage()
                        }
                    case .failure(let error):
                        print("Transcription error: \(error.localizedDescription)")
                        self.isListening = false
                    }
                }
            }
        } else {
            // Stop listening
            speechService.stopListening()
        }
    }
    
    private func addToRecentCommands(_ command: String) {
        // Add to recent commands, keeping only the last 5
        if !recentCommands.contains(command) {
            recentCommands.insert(command, at: 0)
            if recentCommands.count > 5 {
                recentCommands.removeLast()
            }
        }
    }
    
    private func handleQuickAction(_ action: QuickAction?) {
        guard let action = action else { return }
        
        switch action {
        case .voiceInput:
            toggleVoiceInput()
        case .meetingSummary:
            navigationState.navigateToMeeting()
        case .transcription:
            // Set up a prompt for transcription
            userInput = "Please transcribe the following audio file: "
        case .codeAssistant:
            navigationState.navigateToCodeAssistant()
        case .vectorSearch:
            navigationState.navigateToVectorMemory()
        }
        
        // Reset selection
        selectedQuickAction = nil
    }
}

// MARK: - Message View
struct MessageView: View {
    let message: Janet.Models.Message
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isUserMessage {
                // Avatar for assistant
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Circle())
            }
            
            VStack(alignment: message.isUserMessage ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding()
                    .background(
                        message.isUserMessage ?
                        Color.blue.opacity(0.2) :
                        Color.secondary.opacity(0.2)
                    )
                    .cornerRadius(12)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.isUserMessage {
                // Avatar for user
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                    .frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - Extension for ModelOrchestrator
extension ModelOrchestrator {
    // Add a computed property to check if auto mode is enabled
    var isAutoMode: Bool {
        return executionMode == .auto
    }
    
    // Add a method to process prompts
    func processPrompt(_ prompt: String) async throws -> String {
        return try await generateText(prompt: prompt, taskType: .general)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(OllamaService())
            .environmentObject(MemoryManager())
            .environmentObject(CommandHandler())
            .environmentObject(NavigationState())
            .environmentObject(ModelOrchestrator.shared)
            .environmentObject(SpeechService())
            .preferredColorScheme(.dark)
    }
}
