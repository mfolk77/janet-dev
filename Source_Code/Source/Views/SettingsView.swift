//
//  SettingsView.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import SwiftUI

struct SettingsView2: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var ollamaService = OllamaService.shared
    @State private var showApiSettings = false
    @State private var showAbout = false
    @State private var mockMode = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Connection")) {
                    Toggle("Offline Mode", isOn: $mockMode)
                        .onChange(of: mockMode) { oldValue, newValue in
                            ollamaService.useMockMode = newValue
                        }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(ollamaService.isRunning ? "Connected" : "Offline")
                            .foregroundColor(ollamaService.isRunning ? .green : .red)
                    }
                    
                    // Show help text for Ollama installation
                    if !ollamaService.isRunning && !mockMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ollama Connection Troubleshooting:")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("1. Make sure Ollama is installed")
                                .font(.caption)
                            Text("2. Open Terminal and run: ollama serve")
                                .font(.caption)
                            Text("3. Then click 'Try Connection Again'")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    if ollamaService.isRunning {
                        HStack {
                            Text("Current Model")
                            Spacer()
                            Text(ollamaService.currentModel)
                        }
                        
                        if !ollamaService.availableModels.isEmpty {
                            Picker("Model", selection: $ollamaService.currentModel) {
                                ForEach(ollamaService.availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            mockMode = false
                            ollamaService.useMockMode = false
                            let isRunning = await ollamaService.checkOllamaStatus()
                            if isRunning {
                                await ollamaService.loadAvailableModels()
                            }
                        }
                    }) {
                        Label("Try Connection Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.blue)
                }
                
                Section(header: Text("API Integrations")) {
                    Button(action: {
                        showApiSettings = true
                    }) {
                        HStack {
                            Label("API Settings", systemImage: "key.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("Application")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                    }
                    
                    Button(action: {
                        showAbout = true
                    }) {
                        HStack {
                            Label("About Janet", systemImage: "info.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Update the mock mode toggle to match the service state
                mockMode = ollamaService.useMockMode
                
                // Check connection status
                Task {
                    // Store and use the status result
                    let isRunning = await ollamaService.checkOllamaStatus()
                    if !isRunning && !ollamaService.useMockMode {
                        print("Ollama service not running during settings view init")
                    }
                }
            }
            .sheet(isPresented: $showApiSettings) {
                APISettingsView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding()
                
                Text("Janet AI")
                    .font(.largeTitle)
                    .bold()
                
                Text("Version 1.0.0")
                    .font(.headline)
                
                Text("An AI assistant powered by Ollama")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Divider()
                    .padding()
                
                Text("Created by Michael Folk")
                    .font(.body)
                
                Text("© 2025 Janet AI Project")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
                
                Spacer()
            }
            .padding()
            .navigationTitle("About")
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView2()
    }
}
