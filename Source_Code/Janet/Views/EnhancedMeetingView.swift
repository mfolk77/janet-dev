import SwiftUI
import AVFoundation
import Combine

struct EnhancedMeetingView: View {
    // Environment objects
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var memoryManager: MemoryManager
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    
    // State variables for meeting management
    @State private var meetingTitle: String = ""
    @State private var meetingNotes: String = ""
    @State private var isRecording: Bool = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var shouldSaveToNotion: Bool = false
    @State private var highlightedPoints: [HighlightedPoint] = []
    @State private var selectedCategory: HighlightCategory = .action
    @State private var newHighlightText: String = ""
    @State private var showingHighlightInput: Bool = false
    @State private var autoSaveTimer: Timer?
    @State private var lastAutoSaveTime: Date?
    @State private var transcriptionText: String = ""
    @State private var meetingParticipants: String = ""
    @State private var showMeetingSetup: Bool = true
    @State private var showSummaryView: Bool = false
    @State private var meetingSummary: String = ""
    @State private var isGeneratingSummary: Bool = false
    
    // Audio recording properties
    private let audioEngine = AVAudioEngine()
    // Use NSSpeechRecognizer instead of SFSpeechRecognizer for macOS
    private let speechRecognizer = NSSpeechRecognizer()
    // These are not needed for macOS
    // private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    // private var recognitionTask: SFSpeechRecognitionTask?
    // private let audioSession = AVAudioSession.sharedInstance()
    
    // Formatter for time display
    private let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            if showMeetingSetup {
                meetingSetupView
            } else if showSummaryView {
                meetingSummaryView
            } else {
                // Active meeting view
                activeMeetingView
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
        )
        .onDisappear {
            stopRecording()
            stopAutoSave()
        }
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        HStack {
            Button(action: {
                if isRecording {
                    // Show confirmation dialog
                    // This would be implemented with an alert in a real app
                    stopRecording()
                }
                navigationState.navigateToHome()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(showMeetingSetup ? "New Meeting" : (showSummaryView ? "Meeting Summary" : meetingTitle))
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
            
            Spacer()
            
            if isRecording {
                // Recording indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.5)
                    
                    Text(timeFormatter.string(from: recordingTime) ?? "00:00:00")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
    
    private var meetingSetupView: some View {
        VStack(spacing: 20) {
            Form {
                Section(header: Text("Meeting Details")) {
                    TextField("Meeting Title", text: $meetingTitle)
                    
                    TextField("Participants (optional)", text: $meetingParticipants)
                    
                    Toggle("Save to Notion", isOn: $shouldSaveToNotion)
                }
                
                Section(header: Text("Meeting Options")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-save Interval")
                        
                        Picker("Auto-save Interval", selection: .constant(2)) {
                            Text("30 seconds").tag(0)
                            Text("1 minute").tag(1)
                            Text("2 minutes").tag(2)
                            Text("5 minutes").tag(3)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription Language")
                        
                        Picker("Language", selection: .constant("English (US)")) {
                            Text("English (US)").tag("English (US)")
                            Text("English (UK)").tag("English (UK)")
                            Text("Spanish").tag("Spanish")
                            Text("French").tag("French")
                            Text("German").tag("German")
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Section {
                    Button(action: {
                        startMeeting()
                    }) {
                        Text("Start Meeting")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(meetingTitle.isEmpty ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(meetingTitle.isEmpty)
                }
            }
            .padding()
        }
    }
    
    private var activeMeetingView: some View {
        VStack(spacing: 0) {
            // Tabs for transcription and notes
            Picker("View", selection: .constant(0)) {
                Text("Transcription").tag(0)
                Text("Notes").tag(1)
                Text("Highlights").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Main content area
            VStack(spacing: 16) {
                // Transcription view
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(transcriptionText)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Highlighted points
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Highlighted Points")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showingHighlightInput.toggle()
                        }) {
                            Image(systemName: showingHighlightInput ? "minus.circle.fill" : "plus.circle.fill")
                                .foregroundColor(showingHighlightInput ? .red : .blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if showingHighlightInput {
                        HStack {
                            TextField("Add highlight...", text: $newHighlightText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(HighlightCategory.allCases, id: \.self) { category in
                                    Text(category.rawValue).tag(category)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 120)
                            
                            Button(action: {
                                addHighlight()
                            }) {
                                Text("Add")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(newHighlightText.isEmpty)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(highlightedPoints) { point in
                                HighlightedPointView(point: point) {
                                    removeHighlight(point)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal)
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        Label(isRecording ? "Stop Recording" : "Start Recording", systemImage: isRecording ? "stop.fill" : "record.circle")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(isRecording ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        saveNotes()
                    }) {
                        Label("Save Notes", systemImage: "square.and.arrow.down")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        generateSummary()
                    }) {
                        Label("Generate Summary", systemImage: "text.badge.checkmark")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
        }
    }
    
    private var meetingSummaryView: some View {
        VStack(spacing: 16) {
            if isGeneratingSummary {
                ProgressView("Generating summary...")
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Meeting details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meeting Details")
                                .font(.headline)
                            
                            HStack {
                                Text("Title:")
                                    .fontWeight(.semibold)
                                Text(meetingTitle)
                            }
                            
                            if !meetingParticipants.isEmpty {
                                HStack {
                                    Text("Participants:")
                                        .fontWeight(.semibold)
                                    Text(meetingParticipants)
                                }
                            }
                            
                            HStack {
                                Text("Duration:")
                                    .fontWeight(.semibold)
                                Text(timeFormatter.string(from: recordingTime) ?? "00:00:00")
                            }
                        }
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.headline)
                            
                            Text(meetingSummary)
                                .lineSpacing(1.2)
                        }
                        .padding()
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Key points
                        if !highlightedPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Key Points")
                                    .font(.headline)
                                
                                ForEach(HighlightCategory.allCases, id: \.self) { category in
                                    let pointsInCategory = highlightedPoints.filter { $0.category == category }
                                    if !pointsInCategory.isEmpty {
                                        Text(category.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(category.color)
                                        
                                        ForEach(pointsInCategory) { point in
                                            HStack(alignment: .top) {
                                                Text("•")
                                                Text(point.text)
                                            }
                                            .padding(.leading, 8)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: {
                        // Return to active meeting
                        showSummaryView = false
                    }) {
                        Label("Back to Meeting", systemImage: "arrow.left")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        // Export summary
                        exportSummary()
                    }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startMeeting() {
        showMeetingSetup = false
        startRecording()
        startAutoSave()
    }
    
    private func startRecording() {
        // Ensure we're on the main thread for UI updates
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.startRecording()
            }
            return
        }
        
        isRecording = true
        
        // Start timer for recording duration on the main thread
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.recordingTime += 1
        }
        
        // Here would be the actual audio recording and transcription code
        // This is a simplified version
        
        // Request permission for speech recognition
        // SFSpeechRecognizer.requestAuthorization { status in
        //     // Handle authorization status
        // }
        
        // In a real implementation, we would set up the audio engine and speech recognition
    }
    
    private func stopRecording() {
        // Ensure we're on the main thread for UI updates
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.stopRecording()
            }
            return
        }
        
        isRecording = false
        
        // Invalidate timer safely
        if let timer = timer {
            timer.invalidate()
        }
        self.timer = nil
        
        // Stop audio recording and transcription
        // This is a simplified version
    }
    
    private func startAutoSave() {
        // Ensure we're on the main thread for timer creation
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.startAutoSave()
            }
            return
        }
        
        // Auto-save every 2 minutes
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { _ in
            self.saveNotes()
            self.lastAutoSaveTime = Date()
        }
    }
    
    private func stopAutoSave() {
        // Ensure we're on the main thread for timer invalidation
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.stopAutoSave()
            }
            return
        }
        
        // Invalidate timer safely
        if let timer = autoSaveTimer {
            timer.invalidate()
        }
        autoSaveTimer = nil
    }
    
    private func saveNotes() {
        // Create a dedicated queue for file operations
        let fileQueue = DispatchQueue(label: "com.janet.fileoperations", qos: .background)
        
        fileQueue.async {
            // Save notes to storage
            // This is a simplified version
            
            // If Notion integration is enabled, save to Notion
            if self.shouldSaveToNotion {
                // Save to Notion
                // This would require actual Notion API integration
            }
            
            // Update UI on main thread if needed
            DispatchQueue.main.async {
                // Update UI elements if needed
            }
        }
    }
    
    private func addHighlight() {
        guard !newHighlightText.isEmpty else { return }
        
        let newPoint = HighlightedPoint(
            id: UUID(),
            text: newHighlightText,
            category: selectedCategory,
            timestamp: Date()
        )
        
        highlightedPoints.append(newPoint)
        newHighlightText = ""
    }
    
    private func removeHighlight(_ point: HighlightedPoint) {
        highlightedPoints.removeAll { $0.id == point.id }
    }
    
    private func generateSummary() {
        isGeneratingSummary = true
        showSummaryView = true
        
        // In a real implementation, we would use the model orchestrator to generate a summary
        // This is a simplified version
        
        // Simulate summary generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            meetingSummary = """
            This meeting covered several key topics related to the project timeline and resource allocation. The team discussed the current progress on the mobile app development, with a focus on UI improvements and backend integration.
            
            Key decisions were made regarding the project timeline, with agreement to extend the beta testing phase by two weeks to address user feedback more thoroughly. Resource allocation was adjusted to prioritize the backend integration work.
            
            Action items were assigned to team members with specific deadlines, and a follow-up meeting was scheduled for next week to review progress.
            """
            
            isGeneratingSummary = false
        }
    }
    
    private func exportSummary() {
        // Export summary to file or share
        // This is a simplified version
    }
}

// MARK: - Highlighted Point

struct HighlightedPoint: Identifiable {
    let id: UUID
    let text: String
    let category: HighlightCategory
    let timestamp: Date
}

enum HighlightCategory: String, CaseIterable {
    case action = "Action Item"
    case decision = "Decision"
    case question = "Question"
    case idea = "Idea"
    case important = "Important"
    
    var color: Color {
        switch self {
        case .action: return .green
        case .decision: return .blue
        case .question: return .orange
        case .idea: return .purple
        case .important: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .action: return "checkmark.circle"
        case .decision: return "hand.thumbsup"
        case .question: return "questionmark.circle"
        case .idea: return "lightbulb"
        case .important: return "exclamationmark.circle"
        }
    }
}

// MARK: - Highlighted Point View

struct HighlightedPointView: View {
    let point: HighlightedPoint
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: point.category.icon)
                    .foregroundColor(point.category.color)
                
                Text(point.category.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(point.category.color)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Text(point.text)
                .font(.subheadline)
                .lineLimit(2)
            
            Text(formatTime(point.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(width: 200)
        .background(point.category.color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(point.category.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EnhancedMeetingView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedMeetingView()
            .environmentObject(NavigationState())
            .environmentObject(MemoryManager())
            .environmentObject(ModelOrchestrator.shared)
    }
}