import SwiftUI
import AVFoundation

struct SpeechView: View {
    @EnvironmentObject var speechService: SpeechService
    @EnvironmentObject var ollamaService: OllamaService
    @State private var textToSpeak: String = ""
    @State private var showVoiceSettings: Bool = false
    @State private var isProcessingVoiceCommand: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Speech Interface")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Speech-to-Text Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Speech Recognition")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        speechService.resetRecognizedText()
                    }) {
                        Label("Clear", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(speechService.recognizedText.isEmpty)
                }
                .padding(.horizontal)
                
                ZStack(alignment: .topLeading) {
                    if speechService.recognizedText.isEmpty {
                        Text("Recognized text will appear here...")
                            .foregroundColor(.gray)
                            .padding()
                    }
                    
                    TextEditor(text: .constant(speechService.recognizedText))
                        .frame(minHeight: 100)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(true)
                }
                .padding(.horizontal)
                
                HStack {
                    Button(action: {
                        speechService.startListening()
                    }) {
                        HStack {
                            Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                                .foregroundColor(speechService.isListening ? .red : .blue)
                            Text(speechService.isListening ? "Stop Listening" : "Start Listening")
                        }
                        .frame(minWidth: 150)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        if !speechService.recognizedText.isEmpty {
                            isProcessingVoiceCommand = true
                            ollamaService.sendMessage(speechService.recognizedText) { _ in
                                isProcessingVoiceCommand = false
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send to Janet")
                        }
                        .frame(minWidth: 150)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(speechService.recognizedText.isEmpty || isProcessingVoiceCommand)
                    .opacity(speechService.recognizedText.isEmpty || isProcessingVoiceCommand ? 0.5 : 1.0)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Text-to-Speech Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Text-to-Speech")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        showVoiceSettings.toggle()
                    }) {
                        Label("Voice Settings", systemImage: "gear")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.horizontal)
                
                TextEditor(text: $textToSpeak)
                    .frame(minHeight: 100)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                HStack {
                    Button(action: {
                        if !textToSpeak.isEmpty {
                            speechService.speak(textToSpeak)
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Speak Text")
                        }
                        .frame(minWidth: 150)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(textToSpeak.isEmpty || speechService.isSpeaking)
                    .opacity(textToSpeak.isEmpty || speechService.isSpeaking ? 0.5 : 1.0)
                    
                    Spacer()
                    
                    Button(action: {
                        speechService.stopSpeaking()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop Speaking")
                        }
                        .frame(minWidth: 150)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(!speechService.isSpeaking)
                    .opacity(speechService.isSpeaking ? 1.0 : 0.5)
                }
                .padding(.horizontal)
                
                // Latest response from Janet
                if let lastMessage = ollamaService.messages.last, lastMessage.role == "assistant" {
                    HStack {
                        Spacer()
                        Button(action: {
                            textToSpeak = lastMessage.content
                        }) {
                            Label("Use Janet's Last Response", systemImage: "text.bubble")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Error message display
            if let errorMessage = speechService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showVoiceSettings) {
            VoiceSettingsView()
                .environmentObject(speechService)
        }
    }
}

struct VoiceSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var speechService: SpeechService
    @State private var selectedVoiceID: String
    @State private var speechRate: Float
    @State private var speechPitch: Float
    @State private var testText = "Hello, I am Janet. How can I help you today?"
    
    init() {
        // Initialize with default values
        _selectedVoiceID = State(initialValue: "com.apple.speech.synthesis.voice.samantha")
        _speechRate = State(initialValue: 0.5)
        _speechPitch = State(initialValue: 1.0)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voice Selection")) {
                    Picker("Voice", selection: $selectedVoiceID) {
                        ForEach(speechService.availableVoices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                    .onChange(of: selectedVoiceID) { newValue in
                        speechService.selectedVoice = newValue
                    }
                }
                
                Section(header: Text("Speech Rate")) {
                    Slider(value: $speechRate, in: 0.0...1.0, step: 0.05) {
                        Text("Rate")
                    } minimumValueLabel: {
                        Text("Slow")
                    } maximumValueLabel: {
                        Text("Fast")
                    }
                    .onChange(of: speechRate) { newValue in
                        speechService.speechRate = newValue
                    }
                    
                    Text("Rate: \(Int(speechRate * 100))%")
                }
                
                Section(header: Text("Speech Pitch")) {
                    Slider(value: $speechPitch, in: 0.5...2.0, step: 0.1) {
                        Text("Pitch")
                    } minimumValueLabel: {
                        Text("Low")
                    } maximumValueLabel: {
                        Text("High")
                    }
                    .onChange(of: speechPitch) { newValue in
                        speechService.speechPitch = newValue
                    }
                    
                    Text("Pitch: \(String(format: "%.1f", speechPitch))")
                }
                
                Section(header: Text("Test Voice")) {
                    TextField("Test Text", text: $testText)
                    
                    Button(action: {
                        speechService.speak(testText)
                    }) {
                        HStack {
                            Spacer()
                            Label("Test Voice", systemImage: "play.circle")
                            Spacer()
                        }
                    }
                    .disabled(speechService.isSpeaking)
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Load current settings
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