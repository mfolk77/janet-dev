//
//  ContentView.swift
//  Janet
//
//  Created by Michael  folk on 2/25/25.
//

//
//  ContentView.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import SwiftUI
import Combine

// Import NavigationState from Models
// We'll use the NavigationState class from Models/NavigationState.swift instead of defining it here

struct ContentView: View {
    @EnvironmentObject private var ollamaService: OllamaService
    @EnvironmentObject private var memoryManager: MemoryManager
    @EnvironmentObject private var commandHandler: CommandHandler
    @EnvironmentObject private var webhookService: WebhookService
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject var audioRecordingService: AudioRecordingService
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    @StateObject private var speechService = SpeechService()
    
    @State private var selectedTab: Int = 0
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            Sidebar(selectedTab: $selectedTab)
            
            ZStack {
                // Main content based on navigation state
                switch navigationState.activeView {
                case .home:
                    HomeView()
                case .settings:
                    HomeView()
                case .vectorMemory:
                    EnhancedVectorMemoryView()
                case .meeting:
                    EnhancedMeetingView()
                case .speech:
                    EnhancedSpeechView()
                case .codeAssistant:
                    CodeAssistantView()
                case .orchestrator:
                    OrchestratorView()
                case .stressTest:
                    HomeView()
                case .testLoop:
                    HomeView()
                case .memory:
                    MemoryView()
                case .chat:
                    ChatView()
                case .mcp:
                    MCPStatusView()
                }
            }
            
            // Debug menu (only in debug builds)
            #if DEBUG
            VStack {
                HStack {
                    Spacer()
                    
                    Menu {
                        Button("Thread Monitor") {
                            toggleThreadMonitor()
                        }
                        
                        Button("Stress Test") {
                            navigationState.activeView = .stressTest
                        }
                        
                        Button("Test Loop") {
                            navigationState.activeView = .testLoop
                        }
                        
                        Divider()
                        
                        Button("Generate Thread Report") {
                            generateThreadReport()
                        }
                    } label: {
                        Image(systemName: "ladybug")
                            .font(.system(size: 18))
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    .fixedSize()
                }
                
                Spacer()
            }
            .padding()
            #endif
        }
        .environmentObject(speechService)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Model", selection: $ollamaService.currentModel) {
                    ForEach(ollamaService.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .frame(width: 120)
                .disabled(isLoading)
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    memoryManager.clearConversation()
                }) {
                    Label("New Chat", systemImage: "plus")
                }
                .disabled(isLoading)
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    navigationState.navigateToMeeting()
                }) {
                    Label("Meeting Mode", systemImage: "person.2.wave.2")
                        .foregroundColor(.blue)
                }
                .help("Start recording and transcribing a meeting")
            }
            
            ToolbarItem(placement: .automatic) {
                // Status indicator for Ollama service
                HStack {
                    Circle()
                        .fill($ollamaService.isRunning.wrappedValue ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text($ollamaService.isRunning.wrappedValue ? "Ollama: Connected" : "Ollama: Disconnected")
                        .font(.caption)
                        .foregroundColor($ollamaService.isRunning.wrappedValue ? .green : .red)
                }
                .padding(.horizontal)
                .padding(.bottom, 5)
            }
        }
        .onAppear {
            Task {
                // Check if Ollama is running - store and use the result
                isLoading = true
                let isRunning = await ollamaService.checkOllamaStatus()
                isLoading = false
                
                // Only load models if Ollama is running
                if isRunning {
                    isLoading = true
                    await ollamaService.loadAvailableModels()
                    isLoading = false
                }
                
                // Load saved conversations in parallel
            }
        }
    }
    
    #if DEBUG
    private func toggleThreadMonitor() {
        if ThreadMonitor.shared.isMonitoringEnabled {
            ThreadMonitor.shared.stopMonitoring()
            print("Thread monitoring stopped")
        } else {
            ThreadMonitor.shared.startMonitoring()
            print("Thread monitoring started")
        }
    }
    
    private func generateThreadReport() {
        let report = ThreadMonitor.shared.getRecursiveLockReport()
        print("Thread Monitor Report:\n\(report)")
    }
    #endif
}

struct Sidebar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var memoryManager: MemoryManager
    @EnvironmentObject private var navigationState: NavigationState
    
    var body: some View {
        List {
            Text("Recent Chats")
                .font(.headline)
                .padding(.top, 5)
            
            if memoryManager.conversations.isEmpty {
                Text("No saved conversations")
                    .foregroundColor(.secondary)
                    .padding(.leading)
            } else {
                // Use a simple List with identifiable items
                ForEach(memoryManager.conversations, id: \.id) { conversation in
                    ConversationRow(conversation: conversation, onSelect: {
                        selectedTab = 0
                        memoryManager.switchConversation(to: conversation.id)
                        navigationState.activeView = .chat
                    })
                }
            }
            
            Divider()
                .padding(.vertical, 10)
            
            Button(action: {
                navigationState.activeView = .settings
            }) {
                Label("Settings", systemImage: "gear")
            }
            
            Button(action: {
                navigationState.activeView = .memory
            }) {
                Label("Memory", systemImage: "brain")
            }
            
            Button(action: {
                navigationState.navigateToVectorMemory()
            }) {
                Label("Vector Memory", systemImage: "brain.head.profile")
            }
            
            Button(action: {
                navigationState.navigateToMeeting()
            }) {
                Label("Meeting Recorder", systemImage: "person.2.wave.2")
            }
            
            Button(action: {
                navigationState.navigateToSpeech()
            }) {
                Label("Speech", systemImage: "waveform")
            }
            
            Button(action: {
                navigationState.navigateToOrchestrator()
            }) {
                Label("Orchestrator", systemImage: "cpu.fill")
            }
            
            Button(action: {
                navigationState.navigateToCodeAssistant()
            }) {
                Label("Code Assistant", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            
            Button(action: {
                navigationState.navigateToMCP()
            }) {
                Label("MCP Status", systemImage: "server.rack")
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "message")
                    .foregroundColor(.blue)
                Text(conversation.title)
                Spacer()
                Text(formatDate(conversation.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// SettingsView was moved to SettingsView.swift to avoid duplication
// Now using SettingsView2 from that file

struct MemoryView: View {
    @EnvironmentObject private var memoryManager: MemoryManager
    @EnvironmentObject private var notionMemory: NotionMemory
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        VStack {
            HStack {
                Text("Memory Management")
                    .font(.title)
                Spacer()
                
                // Home button
                HomeButton()
            }
            .padding()
            
            TabView {
                // Short-term memory
                VStack {
                    List {
                        ForEach(memoryManager.currentConversation.messages, id: \.id) { item in
                            VStack(alignment: .leading) {
                                Text(item.content)
                                    .font(.body)
                                Text(formatDate(item.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    Button("Clear Short-Term Memory") {
                        // Remove the incorrect call
                        // We need to implement a proper method in MemoryManager
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
                .tabItem {
                    Label("Short-Term", systemImage: "brain.head.profile")
                }
                
                // Medium-term memory (Notion)
                VStack {
                    if notionMemory.isEnabled {
                        List {
                            ForEach(notionMemory.notionItems, id: \.id) { item in
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.content)
                                        .font(.body)
                                    Text(formatDate(item.createdTime))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                        .listStyle(PlainListStyle())
                        
                        Button("Sync with Notion") {
                            Task {
                                do {
                                    try await notionMemory.fetchNotionItems()
                                } catch {
                                    print("Error syncing with Notion: \(error.localizedDescription)")
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding()
                    } else {
                        VStack {
                            Text("Notion Integration Not Enabled")
                                .font(.title2)
                            
                            Text("Enable Notion integration in Settings to view medium-term memory.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding()
                            
                            Button("Open Settings") {
                                // Navigate to settings (future implementation)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                }
                .tabItem {
                    Label("Medium-Term", systemImage: "doc.text")
                }
                
                // Long-term memory (JSON) - Removed as it's not available in this version
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - HomeButton
struct HomeButton: View {
    @EnvironmentObject private var navigationState: NavigationState
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: {
            // Navigate to home
            navigationState.navigateToHome()
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
        }
        .buttonStyle(BorderlessButtonStyle())
        .help("Return to home")
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

// Message bubble shape
struct BubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 18
        
        // Top left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        // Top edge and top right corner
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // Right edge and bottom right corner
        if isUser {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        
        // Bottom edge and bottom left corner
        if isUser {
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        } else {
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }
        
        // Left edge back to start
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        
        return path
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(OllamaService())
            .environmentObject(MemoryManager())
            .environmentObject(CommandHandler())
            .environmentObject(WebhookService())
            .environmentObject(NotionMemory())
            .environmentObject(NavigationState())
    }
}
