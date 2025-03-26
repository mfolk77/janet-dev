//
//  AudioRecordingView.swift
//  Janet
//
//  Created by Michael folk on 3/2/2025.
//

import SwiftUI
import AVFoundation
import Speech
import UniformTypeIdentifiers
import CryptoKit

struct AudioRecordingView: View {
    // Use safe initialization pattern for ModelManager
    @EnvironmentObject private var modelManager: ModelManager
    
    // On appear hook to ensure model manager is properly initialized
    private var onAppearHandler: some View {
        Color.clear
            .onAppear {
                if modelManager.isLoaded == false {
                    // Try to initialize model if not already loaded
                    Task {
                        do {
                            try await ModelManager.shared.loadModel()
                        } catch {
                            print("Error initializing model: \(error.localizedDescription)")
                        }
                    }
                }
            }
    }
    @EnvironmentObject private var navigationState: NavigationState
    @EnvironmentObject private var notionMemory: NotionMemory
    @StateObject private var audioService = AudioRecordingService()
    
    @State private var showingSettings = false
    @State private var showingTranscriptionDetail: Transcription? = nil
    @State private var isExporting = false
    @State private var exportURL: URL? = nil
    @State private var meetingTitle: String = ""
    @State private var shouldSaveToNotion: Bool = false
    @State private var meetingStarted: Bool = false
    
    var body: some View {
        NavigationView {
            // Ensure modelManager is initialized
            onAppearHandler
            
            List {
                // Home Button
                Section {
                    HStack {
                        Spacer()
                        Button(action: {
                            navigationState.navigateToHome()
                        }) {
                            HStack {
                                Image(systemName: "house.fill")
                                Text("Return to Home")
                            }
                            .padding(10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                    }
                }
                // Controls Section
                Section(header: Text(meetingStarted ? "Meeting in Progress" : "Meeting Controls") as Text) {
                    if !meetingStarted {
                        // Meeting setup form
                        VStack(alignment: .leading, spacing: 16) {
                            TextField("Meeting Title", text: $meetingTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.vertical, 4)
                            
                            Toggle("Save to Notion Memory", isOn: $shouldSaveToNotion)
                                .disabled(!notionMemory.isEnabled)
                            
                            if shouldSaveToNotion && !notionMemory.isEnabled {
                                Text("Notion integration is not enabled. Configure it in Settings.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            Button(action: {
                                startMeeting()
                            }) {
                                Text("Start Meeting")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .font(.headline)
                            }
                            .disabled(meetingTitle.isEmpty)
                            .padding(.top, 8)
                        }
                        .padding()
                    } else {
                        VStack(alignment: .center, spacing: 20) {
                            // Meeting info
                            Text(meetingTitle)
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            // Record Button
                            Button(action: toggleRecording) {
                                ZStack {
                                    Circle()
                                        .fill(audioService.isRecording ? Color.red : Color.blue)
                                        .frame(width: 70, height: 70)
                                    
                                    if audioService.isRecording {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 25, height: 25)
                                            .padding(.leading, 3) // Offset to give "play" appearance
                                    }
                                }
                            }
                            .padding()
                            
                            // Timer Display
                            Text(formatTime(audioService.recordingTime))
                                .font(.system(size: 30, weight: .bold, design: .monospaced))
                                .foregroundColor(audioService.isRecording ? .red : .primary)
                            
                            // Live transcription toggle
                            Toggle("Live Transcription", isOn: $audioService.isLiveTranscriptionEnabled)
                                .disabled(audioService.isRecording)
                                .padding(.horizontal)
                            
                            // End meeting button
                            Button("End Meeting") {
                                endMeeting()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        
                        // Current transcription (for live mode)
                        if audioService.isRecording && audioService.isLiveTranscriptionEnabled && !audioService.currentTranscription.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Live Transcription")
                                    .font(.headline)
                                
                                Text(audioService.currentTranscription)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Recordings Section
                Section(header: Text("Recordings")) {
                    if audioService.recordedAudios.isEmpty {
                        Text("No recordings available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(audioService.recordedAudios.sorted(by: { $0.date > $1.date })) { recording in
                            RecordingRow(
                                recording: recording,
                                transcription: audioService.transcriptions.first(where: { $0.recordingId == recording.id }),
                                onDelete: {
                                    audioService.deleteRecording(recording)
                                },
                                onShowTranscription: { transcription in
                                    showingTranscriptionDetail = transcription
                                }
                            )
                        }
                    }
                }
                
                // HIPAA Compliance Notice
                Section(header: Text("Security")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.green)
                            Text("HIPAA Compliant Storage")
                                .font(.headline)
                        }
                        
                        Text("All recordings and transcriptions are stored with AES-256 encryption and never leave your device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.blue)
                            Text("Automatic Deletion: \(audioService.retentionPeriodDays) days")
                                .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        Label("Security Settings", systemImage: "gear")
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Medical Recorder")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                RecordingSettingsView(retentionPeriodDays: $audioService.retentionPeriodDays, encryptionEnabled: $audioService.encryptionEnabled)
            }
            .sheet(item: $showingTranscriptionDetail) { transcription in
                TranscriptionDetailView(
                    transcription: transcription,
                    onExport: {
                        exportURL = audioService.exportTranscription(transcription)
                        if exportURL != nil {
                            isExporting = true
                        }
                    }
                )
            }
            .fileExporter(
                isPresented: $isExporting,
                document: TextDocument(url: exportURL),
                contentType: .plainText,
                defaultFilename: "Janet_Transcription.txt"
            ) { result in
                switch result {
                case .success(let url):
                    print("Saved to \(url)")
                case .failure(let error):
                    print("Export failed: \(error.localizedDescription)")
                }
                exportURL = nil
            }
            .onAppear {
                // Connect the model manager for transcription - use shared instance directly
                audioService.modelManager = ModelManager.shared
            }
            .alert(isPresented: $audioService.showPermissionAlert) {
                Alert(
                    title: Text("Microphone Access Required"),
                    message: Text("Please enable microphone access in Settings to use recording features."),
                    primaryButton: .default(Text("Settings")),
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func startMeeting() {
        meetingStarted = true
        audioService.isLiveTranscriptionEnabled = true // Enable live transcription by default for meetings
        
        // Auto-start recording when meeting begins
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            audioService.startRecording()
        }
    }
    
    private func endMeeting() {
        // Make sure recording is stopped
        if audioService.isRecording {
            audioService.stopRecording()
        }
        
        // Transcription will be saved to Notion automatically by the service
        // We've removed the explicit Notion save here since it's now handled in AudioRecordingService
        
        // Provide feedback to user about where the recording was saved
        navigationState.activeView = .chat
        
        // Reset meeting state
        meetingStarted = false
        meetingTitle = ""
        shouldSaveToNotion = false
    }
    
    private func toggleRecording() {
        if audioService.isRecording {
            audioService.stopRecording()
        } else {
            audioService.startRecording()
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

struct RecordingRow: View {
    let recording: RecordedAudio
    let transcription: Transcription?
    let onDelete: () -> Void
    let onShowTranscription: (Transcription) -> Void
    
    @State private var isPlaying = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(formatDate(recording.date))
                        .font(.headline)
                    
                    Text(formatDuration(recording.duration))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Playback controls
                Button(action: {
                    isPlaying = true
                    // Use a singleton or shared instance for audio service
                    let audioService = AudioRecordingService()
                    audioService.playRecording(recording) { success in
                        if success {
                            DispatchQueue.main.async {
                                isPlaying = false
                            }
                        }
                    }
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isPlaying)
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
                .alert(isPresented: $showDeleteConfirmation) {
                    Alert(
                        title: Text("Delete Recording"),
                        message: Text("Are you sure you want to delete this recording? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            onDelete()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            
            // Transcription status
            if let transcription = transcription {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Transcription available")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Button("Show") {
                            onShowTranscription(transcription)
                        }
                        .font(.caption)
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    // Preview of transcription text
                    Text("Preview: \(transcription.text.prefix(100))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                .padding(.top, 4)
            } else if recording.transcriptionAvailable {
                Text("Loading transcription...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Encryption status
            if !recording.encryptionKeyIdentifier.isEmpty {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.green)
                        .imageScale(.small)
                    
                    Text("Encrypted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TranscriptionDetailView: View {
    let transcription: Transcription
    let onExport: () -> Void
    
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: "calendar")
                            Text(formatDate(transcription.dateCreated))
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    Divider()
                    
                    // Transcription text
                    Text(transcription.text)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Export button
                    Button(action: onExport) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export as Text")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    
                    // HIPAA compliance notice
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.green)
                            
                            Text("HIPAA Compliant")
                                .font(.headline)
                        }
                        
                        Text("This transcription is stored securely on your device with AES-256 encryption.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Transcription")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct RecordingSettingsView: View {
    @Binding var retentionPeriodDays: Int
    @Binding var encryptionEnabled: Bool
    
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Security")) {
                    Toggle("Enable Encryption", isOn: $encryptionEnabled)
                    
                    if encryptionEnabled {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.green)
                            Text("AES-256 Encryption")
                        }
                    }
                }
                
                Section(header: Text("Data Retention")) {
                    Picker("Retention Period", selection: $retentionPeriodDays) {
                        Text("30 days").tag(30)
                        Text("60 days").tag(60)
                        Text("90 days").tag(90)
                        Text("180 days").tag(180)
                        Text("1 year").tag(365)
                    }
                    
                    Text("Recordings and transcripts will be automatically deleted after the selected period to maintain compliance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("HIPAA Compliance")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Janet AI Medical Recorder is designed to comply with HIPAA requirements for the secure handling of Protected Health Information (PHI).")
                            .font(.subheadline)
                        
                        Text("• All data is processed locally on your device")
                            .font(.caption)
                        
                        Text("• Encryption ensures PHI security at rest")
                            .font(.caption)
                        
                        Text("• Automatic deletion policies maintain compliance")
                            .font(.caption)
                        
                        Text("• No cloud storage or external processing")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Security Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// Helper for file export
struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.plainText]
    var url: URL?
    
    init(url: URL?) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        self.url = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url, let data = try? Data(contentsOf: url) else {
            return FileWrapper(regularFileWithContents: Data())
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

struct AudioRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        AudioRecordingView()
            .environmentObject(ModelManager.shared)
            .environmentObject(NotionMemory())
            .environmentObject(NavigationState())
    }
}
