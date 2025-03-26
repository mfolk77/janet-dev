import SwiftUI

// MARK: - ChatView
struct ChatView: View {
    @ObservedObject var modelManager = ModelManager.shared
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var memoryManager: MemoryManager
    @EnvironmentObject private var notionMemory: NotionMemory
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    @State private var userInput: String = ""
    @State private var isGenerating: Bool = false
    @State private var showingHomeConfirmation: Bool = false
    @FocusState private var isInputFocused: Bool
    
    // Enhanced memory manager
    private let enhancedMemory = EnhancedMemoryManager.shared
    
    var body: some View {
        // Break up the complex expression into simpler parts
        mainContent
    }
    
    // Main content view
    private var mainContent: some View {
        VStack(spacing: 16) {
            headerView
            messagesArea
            inputArea
        }
        .padding(.bottom, 20) // Add extra bottom padding to prevent content from being cut off
        .padding([.horizontal, .top])
        .onAppear(perform: onAppear)
        .alert("Return to Home", isPresented: $showingHomeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Chat", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    memoryManager.clearConversation()
                    navigationState.navigateToHome()
                }
            }
        } message: {
            Text("Are you sure you want to clear the current chat and return to the home screen?")
        }
    }
    
    // Header view
    private var headerView: some View {
        HStack {
            Text("Janet")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Home button
            ChatHomeButton(messages: $memoryManager.currentConversation.messages, showConfirmation: $showingHomeConfirmation)
                .padding(.trailing, 8)
            
            // Model status indicator
            Circle()
                .fill(modelManager.isLoaded ? Color.green : Color.yellow)
                .frame(width: 12, height: 12)
            
            Text(modelManager.isLoaded ? "Model Ready" : "Loading Model")
                .font(.caption)
        }
        .padding()
    }
    
    // Messages area
    private var messagesArea: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack(alignment: .center, spacing: 12) {
                    // Welcome message (only shown when no messages)
                    if memoryManager.currentConversation.messages.isEmpty {
                        welcomeMessage
                    }
                    
                    // Chat messages
                    ForEach(memoryManager.currentConversation.messages) { message in
                        ChatMessageView(message: message)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .id(message.id)
                    }
                    
                    // Show loading indicator when generating a response
                    if isGenerating {
                        loadingIndicator
                    }
                }
                .padding()
            }
            .onChange(of: memoryManager.currentConversation.messages.count) { oldCount, newCount in
                if let lastMessage = memoryManager.currentConversation.messages.last {
                    withAnimation {
                        scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            // Make the conversation box larger
            .frame(minHeight: 600)
            .background(Color(NSColor.underPageBackgroundColor))
            .cornerRadius(12)
            .padding()
        }
    }
    
    // Welcome message
    private var welcomeMessage: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.bottom, 10)
            
            Text("Welcome to Janet")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Powered by Phi-4 Multimodal")
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("A proud product of FolktechAI")
                .font(.title3)
                .foregroundColor(.gray)
            
            Text("Ask me anything or share images to get started!")
                .font(.headline)
                .padding(.top, 10)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 300)
        .padding()
    }
    
    // Loading indicator
    private var loadingIndicator: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text("Janet is thinking")
                        .foregroundColor(.white)
                    
                    // Animated dots
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .opacity(0.5)
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(0.2 * Double(i)),
                                value: isGenerating
                            )
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.7))
                .cornerRadius(16)
                
                Text(formatTimestamp(Date()))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            Spacer()
        }
    }
    
    // Input area
    private var inputArea: some View {
        HStack(alignment: .center) {
            // Use TextField for better keyboard support
            TextField("Ask a question...", text: $userInput)
                .padding(10)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .disabled(isGenerating)
                .focused($isInputFocused)
                .submitLabel(.send) // Use send as the submit label
                .onSubmit {
                    if !userInput.isEmpty && !isGenerating {
                        sendMessage()
                    }
                }
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundColor(userInput.isEmpty || isGenerating ? .gray : .blue)
            }
            .disabled(userInput.isEmpty || isGenerating)
            // Make the button at least 44x44 for better touch targets
            .frame(width: 44, height: 44)
        }
        .padding()
    }
    
    // On appear handler
    private func onAppear() {
        // Focus the text field when the view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isInputFocused = true
        }
        
        // Set orchestrator to auto mode
        modelOrchestrator.executionMode = .auto
        
        // Load Notion items when the view appears
        if notionMemory.isEnabled && notionMemory.notionItems.isEmpty {
            Task {
                do {
                    try await notionMemory.fetchNotionItems()
                    print("🔍 JANET_DEBUG: Loaded \(notionMemory.notionItems.count) items from Notion")
                } catch {
                    print("🔍 JANET_DEBUG: Failed to load Notion items: \(error)")
                }
            }
        }
        
        // Set up a paste board change notification
        #if os(macOS)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                if isInputFocused {
                    if let clipboardString = NSPasteboard.general.string(forType: .string) {
                        userInput += clipboardString
                    }
                    return nil // Consume the event
                }
            }
            return event
        }
        #endif
    }
    
    private func sendMessage() {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating else { return }
        
        // Create a new message from the user input
        let userMessage = Janet.Models.Message(
            id: UUID().uuidString,
            content: userInput,
            timestamp: Date(),
            isUserMessage: true
        )
        
        // Add to memory manager
        memoryManager.addMessage(userMessage.content, isUser: true)
        
        let userPrompt = userInput
        userInput = ""
        isGenerating = true
        
        // Get context from vector memory
        let vectorMemoryContext = enhancedMemory.getMemoryContext(for: userPrompt)
        
        // Prepare context from Notion if available
        var contextPrompt = userPrompt
        
        // Add vector memory context if available
        if !vectorMemoryContext.isEmpty {
            contextPrompt = """
            \(vectorMemoryContext)
            
            User question: \(userPrompt)
            """
            print("🔍 JANET_DEBUG: Added vector memory context to prompt")
        }
        // If no vector memory context, try Notion context
        else if notionMemory.isEnabled && !notionMemory.notionItems.isEmpty {
            // Find relevant Notion items
            let relevantItems = findRelevantNotionItems(for: userPrompt)
            if !relevantItems.isEmpty {
                let notionContext = relevantItems.map { "- \($0.title): \($0.content)" }.joined(separator: "\n")
                contextPrompt = """
                I have some relevant information from my Notion database that might help answer this question:
                
                \(notionContext)
                
                User question: \(userPrompt)
                """
                print("🔍 JANET_DEBUG: Added Notion context to prompt")
            }
        }
        
        // Always use the orchestrator
        sendMessageWithOrchestrator(contextPrompt)
    }
    
    private func sendMessageWithOrchestrator(_ prompt: String) {
        print("🎭 JANET_DEBUG: Using orchestrator to process message")
        
        // Execute the task using the orchestrator
        Task {
            do {
                let result = try await modelOrchestrator.generateText(prompt: prompt, taskType: .general)
                
                DispatchQueue.main.async {
                    let assistantMessage = Janet.Models.Message(
                        id: UUID().uuidString,
                        content: result,
                        timestamp: Date(),
                        isUserMessage: false
                    )
                    
                    self.memoryManager.addMessage(assistantMessage.content, isUser: false)
                    self.isGenerating = false
                    self.isInputFocused = true
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMessage = "Sorry, I couldn't process your request: \(error.localizedDescription)"
                    
                    let assistantMessage = Janet.Models.Message(
                        id: UUID().uuidString,
                        content: errorMessage,
                        timestamp: Date(),
                        isUserMessage: false
                    )
                    
                    self.memoryManager.addMessage(assistantMessage.content, isUser: false)
                    self.isGenerating = false
                    self.isInputFocused = true
                }
            }
        }
    }
    
    // This method is kept for backward compatibility but is no longer used
    private func sendMessageWithDirectModel(_ prompt: String) {
        Task {
            do {
                let response = try await modelManager.generateText(prompt: prompt)
                
                DispatchQueue.main.async {
                    let assistantMessage = Janet.Models.Message(
                        id: UUID().uuidString,
                        content: response,
                        timestamp: Date(),
                        isUserMessage: false
                    )
                    
                    // Add to memory manager
                    memoryManager.addMessage(assistantMessage.content, isUser: false)
                    
                    isGenerating = false
                    // Refocus the input field after response
                    isInputFocused = true
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMessage = Janet.Models.Message(
                        id: UUID().uuidString,
                        content: "Sorry, I encountered an error: \(error.localizedDescription)",
                        timestamp: Date(),
                        isUserMessage: false
                    )
                    
                    // Add to memory manager
                    memoryManager.addMessage(errorMessage.content, isUser: false)
                    
                    isGenerating = false
                    // Refocus the input field after error
                    isInputFocused = true
                }
            }
        }
    }
    
    // Helper function to format timestamps
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper function to find relevant Notion items for a query
    private func findRelevantNotionItems(for query: String) -> [NotionItem] {
        // Simple keyword matching for now
        let keywords = query.lowercased().split(separator: " ")
            .filter { $0.count > 3 } // Only consider words with more than 3 characters
            .map { String($0) }
        
        if keywords.isEmpty {
            return []
        }
        
        // Score each Notion item based on keyword matches
        var scoredItems: [(item: NotionItem, score: Int)] = []
        
        for item in notionMemory.notionItems {
            let title = item.title.lowercased()
            let content = item.content.lowercased()
            var score = 0
            
            for keyword in keywords {
                if title.contains(keyword) {
                    score += 3 // Higher weight for title matches
                }
                if content.contains(keyword) {
                    score += 1
                }
            }
            
            if score > 0 {
                scoredItems.append((item, score))
            }
        }
        
        // Sort by score and take top 3
        let sortedItems = scoredItems.sorted { $0.score > $1.score }
        let topItems = sortedItems.prefix(3).map { $0.item }
        
        return Array(topItems)
    }
}

// MARK: - ChatHomeButton
struct ChatHomeButton: View {
    @Binding var messages: [Janet.Models.Message]
    @Binding var showConfirmation: Bool
    @EnvironmentObject private var navigationState: NavigationState
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            // Animate button press
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            // Reset button press state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            
            // Show confirmation if there are messages, otherwise clear immediately
            if !messages.isEmpty {
                showConfirmation = true
            } else {
                // Clear messages with animation and navigate to home
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    messages = []
                    navigationState.navigateToHome()
                }
            }
        }) {
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundColor(isHovered ? .white : .blue)
                .padding(8)
                .background(
                    Circle()
                        .fill(isHovered ? Color.blue : Color.blue.opacity(0.1))
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .overlay(
                    isHovered && !messages.isEmpty ?
                    VStack {
                        Spacer()
                        Text("Clear chat and return home")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .offset(y: 30)
                    } : nil
                )
        }
        .buttonStyle(BorderlessButtonStyle())
        .help("Return to home screen")
        .contentShape(Circle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

struct ChatMessageView: View {
    let message: Janet.Models.Message
    @EnvironmentObject var ollamaService: OllamaService
    @EnvironmentObject var speechService: SpeechService
    @State private var isSpeaking = false
    
    var body: some View {
        VStack(alignment: message.isUserMessage ? .trailing : .leading) {
            HStack {
                if message.isUserMessage {
                    Spacer()
                }
                
                VStack(alignment: message.isUserMessage ? .trailing : .leading, spacing: 4) {
                    HStack {
                        if !message.isUserMessage {
                            Text("Janet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                        
                        Spacer()
                        
                        if message.isUserMessage {
                            Text("You")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 8)
                        }
                    }
                    
                    Text(message.content)
                        .padding(12)
                        .background(
                            BubbleShape(isUser: message.isUserMessage)
                                .fill(message.isUserMessage ? Color.blue : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(message.isUserMessage ? .white : .primary)
                        .contextMenu {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.content, forType: .string)
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            if !message.isUserMessage {
                                Button(action: {
                                    isSpeaking.toggle()
                                    if isSpeaking {
                                        speechService.speak(message.content)
                                    } else {
                                        speechService.stopSpeaking()
                                    }
                                }) {
                                    Label(isSpeaking ? "Stop Speaking" : "Speak Response", systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                                }
                            }
                        }
                }
                
                if !message.isUserMessage {
                    Spacer()
                    
                    // Add speak button for assistant messages
                    if !message.isUserMessage {
                        Button(action: {
                            isSpeaking.toggle()
                            if isSpeaking {
                                speechService.speak(message.content)
                            } else {
                                speechService.stopSpeaking()
                            }
                        }) {
                            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                                .foregroundColor(isSpeaking ? .red : .blue)
                                .padding(8)
                                .background(Circle().fill(Color.gray.opacity(0.1)))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help(isSpeaking ? "Stop Speaking" : "Speak Response")
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .onReceive(speechService.$isSpeaking) { isSpeaking in
            // Update local state when speech service state changes
            if !isSpeaking {
                self.isSpeaking = false
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
    
    // Convert to global Message type
    func toMessage() -> Message {
        return Message(
            id: self.id,
            content: self.content,
            isUser: self.isUser,
            timestamp: self.timestamp
        )
    }
    
    // Create from global Message type
    static func fromMessage(_ message: Message) -> ChatMessage {
        return ChatMessage(
            id: message.id,
            content: message.content,
            isUser: message.isUser,
            timestamp: message.timestamp
        )
    }
    
    // Create from Janet.Models.Message type
    static func fromJanetMessage(_ message: Janet.Models.Message) -> ChatMessage {
        return ChatMessage(
            id: UUID(uuidString: message.id) ?? UUID(),
            content: message.content,
            isUser: message.isUserMessage,
            timestamp: message.timestamp
        )
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading) {
                Text(message.content)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ChatView()
        .environmentObject(NavigationState())
}

