import Foundation
import AVFoundation
import Speech
import SwiftUI
import Combine

class SpeechService: NSObject, ObservableObject, @unchecked Sendable {
    // MARK: - Properties
    
    // Text-to-Speech
    private lazy var synthesizer = AVSpeechSynthesizer()
    
    // Speech-to-Text
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Thread safety
    private let speechQueue = DispatchQueue(label: "com.janet.speechservice", qos: .userInitiated)
    private let stateUpdateQueue = DispatchQueue(label: "com.janet.speechservice.state", qos: .userInteractive)
    
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
    
    // Cancellables storage
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSpeech()
        loadAvailableVoices()
        synthesizer.delegate = self
    }
    
    // MARK: - Setup
    
    private func setupSpeech() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }
            
            let message: String?
            switch authStatus {
            case .authorized:
                message = nil
            case .denied:
                message = "Speech recognition authorization denied"
            case .restricted:
                message = "Speech recognition restricted on this device"
            case .notDetermined:
                message = "Speech recognition not yet authorized"
            @unknown default:
                message = "Unknown authorization status"
            }
            
            self.updateErrorMessage(message)
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
    
    // MARK: - Thread-safe state updates
    
    private func updateIsListening(_ value: Bool) {
        stateUpdateQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isListening = value
            }
        }
    }
    
    private func updateIsSpeaking(_ value: Bool) {
        stateUpdateQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isSpeaking = value
            }
        }
    }
    
    private func updateRecognizedText(_ value: String) {
        stateUpdateQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.recognizedText = value
            }
        }
    }
    
    private func updateErrorMessage(_ value: String?) {
        stateUpdateQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.errorMessage = value
            }
        }
    }
    
    // MARK: - Text-to-Speech Methods
    
    func speak(_ text: String) {
        speechQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Stop any ongoing speech
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }
            
            // Create utterance
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = self.speechRate
            utterance.pitchMultiplier = self.speechPitch
            
            // Set voice
            if let voice = AVSpeechSynthesisVoice(identifier: self.selectedVoice) {
                utterance.voice = voice
            }
            
            // Start speaking
            self.updateIsSpeaking(true)
            self.synthesizer.speak(utterance)
        }
    }
    
    func stopSpeaking() {
        speechQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
                self.updateIsSpeaking(false)
            }
        }
    }
    
    // MARK: - Speech-to-Text Methods
    
    func startListening() {
        speechQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if already listening
            if self.isListening {
                return
            }
            
            self.updateIsListening(true)
            self.setupRecognition()
        }
    }
    
    private func setupRecognition() {
        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            updateErrorMessage("Unable to create speech recognition request")
            updateIsListening(false)
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio engine and input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            updateErrorMessage("Could not start audio engine: \(error.localizedDescription)")
            updateIsListening(false)
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.updateRecognizedText(result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopListeningInternal()
            }
        }
    }
    
    private func stopListeningInternal() {
        speechQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Stop audio engine and remove tap
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
            
            // End recognition request and task
            self.recognitionRequest?.endAudio()
            self.recognitionRequest = nil
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            
            // Update state
            self.updateIsListening(false)
        }
    }
    
    func stopListening() {
        stopListeningInternal()
    }
    
    func startListening(completion: @escaping (Result<String, Error>) -> Void) {
        // Cancel any existing subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Reset recognized text
        updateRecognizedText("")
        
        // Set up a one-time observer for the recognizedText
        $recognizedText
            .dropFirst() // Skip the initial empty value
            .filter { !$0.isEmpty }
            .first()
            .sink { [weak self] text in
                self?.stopListening()
                completion(.success(text))
            }
            .store(in: &cancellables)
        
        // Start the regular listening process
        startListening()
        
        // Set a timeout to stop listening after 10 seconds if no speech is detected
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            
            if self.isListening {
                self.stopListening()
                
                // Only send failure if we haven't already succeeded
                if self.cancellables.count > 0 {
                    self.cancellables.removeAll()
                    completion(.failure(NSError(domain: "SpeechService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No speech detected"])))
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func resetRecognizedText() {
        updateRecognizedText("")
    }
    
    func getVoiceName(for identifier: String) -> String {
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice.name
        }
        return "Unknown Voice"
    }
    
    func setVoice(_ voiceName: String) {
        // Find the voice by name
        if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.name == voiceName }) {
            selectedVoice = voice.identifier
        }
    }
    
    func setSpeechRate(_ rate: Float) {
        speechRate = rate
    }
    
    func setSpeechPitch(_ pitch: Float) {
        speechPitch = pitch
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        updateIsSpeaking(false)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        updateIsSpeaking(false)
    }
} 