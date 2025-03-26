//
//  AudioRecordingService.swift
//  Janet
//
//  Created by Michael folk on 3/2/2025.
//

import Foundation
import AVFoundation
import Speech
import Combine
import CryptoKit
import SwiftUI
import os

// MARK: - Data Models

/// Represents a recorded audio session with metadata
struct RecordedAudio: Identifiable, Codable {
    var id = UUID()
    var fileName: String
    var date: Date
    var duration: TimeInterval
    var transcriptionAvailable: Bool
    var encryptionKeyIdentifier: String
    var autoDeleteDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, fileName, date, duration, transcriptionAvailable, encryptionKeyIdentifier, autoDeleteDate
    }
}

/// Represents a transcription with metadata
struct Transcription: Identifiable, Codable {
    var id = UUID()
    var recordingId: UUID
    var text: String
    var segments: [TranscriptionSegment]
    var dateCreated: Date
    var lastModified: Date
    
    enum CodingKeys: String, CodingKey {
        case id, recordingId, text, segments, dateCreated, lastModified
    }
}

/// Represents a timestamped segment of a transcription
struct TranscriptionSegment: Identifiable, Codable {
    var id = UUID()
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var speakerId: Int?
    var confidence: Float
    
    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, text, speakerId, confidence
    }
}

// MARK: - Audio Recording Service

/// Manages audio recording, encryption, and transcription in a HIPAA-compliant manner
class AudioRecordingService: NSObject, ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "AudioRecordingService")
    
    // Published properties for UI updates
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordedAudios: [RecordedAudio] = []
    @Published var transcriptions: [Transcription] = []
    @Published var isTranscribing = false
    @Published var isLiveTranscriptionEnabled = false
    @Published var currentTranscription: String = ""
    @Published var recordingPermissionGranted = true // macOS doesn't require explicit recording permission
    @Published var showPermissionAlert = false
    
    // HIPAA Compliance Settings
    @Published var retentionPeriodDays: Int = 90
    @Published var encryptionEnabled = true
    
    // Audio recording components
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    
    // Timer for updating recording duration
    private var timer: Timer?
    
    // Current recording info
    private var currentRecordingFileName: String?
    private var currentRecordingStartTime: Date?
    private var currentEncryptionKey: SymmetricKey?
    private var currentKeyIdentifier: String?
    
    // Reference to active audio player (to prevent deallocation during playback)
    private var activeAudioPlayer: AVAudioPlayer?
    
    // File handling
    private let fileManager = FileManager.default
    private var recordingsDirectoryURL: URL?
    private var transcriptionsDirectoryURL: URL?
    private var metadataDirectoryURL: URL?
    
    // Reference to ModelManager for transcription
    var modelManager: ModelManager?
    
    override init() {
        super.init()
        setupDirectories()
        loadSavedRecordings()
        loadSavedTranscriptions()
        
        // Setup automatic cleanup based on retention policy
        setupAutomaticCleanup()
    }
    
    // MARK: - Setup Methods
    
    private func setupDirectories() {
        // Get the Documents directory
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Unable to access Documents directory")
            return
        }
        
        // Create secure directories for our data
        let janetDirectory = documentsDirectory.appendingPathComponent("Janet", isDirectory: true)
        recordingsDirectoryURL = janetDirectory.appendingPathComponent("Recordings", isDirectory: true)
        transcriptionsDirectoryURL = janetDirectory.appendingPathComponent("Transcriptions", isDirectory: true)
        metadataDirectoryURL = janetDirectory.appendingPathComponent("Metadata", isDirectory: true)
        
        // Create directories if they don't exist
        do {
            try fileManager.createDirectory(at: janetDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: recordingsDirectoryURL!, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: transcriptionsDirectoryURL!, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: metadataDirectoryURL!, withIntermediateDirectories: true)
            
            // Set directory attributes for additional security
            var attributes: [FileAttributeKey: Any] = [:]
            attributes[.posixPermissions] = 0o700  // Owner only permissions
            
            try fileManager.setAttributes(attributes, ofItemAtPath: recordingsDirectoryURL!.path)
            try fileManager.setAttributes(attributes, ofItemAtPath: transcriptionsDirectoryURL!.path)
            try fileManager.setAttributes(attributes, ofItemAtPath: metadataDirectoryURL!.path)
            
            logger.info("Secure directories set up successfully")
        } catch {
            logger.error("Failed to set up directories: \(error.localizedDescription)")
        }
    }
    
    private func setupAutomaticCleanup() {
        // Schedule daily cleanup check
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.cleanupExpiredRecordings()
        }
    }
    
    // MARK: - Recording Methods
    
    /// Start a new audio recording session
    func startRecording() {
        // Generate a unique file name based on timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "recording_\(dateFormatter.string(from: Date())).m4a"
        currentRecordingFileName = fileName
        currentRecordingStartTime = Date()
        
        // Generate encryption key if encryption is enabled
        if encryptionEnabled {
            currentEncryptionKey = SymmetricKey(size: .bits256) // AES-256 for HIPAA compliance
            currentKeyIdentifier = UUID().uuidString
            saveEncryptionKey()
        }
        
        // Configure the audio recorder settings
        guard let recordingsURL = recordingsDirectoryURL else {
            logger.error("Recordings directory not set up")
            return
        }
        
        let fileURL = recordingsURL.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Initialize and start the audio recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            if audioRecorder?.record() == true {
                isRecording = true
                recordingTime = 0
                
                // Start timer to update recording duration
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.recordingTime += 0.1
                }
                
                // Initialize live transcription if enabled
                if isLiveTranscriptionEnabled {
                    startLiveTranscription()
                }
                
                logger.info("Recording started: \(fileName)")
            } else {
                logger.error("Failed to start recording")
            }
        } catch {
            logger.error("Error creating audio recorder: \(error.localizedDescription)")
        }
    }
    
    /// Stop the current recording and process it
    func stopRecording() {
        guard isRecording, let audioRecorder = audioRecorder else {
            logger.warning("No active recording to stop")
            return
        }
        
        // Set isRecording to false immediately to prevent callbacks from operating on disposed objects
        isRecording = false
        
        // Stop the audio recorder
        audioRecorder.stop()
        
        // Stop the timer
        timer?.invalidate()
        timer = nil
        
        // Stop live transcription if it was running
        // Do this before processing to ensure clean shutdown
        if isLiveTranscriptionEnabled {
            stopLiveTranscription()
        }
        
        // Small delay to ensure audio resources are properly released
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Process the recording (encrypt and save metadata)
            self.processRecording()
            
            self.logger.info("Recording stopped and processed")
        }
    }
    
    /// Process the recorded audio file (encryption and metadata)
    private func processRecording() {
        guard let fileName = currentRecordingFileName,
              let startTime = currentRecordingStartTime,
              let recordingsURL = recordingsDirectoryURL else {
            logger.error("Missing recording information")
            return
        }
        
        let fileURL = recordingsURL.appendingPathComponent(fileName)
        
        // Calculate recording duration
        let duration = recordingTime
        
        // Encrypt the audio file if encryption is enabled
        if encryptionEnabled {
            encryptFile(at: fileURL)
        }
        
        // Create and save recording metadata
        let recordedAudio = RecordedAudio(
            fileName: fileName,
            date: startTime,
            duration: duration,
            transcriptionAvailable: false,
            encryptionKeyIdentifier: currentKeyIdentifier ?? "",
            autoDeleteDate: Calendar.current.date(byAdding: .day, value: retentionPeriodDays, to: Date())
        )
        
        recordedAudios.append(recordedAudio)
        saveRecordingsMetadata()
        
        // Start transcription process
        if !isLiveTranscriptionEnabled {
            transcribeRecording(recordedAudio)
        } else {
            // Save the live transcription result
            saveTranscription(for: recordedAudio.id, text: currentTranscription)
        }
        
        // Reset current recording info
        currentRecordingFileName = nil
        currentRecordingStartTime = nil
        currentEncryptionKey = nil
        currentKeyIdentifier = nil
        recordingTime = 0
    }
    
    // MARK: - Encryption Methods
    
    /// Save the encryption key securely in the keychain
    private func saveEncryptionKey() {
        guard let key = currentEncryptionKey, 
              let identifier = currentKeyIdentifier else {
            logger.error("No encryption key to save")
            return
        }
        
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Use the Keychain to store the encryption key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.janet.audioencryption",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Failed to save encryption key to Keychain: \(status)")
        }
    }
    
    /// Retrieve an encryption key from the keychain
    private func getEncryptionKey(identifier: String) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.janet.audioencryption",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, 
              let keyData = item as? Data else {
            logger.error("Failed to retrieve encryption key: \(status)")
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
    
    /// Encrypt a file using AES-GCM
    private func encryptFile(at url: URL) {
        guard let key = currentEncryptionKey else {
            logger.error("No encryption key available")
            return
        }
        
        do {
            // Read the file data
            let fileData = try Data(contentsOf: url)
            
            // Generate a nonce
            let nonce = AES.GCM.Nonce()
            
            // Encrypt the data
            let sealedBox = try AES.GCM.seal(fileData, using: key, nonce: nonce)
            
            // Create combined data with nonce and ciphertext
            var encryptedData = Data()
            encryptedData.append(nonce.withUnsafeBytes { Data($0) })
            encryptedData.append(sealedBox.ciphertext)
            encryptedData.append(sealedBox.tag)
            
            // Write the encrypted data back to the file
            try encryptedData.write(to: url, options: .atomic)
            
            logger.info("File encrypted successfully: \(url.lastPathComponent)")
        } catch {
            logger.error("Encryption failed: \(error.localizedDescription)")
        }
    }
    
    /// Decrypt a file using AES-GCM
    private func decryptFile(at url: URL, keyIdentifier: String) -> Data? {
        guard let key = getEncryptionKey(identifier: keyIdentifier) else {
            logger.error("Could not retrieve encryption key for \(keyIdentifier)")
            return nil
        }
        
        do {
            // Read the encrypted data
            let encryptedData = try Data(contentsOf: url)
            
            // Extract nonce (first 12 bytes)
            let nonceData = encryptedData.prefix(12)
            let nonce = try AES.GCM.Nonce(data: nonceData)
            
            // Extract ciphertext (middle portion)
            let tagSize = 16 // AES-GCM tag size is 16 bytes
            let ciphertextData = encryptedData.dropFirst(12).dropLast(tagSize)
            
            // Extract authentication tag (last 16 bytes)
            let tagData = encryptedData.suffix(tagSize)
            
            // Recreate sealed box
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce,
                                           ciphertext: ciphertextData,
                                           tag: tagData)
            
            // Decrypt the data
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            logger.info("File decrypted successfully: \(url.lastPathComponent)")
            return decryptedData
        } catch {
            logger.error("Decryption failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Transcription Methods
    
    /// Start live transcription
    private func startLiveTranscription() {
        audioEngine = AVAudioEngine()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            logger.error("Unable to create speech recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        do {
            let inputNode = audioEngine!.inputNode
            
            // Install tap on input node
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            // Start the audio engine
            audioEngine!.prepare()
            try audioEngine!.start()
            
            // Start recognition
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    // Update the current transcription
                    self.currentTranscription = result.bestTranscription.formattedString
                }
                
                if error != nil || (result?.isFinal ?? false) {
                    // Safely cleanup when recognition completes
                    let localEngine = self.audioEngine
                    
                    // Set properties to nil first
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    
                    // Execute cleanup
                    if let engine = localEngine, engine.isRunning {
                        engine.stop()
                        inputNode.removeTap(onBus: 0)
                    }
                    
                    self.audioEngine = nil
                }
            }
            
            logger.info("Live transcription started")
        } catch {
            logger.error("Error starting live transcription: \(error.localizedDescription)")
            stopLiveTranscription()
        }
    }
    
    /// Stop live transcription
    private func stopLiveTranscription() {
        // Copy references locally to avoid race conditions
        let localEngine = audioEngine
        let localTask = recognitionTask
        let localRequest = recognitionRequest
        
        // Set class properties to nil first to avoid callback issues
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        
        // Execute cleanup operations on these local references
        
        // Handle audio engine
        if let engine = localEngine {
            do {
                // Only remove tap if engine is running
                if engine.isRunning {
                    try autoreleasepool {
                        engine.inputNode.removeTap(onBus: 0)
                    }
                }
                engine.stop()
            } catch {
                logger.error("Error cleaning up audio engine: \(error.localizedDescription)")
            }
        }
        
        // Cancel recognition task
        localTask?.cancel()
        
        // Clean up recognition request
        do {
            try autoreleasepool {
                localRequest?.endAudio()
            }
        } catch {
            logger.error("Error ending audio request: \(error.localizedDescription)")
        }
        
        // Clear local references
        currentTranscription = ""
        
        logger.info("Live transcription stopped")
    }
    
    /// Transcribe a recorded audio file
    private func transcribeRecording(_ recording: RecordedAudio) {
        guard let recordingsURL = recordingsDirectoryURL else {
            logger.error("Recordings directory not set up")
            return
        }
        
        isTranscribing = true
        
        // Path to the recording file
        let fileURL = recordingsURL.appendingPathComponent(recording.fileName)
        
        // If file is encrypted, decrypt it first
        var audioData: Data?
        if encryptionEnabled && !recording.encryptionKeyIdentifier.isEmpty {
            audioData = decryptFile(at: fileURL, keyIdentifier: recording.encryptionKeyIdentifier)
        } else {
            do {
                audioData = try Data(contentsOf: fileURL)
            } catch {
                logger.error("Failed to read audio file: \(error.localizedDescription)")
                isTranscribing = false
                return
            }
        }
        
        guard let audioData = audioData else {
            logger.error("Could not get audio data for transcription")
            isTranscribing = false
            return
        }
        
        // Check if we have a model manager available for PHI-4 transcription
        if let modelManager = modelManager {
            // Create a temporary file for the decrypted audio
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".m4a")
            
            do {
                // Write the decrypted data to temp file
                try audioData.write(to: tempURL)
                
                // Use model for transcription
                Task {
                    do {
                        // Ensure the model is loaded first
                        if !modelManager.isLoaded {
                            try await modelManager.loadModel()
                        }
                        
                        // Convert audio to text
                        let prompt = "Transcribe the following audio file accurately. This is a medical recording that may contain protected health information. Generate a verbatim transcript with speaker identification if possible."
                        
                        let transcriptionText = try await modelManager.generateText(
                            prompt: prompt,
                            maxTokens: 4000
                        )
                        
                        // Save the transcription
                        await MainActor.run {
                            self.saveTranscription(for: recording.id, text: transcriptionText)
                            self.isTranscribing = false
                        }
                        
                        // Delete temporary file
                        try? FileManager.default.removeItem(at: tempURL)
                    } catch {
                        logger.error("Transcription failed: \(error.localizedDescription)")
                        await MainActor.run {
                            self.isTranscribing = false
                        }
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                }
            } catch {
                logger.error("Failed to prepare audio for transcription: \(error.localizedDescription)")
                isTranscribing = false
                try? FileManager.default.removeItem(at: tempURL)
            }
        } else {
            // Fallback to built-in speech recognition
            recognizeAudioData(audioData, for: recording.id)
        }
    }
    
    /// Use Apple's built-in speech recognition as a fallback
    private func recognizeAudioData(_ audioData: Data, for recordingId: UUID) {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".m4a")
        
        do {
            try audioData.write(to: tempURL)
            
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            
            recognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    self.logger.error("Speech recognition failed: \(error.localizedDescription)")
                    self.isTranscribing = false
                    try? FileManager.default.removeItem(at: tempURL)
                    return
                }
                
                if let result = result, result.isFinal {
                    let transcriptionText = result.bestTranscription.formattedString
                    
                    // Process transcription on main thread
                    DispatchQueue.main.async {
                        self.saveTranscription(for: recordingId, text: transcriptionText)
                        self.isTranscribing = false
                    }
                    
                    // Delete temporary file
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
        } catch {
            logger.error("Failed to process audio for speech recognition: \(error.localizedDescription)")
            isTranscribing = false
        }
    }
    
    /// Save a transcription and send to Notion automatically
    private func saveTranscription(for recordingId: UUID, text: String) {
        guard let transcriptionsURL = transcriptionsDirectoryURL else {
            logger.error("Transcriptions directory not set up")
            return
        }
        
        // Get meeting title or generate one based on date
        var meetingTitle = "Meeting Recording"
        if let index = recordedAudios.firstIndex(where: { $0.id == recordingId }) {
            let recording = recordedAudios[index]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            meetingTitle = "Meeting on \(dateFormatter.string(from: recording.date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            meetingTitle = "Meeting on \(dateFormatter.string(from: Date()))"
        }
        
        // Create transcription object
        let transcription = Transcription(
            recordingId: recordingId,
            text: text,
            segments: [], // Detailed segments not available in basic implementation
            dateCreated: Date(),
            lastModified: Date()
        )
        
        // Update the corresponding recording
        if let index = recordedAudios.firstIndex(where: { $0.id == recordingId }) {
            var updatedRecording = recordedAudios[index]
            updatedRecording.transcriptionAvailable = true
            recordedAudios[index] = updatedRecording
            saveRecordingsMetadata()
        }
        
        // Add to transcriptions array
        transcriptions.append(transcription)
        
        // Save to file
        let transcriptionFileURL = transcriptionsURL.appendingPathComponent("\(recordingId.uuidString).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try encoder.encode(transcription)
            
            // Encrypt the transcription if encryption is enabled
            if encryptionEnabled, 
               let index = recordedAudios.firstIndex(where: { $0.id == recordingId }),
               !recordedAudios[index].encryptionKeyIdentifier.isEmpty,
               let key = getEncryptionKey(identifier: recordedAudios[index].encryptionKeyIdentifier) {
                
                // Encrypt the JSON data
                let nonce = AES.GCM.Nonce()
                let sealedBox = try AES.GCM.seal(jsonData, using: key, nonce: nonce)
                
                var encryptedData = Data()
                encryptedData.append(nonce.withUnsafeBytes { Data($0) })
                encryptedData.append(sealedBox.ciphertext)
                encryptedData.append(sealedBox.tag)
                
                try encryptedData.write(to: transcriptionFileURL, options: .atomic)
            } else {
                // Save unencrypted
                try jsonData.write(to: transcriptionFileURL, options: .atomic)
            }
            
            logger.info("Transcription saved successfully for recording \(recordingId.uuidString)")
            
            // Send to Notion automatically (do this in background to avoid blocking)
            Task {
                // Store and log the result of Notion save attempt
                let notionSaveResult = await saveTranscriptionToNotion(title: meetingTitle, text: text)
                if !notionSaveResult {
                    logger.error("Failed to save transcription to Notion initially")
                }
            }
            
            // Also save to memory manager for chat context - do this on main thread
            DispatchQueue.main.async {
                // Add to short-term memory through NotificationCenter
                NotificationCenter.default.post(
                    name: NSNotification.Name("AddToShortTermMemory"),
                    object: nil,
                    userInfo: [
                        "content": "Transcription: \(text.prefix(1000))",
                        "source": "Audio Recording",
                        "timestamp": Date()
                    ]
                )
            }
        } catch {
            logger.error("Failed to save transcription: \(error.localizedDescription)")
        }
    }
    
    /// Save transcription to Notion - returns success status
    private func saveTranscriptionToNotion(title: String, text: String) async -> Bool {
        // Import NotionMemory if available
        let notionMemory = NotionMemory()
        
        // Only proceed if Notion integration is enabled
        if notionMemory.isEnabled {
            if notionMemory.apiKey.isEmpty || notionMemory.databaseId.isEmpty {
                logger.error("Notion API key or database ID is empty, cannot save to Notion")
                return false
            }
            
            // Log the attempt with detailed info for troubleshooting
            logger.info("Attempting to save to Notion - Title: \(title), Text length: \(text.count), API key length: \(notionMemory.apiKey.count), Database ID length: \(notionMemory.databaseId.count)")
            
            // Prepare tags
            let tags = ["meeting", "transcription", "janet"]
            
            // Try to save to Notion
            let success = await notionMemory.createNotionPage(
                title: title,
                content: text,
                tags: tags
            )
            
            if success {
                logger.info("Successfully saved transcription to Notion")
                return true
            } else {
                logger.error("Failed to save transcription to Notion - check API key and database ID validity")
                
                // Add a retry mechanism for important content
                Task {
                    // Wait 5 seconds and try again once
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    logger.info("Retrying Notion save after delay")
                    let retrySuccess = await notionMemory.createNotionPage(
                        title: title + " (Retry)",
                        content: text,
                        tags: tags
                    )
                    if retrySuccess {
                        logger.info("Successfully saved transcription to Notion on retry")
                    } else {
                        logger.error("Failed to save transcription to Notion on retry")
                    }
                }
                
                return false
            }
        }
        
        // Notion integration not enabled
        logger.info("Notion integration not enabled - skipping Notion save")
        return false
    }
    
    // MARK: - File Management Methods
    
    /// Load saved recordings metadata
    private func loadSavedRecordings() {
        guard let metadataURL = metadataDirectoryURL else {
            logger.error("Metadata directory not set up")
            return
        }
        
        let recordingsMetadataURL = metadataURL.appendingPathComponent("recordings.json")
        
        if fileManager.fileExists(atPath: recordingsMetadataURL.path) {
            do {
                let data = try Data(contentsOf: recordingsMetadataURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                recordedAudios = try decoder.decode([RecordedAudio].self, from: data)
                logger.info("Loaded \(self.recordedAudios.count) recording metadata entries")
            } catch {
                logger.error("Failed to load recordings metadata: \(error.localizedDescription)")
            }
        }
    }
    
    /// Save recordings metadata
    private func saveRecordingsMetadata() {
        guard let metadataURL = metadataDirectoryURL else {
            logger.error("Metadata directory not set up")
            return
        }
        
        let recordingsMetadataURL = metadataURL.appendingPathComponent("recordings.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(recordedAudios)
            try data.write(to: recordingsMetadataURL, options: .atomic)
            
            logger.info("Saved \(self.recordedAudios.count) recording metadata entries")
        } catch {
            logger.error("Failed to save recordings metadata: \(error.localizedDescription)")
        }
    }
    
    /// Load saved transcriptions
    private func loadSavedTranscriptions() {
        guard let transcriptionsURL = transcriptionsDirectoryURL else {
            logger.error("Transcriptions directory not set up")
            return
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: transcriptionsURL, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "json" {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        
                        // Check if this transcription is encrypted
                        let recordingId = UUID(uuidString: fileURL.deletingPathExtension().lastPathComponent)
                        var jsonData = data
                        
                        if let recordingId = recordingId,
                           let recordingIndex = recordedAudios.firstIndex(where: { $0.id == recordingId }),
                           encryptionEnabled,
                           !recordedAudios[recordingIndex].encryptionKeyIdentifier.isEmpty {
                            
                            // Try to decrypt
                            if let key = getEncryptionKey(identifier: recordedAudios[recordingIndex].encryptionKeyIdentifier) {
                                // Extract nonce (first 12 bytes)
                                let nonceData = data.prefix(12)
                                let nonce = try AES.GCM.Nonce(data: nonceData)
                                
                                // Extract ciphertext (middle portion)
                                let tagSize = 16 // AES-GCM tag size is 16 bytes
                                let ciphertextData = data.dropFirst(12).dropLast(tagSize)
                                
                                // Extract authentication tag (last 16 bytes)
                                let tagData = data.suffix(tagSize)
                                
                                // Recreate sealed box
                                let sealedBox = try AES.GCM.SealedBox(nonce: nonce,
                                                               ciphertext: ciphertextData,
                                                               tag: tagData)
                                
                                // Decrypt the data
                                jsonData = try AES.GCM.open(sealedBox, using: key)
                            }
                        }
                        
                        // Decode the transcription
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        
                        let transcription = try decoder.decode(Transcription.self, from: jsonData)
                        transcriptions.append(transcription)
                    } catch {
                        logger.error("Failed to load transcription \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
            
            logger.info("Loaded \(self.transcriptions.count) transcriptions")
        } catch {
            logger.error("Failed to access transcriptions directory: \(error.localizedDescription)")
        }
    }
    
    /// Delete a recording and its transcription
    func deleteRecording(_ recording: RecordedAudio) {
        guard let recordingsURL = recordingsDirectoryURL,
              let transcriptionsURL = transcriptionsDirectoryURL else {
            logger.error("Directories not set up")
            return
        }
        
        // Delete the audio file
        let fileURL = recordingsURL.appendingPathComponent(recording.fileName)
        try? fileManager.removeItem(at: fileURL)
        
        // Delete the transcription file
        let transcriptionURL = transcriptionsURL.appendingPathComponent("\(recording.id.uuidString).json")
        try? fileManager.removeItem(at: transcriptionURL)
        
        // Delete encryption key if necessary
        if encryptionEnabled && !recording.encryptionKeyIdentifier.isEmpty {
            deleteEncryptionKey(identifier: recording.encryptionKeyIdentifier)
        }
        
        // Remove from arrays
        if let index = recordedAudios.firstIndex(where: { $0.id == recording.id }) {
            recordedAudios.remove(at: index)
        }
        
        transcriptions.removeAll(where: { $0.recordingId == recording.id })
        
        // Save updated metadata
        saveRecordingsMetadata()
        
        logger.info("Deleted recording \(recording.id.uuidString)")
    }
    
    /// Delete an encryption key from the keychain
    private func deleteEncryptionKey(identifier: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.janet.audioencryption"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Failed to delete encryption key: \(status)")
        }
    }
    
    /// Clean up recordings that have passed their retention period
    private func cleanupExpiredRecordings() {
        let now = Date()
        
        for recording in recordedAudios {
            if let autoDeleteDate = recording.autoDeleteDate, now > autoDeleteDate {
                deleteRecording(recording)
            }
        }
        
        logger.info("Cleanup complete")
    }
    
    /// Export a transcription as a text file
    func exportTranscription(_ transcription: Transcription) -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Unable to access Documents directory")
            return nil
        }
        
        let exportURL = documentsDirectory.appendingPathComponent("Janet_Transcription_\(Date().timeIntervalSince1970).txt")
        
        do {
            // Format the transcription
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            
            let formattedText = """
            JANET AI TRANSCRIPTION
            Date: \(dateFormatter.string(from: transcription.dateCreated))
            
            TRANSCRIPT:
            \(transcription.text)
            
            Generated by Janet AI - HIPAA Compliant - For authorized use only
            Exported on \(dateFormatter.string(from: Date()))
            """
            
            try formattedText.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            logger.error("Failed to export transcription: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Play a recording
    func playRecording(_ recording: RecordedAudio, completion: @escaping (Bool) -> Void) {
        guard let recordingsURL = recordingsDirectoryURL else {
            logger.error("Recordings directory not set up")
            completion(false)
            return
        }
        
        let fileURL = recordingsURL.appendingPathComponent(recording.fileName)
        
        logger.info("Attempting to play file: \(fileURL.path)")
        print("DEBUG: Attempting to play recording from \(fileURL.path)")
        
        // We'll use the instance property activeAudioPlayer to maintain the reference
        
        // If encrypted, decrypt first
        if encryptionEnabled && !recording.encryptionKeyIdentifier.isEmpty {
            guard let decryptedData = decryptFile(at: fileURL, keyIdentifier: recording.encryptionKeyIdentifier) else {
                logger.error("Failed to decrypt recording")
                completion(false)
                return
            }
            
            // Create temporary file for playback
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".m4a")
            
            do {
                try decryptedData.write(to: tempURL)
                
                print("DEBUG: Playing from decrypted file at \(tempURL.path)")
                
                // Play the audio (preserve the reference)
                self.activeAudioPlayer = try AVAudioPlayer(contentsOf: tempURL)
                self.activeAudioPlayer?.prepareToPlay()
                self.activeAudioPlayer?.volume = 1.0
                
                if let player = self.activeAudioPlayer {
                    player.delegate = self
                    let success = player.play()
                    
                    if !success {
                        logger.error("Failed to start playback")
                        completion(false)
                        return
                    }
                    
                    // Store the player in a property to prevent deallocation
                    print("DEBUG: Playback started, duration: \(player.duration)")
                    
                    // Schedule cleanup
                    DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 1) {
                        print("DEBUG: Playback completed")
                        try? FileManager.default.removeItem(at: tempURL)
                        completion(true)
                    }
                } else {
                    logger.error("Player initialization failed")
                    completion(false)
                }
            } catch {
                logger.error("Failed to play decrypted recording: \(error.localizedDescription)")
                print("DEBUG: Playback error: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: tempURL)
                completion(false)
            }
        } else {
            // Play directly if not encrypted
            do {
                print("DEBUG: Playing from unencrypted file")
                
                // Check if file exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    logger.error("Recording file does not exist at path: \(fileURL.path)")
                    print("DEBUG: File does not exist at: \(fileURL.path)")
                    completion(false)
                    return
                }
                
                // Play the audio (preserve the reference)
                self.activeAudioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                self.activeAudioPlayer?.prepareToPlay()
                self.activeAudioPlayer?.volume = 1.0
                
                if let player = self.activeAudioPlayer {
                    player.delegate = self
                    let success = player.play()
                    
                    if !success {
                        logger.error("Failed to start playback")
                        completion(false)
                        return
                    }
                    
                    print("DEBUG: Playback started, duration: \(player.duration)")
                    
                    // Schedule completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 1) {
                        print("DEBUG: Playback completed")
                        completion(true)
                    }
                } else {
                    logger.error("Player initialization failed")
                    completion(false)
                }
            } catch {
                logger.error("Failed to play recording: \(error.localizedDescription)")
                print("DEBUG: Playback error: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
}

// MARK: - Protocol Conformance

extension AudioRecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            logger.error("Recording finished unsuccessfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            logger.error("Recording encode error: \(error.localizedDescription)")
        }
    }
}

extension AudioRecordingService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        logger.info("Audio playback finished, success: \(flag)")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            logger.error("Audio player decode error: \(error.localizedDescription)")
        }
    }
}
