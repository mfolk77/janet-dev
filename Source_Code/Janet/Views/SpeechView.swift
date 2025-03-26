import SwiftUI
import AVFoundation

struct SpeechView: View {
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var ollamaService: OllamaService
    @State private var textToSpeak: String = ""
    @State private var showVoiceSettings: Bool = false
    @State private var isProcessingVoiceCommand: Bool = false
    
    var body: some View {
        mainContent
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            // Header
            Text("Speech Interface")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Speech-to-Text Section
            speechToTextSection
            
            // Text-to-Speech Section
            textToSpeechSection
            
            // Voice Command Section
            voiceCommandSection
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showVoiceSettings) {
            VoiceSettingsView()
        }
    }
    
    private var speechToTextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Speech Recognition")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    speechService.resetRecognizedText()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                Text(speechService.recognizedText)
                    .padding()
                    .frame(minHeight: 100)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 150)
            
            HStack {
                Button(action: {
                    if speechService.isListening {
                        speechService.stopListening()
                    } else {
                        speechService.startListening()
                    }
                }) {
                    Label(
                        speechService.isListening ? "Stop Listening" : "Start Listening",
                        systemImage: speechService.isListening ? "mic.slash.fill" : "mic.fill"
                    )
                    .foregroundColor(speechService.isListening ? .red : .green)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if speechService.isListening {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.green)
                                .frame(width: 3, height: CGFloat.random(in: 5...20))
                                .animation(
                                    Animation.easeInOut(duration: 0.2)
                                        .repeatForever()
                                        .delay(0.1 * Double(i)),
                                    value: speechService.isListening
                                )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var textToSpeechSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Text-to-Speech")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showVoiceSettings = true
                }) {
                    Label("Voice Settings", systemImage: "gear")
                }
                .buttonStyle(.bordered)
            }
            
            TextEditor(text: $textToSpeak)
                .frame(height: 100)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            HStack {
                Button(action: {
                    if speechService.isSpeaking {
                        speechService.stopSpeaking()
                    } else if !textToSpeak.isEmpty {
                        speechService.speak(textToSpeak)
                    }
                }) {
                    Label(
                        speechService.isSpeaking ? "Stop Speaking" : "Speak Text",
                        systemImage: speechService.isSpeaking ? "stop.fill" : "play.fill"
                    )
                    .foregroundColor(speechService.isSpeaking ? .red : .blue)
                }
                .buttonStyle(.bordered)
                .disabled(textToSpeak.isEmpty && !speechService.isSpeaking)
                
                Spacer()
                
                if speechService.isSpeaking {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                                .scaleEffect(speechService.isSpeaking ? 1.0 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 0.5)
                                        .repeatForever()
                                        .delay(0.15 * Double(i)),
                                    value: speechService.isSpeaking
                                )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var voiceCommandSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice Commands")
                .font(.headline)
            
            Text("Try saying: \"Janet, what's the weather today?\" or \"Janet, tell me a joke\"")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                processVoiceCommand()
            }) {
                Label("Process Last Speech as Command", systemImage: "wand.and.stars")
                    .foregroundColor(.purple)
            }
            .buttonStyle(.bordered)
            .disabled(speechService.recognizedText.isEmpty || isProcessingVoiceCommand)
            
            if isProcessingVoiceCommand {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Text("Processing command...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 5)
                }
                .padding(.top, 5)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func processVoiceCommand() {
        guard !speechService.recognizedText.isEmpty else { return }
        
        isProcessingVoiceCommand = true
        
        var command = speechService.recognizedText
        if let range = command.range(of: "Janet,", options: .caseInsensitive) {
            command = String(command[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        Task {
            let response = await ollamaService.generateResponse(prompt: "User command: \(command)\n\nRespond conversationally as Janet, a helpful AI assistant.")
            await MainActor.run {
                textToSpeak = response
                speechService.speak(response)
                isProcessingVoiceCommand = false
            }
        }
    }
}

struct VoiceSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var speechService: SpeechService
    @State private var selectedVoiceID: String = ""
    @State private var speechRate: Float = 0.5
    @State private var speechPitch: Float = 1.0
    @State private var previewText: String = "Hello, I am Janet, your AI assistant."
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voice Selection")) {
                    Picker("Voice", selection: $selectedVoiceID) {
                        ForEach(speechService.availableVoices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                    .onChange(of: selectedVoiceID) { _, newValue in
                        speechService.selectedVoice = newValue
                    }
                }
                
                Section(header: Text("Speech Rate")) {
                    Slider(value: $speechRate, in: 0.1...1.0, step: 0.1)
                        .onChange(of: speechRate) { _, newValue in
                            speechService.speechRate = newValue
                        }
                    
                    Text("Rate: \(speechRate, specifier: "%.1f")x")
                        .font(.caption)
                }
                
                Section(header: Text("Speech Pitch")) {
                    Slider(value: $speechPitch, in: 0.5...2.0, step: 0.1)
                        .onChange(of: speechPitch) { _, newValue in
                            speechService.speechPitch = newValue
                        }
                    
                    Text("Pitch: \(speechPitch, specifier: "%.1f")")
                        .font(.caption)
                }
                
                Section(header: Text("Preview")) {
                    TextField("Preview Text", text: $previewText)
                    
                    Button(action: {
                        speechService.speak(previewText)
                    }) {
                        Label("Preview Voice", systemImage: "play.circle")
                    }
                    .disabled(speechService.isSpeaking)
                }
            }
            .navigationTitle("Voice Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                selectedVoiceID = speechService.selectedVoice
                speechRate = speechService.speechRate
                speechPitch = speechService.speechPitch
            }
        }
    }
}

struct SpeechView_Previews: PreviewProvider {
    static var previews: some View {
        SpeechView()
            .environmentObject(SpeechService())
            .environmentObject(OllamaService())
    }
} 