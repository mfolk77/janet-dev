import Foundation
import AVFoundation
import Speech
import SwiftUI
import Combine

class SpeechService: NSObject, ObservableObject {
    // MARK: - Properties
    
    // Text-to-Speech
    private let synthesizer = AVSpeechSynthesizer()
    
    // Speech-to-Text
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Published properties for UI binding
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    @Published var speechRate: Float = 0.5 // Default rate (0.0 to 1.0)
    @Published var speechPitch: Float = 1.0 // Default pitch (0.5 to 2.0)
    @Published var selectedVoice: String = "com.apple.speech.synthesis.voice.samantha" // Default voice
    
    // Available voices
    @Published var availableVoices: [AVSpeechSynthesisVoice] = []
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSpeech()
        loadAvailableVoices()
        synthesizer.delegate = self
    }
    
    // MARK: - Setup
    
    private func setupSpeech() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.errorMessage = nil
                case .denied:
                    self.errorMessage = "Speech recognition authorization denied"
                case .restricted:
                    self.errorMessage = "Speech recognition restricted on this device"
                case .notDetermined:
                    self.errorMessage = "Speech recognition not yet authorized"
                @unknown default:
                    self.errorMessage = "Unknown authorization status"
                }
            }
        }
    }
    
    private func loadAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "en") }
        if let defaultVoice = AVSpeechSynthesisVoice(identifier: selectedVoice) {
            if availableVoices.contains(where: { $0.identifier == defaultVoice.identifier }) {
                selectedVoice = defaultVoice.identifier
            } else if let firstVoice = availableVoices.first {
                selectedVoice = firstVoice.identifier
            }
        }
    }
    
    // MARK: - Text-to-Speech Methods
    
    func speak(_ text: String) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch
        
        // Set voice
        if let voice = AVSpeechSynthesisVoice(identifier: selectedVoice) {
            utterance.voice = voice
        }
        
        // Start speaking
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // MARK: - Speech-to-Text Methods
    
    func startListening() {
        // Check if already listening
        if isListening {
            stopListening()
            return
        }
        
        // Check authorization
        guard speechRecognizer?.isAvailable == true else {
            errorMessage = "Speech recognition is not available"
            return
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Could not configure audio session: \(error.localizedDescription)"
            return
        }
        
        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create speech recognition request"
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio engine and input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Could not start audio engine: \(error.localizedDescription)"
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopListening()
            }
        }
        
        DispatchQueue.main.async {
            self.isListening = true
            self.errorMessage = nil
        }
    }
    
    func stopListening() {
        // Stop audio engine and remove tap
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // End recognition request and task
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Update state
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    // MARK: - Utility Methods
    
    func resetRecognizedText() {
        recognizedText = ""
    }
    
    func getVoiceName(for identifier: String) -> String {
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice.name
        }
        return "Unknown Voice"
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
} 