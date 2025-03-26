import SwiftUI
import AVFoundation

struct EnhancedSpeechView: View {
    @EnvironmentObject private var speechService: SpeechService
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var memoryManager: MemoryManager
    
    // State variables
    @State private var speechText: String = ""
    @State private var isSpeaking: Bool = false
    @State private var selectedVoice: String = "Samantha"
    @State private var speechRate: Float = 0.5
    @State private var speechPitch: Float = 1.0
    @State private var recentCommands: [String] = []
    @State private var showVoicePreview: Bool = false
    @State private var previewText: String = "Hello, I'm Janet. How can I help you today?"
    @State private var waveformValues: [CGFloat] = Array(repeating: 0.1, count: 30)
    @State private var waveformTimer: Timer?
    @State private var availableVoices: [String] = []
    
    // UI State
    @State private var selectedTab: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content
            TabView(selection: $selectedTab) {
                // Speech tab
                speechTab
                    .tag(0)
                
                // Voice settings tab
                voiceSettingsTab
                    .tag(1)
                
                // History tab
                historyTab
                    .tag(2)
            }
            .tabViewStyle(DefaultTabViewStyle())
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
        )
        .onAppear {
            loadAvailableVoices()
            loadRecentCommands()
        }
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        HStack {
            Button(action: {
                navigationState.navigateToHome()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Enhanced Speech")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Speech").tag(0)
                Text("Voices").tag(1)
                Text("History").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 300)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
    
    private var speechTab: some View {
        VStack(spacing: 20) {
            // Waveform visualization
            waveformView
                .frame(height: 100)
                .padding(.horizontal)
            
            // Text input
            VStack(alignment: .leading, spacing: 8) {
                Text("Text to Speak")
                    .font(.headline)
                
                TextEditor(text: $speechText)
                    .frame(height: 150)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {
                    clearText()
                }) {
                    Label("Clear", systemImage: "xmark.circle")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(speechText.isEmpty)
                
                Button(action: {
                    if isSpeaking {
                        stopSpeaking()
                    } else {
                        startSpeaking()
                    }
                }) {
                    Label(isSpeaking ? "Stop" : "Speak", systemImage: isSpeaking ? "stop.fill" : "play.fill")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(isSpeaking ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(speechText.isEmpty)
                
                Button(action: {
                    saveToMemory()
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(speechText.isEmpty)
            }
            .padding()
            
            // Quick suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Suggestions")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        quickSuggestionButton("Hello, how are you?")
                        quickSuggestionButton("What's the weather like today?")
                        quickSuggestionButton("Tell me a joke")
                        quickSuggestionButton("What time is it?")
                        quickSuggestionButton("Read my latest email")
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    private var voiceSettingsTab: some View {
        VStack(spacing: 20) {
            // Voice selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Voice")
                    .font(.headline)
                
                Picker("Voice", selection: $selectedVoice) {
                    ForEach(availableVoices, id: \.self) { voice in
                        Text(voice).tag(voice)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedVoice) { oldValue, newValue in
                    speechService.setVoice(newValue)
                }
            }
            .padding(.horizontal)
            
            // Speech rate
            VStack(alignment: .leading, spacing: 8) {
                Text("Speech Rate: \(String(format: "%.1f", speechRate))")
                    .font(.headline)
                
                Slider(value: $speechRate, in: 0.1...1.0, step: 0.1)
                    .onChange(of: speechRate) { oldValue, newValue in
                        speechService.setSpeechRate(newValue)
                    }
            }
            .padding(.horizontal)
            
            // Speech pitch
            VStack(alignment: .leading, spacing: 8) {
                Text("Speech Pitch: \(String(format: "%.1f", speechPitch))")
                    .font(.headline)
                
                Slider(value: $speechPitch, in: 0.5...2.0, step: 0.1)
                    .onChange(of: speechPitch) { oldValue, newValue in
                        speechService.setSpeechPitch(newValue)
                    }
            }
            .padding(.horizontal)
            
            // Voice preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Preview")
                    .font(.headline)
                
                TextEditor(text: $previewText)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Button(action: {
                    previewVoice()
                }) {
                    Label("Preview Voice", systemImage: "play.circle")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    private var historyTab: some View {
        VStack(spacing: 16) {
            Text("Recent Speech Commands")
                .font(.headline)
                .padding(.top)
            
            if recentCommands.isEmpty {
                Text("No recent commands")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(recentCommands, id: \.self) { command in
                        HStack {
                            Text(command)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            Button(action: {
                                speechText = command
                                selectedTab = 0
                            }) {
                                Image(systemName: "text.badge.plus")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                speechService.speak(command)
                                startWaveformAnimation()
                            }) {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        recentCommands.remove(atOffsets: indexSet)
                        saveRecentCommands()
                    }
                }
            }
            
            Button(action: {
                recentCommands.removeAll()
                saveRecentCommands()
            }) {
                Label("Clear History", systemImage: "trash")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Helper Methods
    
    // Load available voices from the speech service
    private func loadAvailableVoices() {
        // Get voice identifiers from the speech service
        availableVoices = speechService.availableVoices.map { $0.name }
        
        // Set default voice if available
        if let defaultVoice = speechService.availableVoices.first(where: { $0.name == "Samantha" }) {
            selectedVoice = defaultVoice.name
            speechService.setVoice(selectedVoice)
        } else if let firstVoice = speechService.availableVoices.first {
            selectedVoice = firstVoice.name
            speechService.setVoice(selectedVoice)
        }
        
        // Set initial speech rate and pitch
        speechService.setSpeechRate(speechRate)
        speechService.setSpeechPitch(speechPitch)
    }
    
    // Load recent commands from UserDefaults
    private func loadRecentCommands() {
        if let savedCommands = UserDefaults.standard.stringArray(forKey: "recentSpeechCommands") {
            recentCommands = savedCommands
        }
    }
    
    // Save recent commands to UserDefaults
    private func saveRecentCommands() {
        UserDefaults.standard.set(recentCommands, forKey: "recentSpeechCommands")
    }
    
    // Clear the text input
    private func clearText() {
        speechText = ""
    }
    
    // Start speaking the text
    private func startSpeaking() {
        guard !speechText.isEmpty else { return }
        
        // Add to recent commands if not already present
        if !recentCommands.contains(speechText) {
            recentCommands.insert(speechText, at: 0)
            if recentCommands.count > 10 {
                recentCommands.removeLast()
            }
            saveRecentCommands()
        }
        
        // Start speaking
        speechService.speak(speechText)
        
        // Update UI state on main thread
        DispatchQueue.main.async {
            self.isSpeaking = true
            // Start waveform animation
            self.startWaveformAnimation()
        }
    }
    
    // Stop speaking
    private func stopSpeaking() {
        speechService.stopSpeaking()
        
        // Update UI state on main thread
        DispatchQueue.main.async {
            self.isSpeaking = false
            // Stop waveform animation
            self.waveformTimer?.invalidate()
            self.waveformTimer = nil
        }
    }
    
    // Save text to memory
    private func saveToMemory() {
        guard !speechText.isEmpty else { return }
        
        // Add to memory manager
        memoryManager.addMessage(speechText, isUser: false)
        
        // Show confirmation
        // In a real app, you might want to show a toast or alert here
    }
    
    // Create a quick suggestion button
    private func quickSuggestionButton(_ text: String) -> some View {
        Button(action: {
            speechText = text
        }) {
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Preview the selected voice
    private func previewVoice() {
        speechService.speak(previewText)
        startWaveformAnimation()
    }
    
    // Start waveform animation
    private func startWaveformAnimation() {
        // Ensure we're on the main thread for UI updates
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.startWaveformAnimation()
            }
            return
        }
        
        // Stop any existing animation
        waveformTimer?.invalidate()
        
        // Create a new timer that updates the waveform values
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Ensure UI updates happen on main thread
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.1)) {
                    // Generate random waveform values
                    for i in 0..<self.waveformValues.count {
                        if self.speechService.isSpeaking {
                            self.waveformValues[i] = CGFloat.random(in: 0.1...1.0)
                        } else {
                            self.waveformValues[i] = 0.1
                        }
                    }
                }
                
                // Stop the animation if speech has stopped
                if !self.speechService.isSpeaking {
                    self.isSpeaking = false
                    self.waveformTimer?.invalidate()
                    self.waveformTimer = nil
                }
            }
        }
    }
    
    // Waveform visualization
    private var waveformView: some View {
        HStack(spacing: 4) {
            ForEach(0..<waveformValues.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 4, height: waveformValues[index] * 80)
                    .animation(.linear(duration: 0.1), value: waveformValues[index])
            }
        }
        .frame(height: 80)
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(12)
    }
}
