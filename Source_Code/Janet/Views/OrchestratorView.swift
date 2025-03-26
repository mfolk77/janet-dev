//
//  OrchestratorView.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import SwiftUI
import os

struct OrchestratorView: View {
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Text("Model Orchestrator")
                .font(.largeTitle)
                .padding(.top)
            
            TabView(selection: $selectedTab) {
                // Models Tab
                ModelsTab()
                    .tabItem {
                        Label("Models", systemImage: "cpu")
                    }
                    .tag(0)
                
                // Tasks Tab
                TasksTab()
                    .tabItem {
                        Label("Tasks", systemImage: "list.bullet.clipboard")
                    }
                    .tag(1)
                
                // Execution Tab
                ExecutionTab()
                    .tabItem {
                        Label("Execution", systemImage: "gearshape.2")
                    }
                    .tag(2)
                
                // Memory Tab
                MemoryTab()
                    .tabItem {
                        Label("Memory", systemImage: "brain")
                    }
                    .tag(3)
            }
            .padding()
        }
    }
}

// MARK: - Models Tab
struct ModelsTab: View {
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    @State private var newModelName = ""
    @State private var newModelType = ""
    @State private var newModelCapabilities = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Registered Models")
                .font(.headline)
                .padding(.bottom, 5)
            
            List {
                ForEach(modelOrchestrator.modelRegistry.getAllRegisteredModels(), id: \.id) { model in
                    VStack(alignment: .leading) {
                        Text(model.modelType.rawValue)
                            .font(.headline)
                        Text("Type: \(model.modelType.rawValue)")
                            .font(.subheadline)
                        Text("Status: \(model.isLoaded ? "Loaded" : "Not Loaded")")
                            .font(.subheadline)
                            .foregroundColor(model.isLoaded ? .green : .red)
                        Text("Capabilities: \(model.capabilities.supportedTasks.map { $0.rawValue }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
            
            Divider()
            
            Text("Register New Model")
                .font(.headline)
                .padding(.top, 10)
            
            HStack {
                TextField("Model Name", text: $newModelName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Model Type", text: $newModelType)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            TextField("Capabilities (comma separated)", text: $newModelCapabilities)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Register Model") {
                registerNewModel()
            }
            .padding(.top, 5)
            .disabled(newModelName.isEmpty || newModelType.isEmpty)
        }
        .padding()
    }
    
    private func registerNewModel() {
        let taskTypes = newModelCapabilities
            .split(separator: ",")
            .map { String($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
            .compactMap { TaskType(rawValue: $0) }
        
        if let modelType = JanetModelType(rawValue: newModelType.lowercased()) {
            let capabilities = ModelCapabilities(
                supportedTasks: taskTypes,
                reasoningAbility: .medium,
                contextWindow: 4096,
                isLocalOnly: true
            )
            
            let newModel = RegisteredModel(
                modelType: modelType,
                capabilities: capabilities,
                priority: 10
            )
            
            modelOrchestrator.modelRegistry.registerModel(newModel)
            
            // Clear the form
            newModelName = ""
            newModelType = ""
            newModelCapabilities = ""
        }
    }
}

// MARK: - Tasks Tab
struct TasksTab: View {
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    @State private var taskTypesList = ["Conversation", "Code Generation", "Image Analysis", "Data Analysis", "Summarization"]
    @State private var selectedTaskType = "Conversation"
    @State private var taskDescription = ""
    @State private var analysisResult = ""
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "TasksTab")
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Task Analysis Configuration")
                .font(.headline)
                .padding(.bottom, 5)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Types")
                        .font(.headline)
                    
                    ForEach(taskTypesList, id: \.self) { taskType in
                        Text(taskType)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Task Type")
                        .font(.headline)
                    
                    TextField("Task Type", text: $selectedTaskType)
                    
                    TextField("Required Capabilities", text: $taskDescription)
                    
                    Button("Add Task Type") {
                        addTaskType()
                    }
                    .disabled(selectedTaskType.isEmpty || taskDescription.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Task Analysis")
                        .font(.headline)
                    
                    TextEditor(text: $taskDescription)
                        .frame(height: 100)
                    
                    Button("Analyze Task") {
                        analyzeTask()
                    }
                    .disabled(taskDescription.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    private func addTaskType() {
        logger.warning("addTaskType functionality is not implemented")
        taskTypesList.append(selectedTaskType)
        selectedTaskType = ""
        taskDescription = ""
    }
    
    private func analyzeTask() {
        logger.warning("analyzeTask functionality is not implemented")
        analysisResult = "Analysis result would appear here"
    }
    
    private func deleteTaskType(at offsets: IndexSet) {
        taskTypesList.remove(atOffsets: offsets)
    }
}

// MARK: - Execution Tab
struct ExecutionTab: View {
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    @State private var executionMode: String = "Auto"
    @State private var executionModes = ["Auto", "Manual", "Hybrid"]
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "ExecutionTab")
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Execution Configuration")
                .font(.headline)
                .padding(.bottom, 5)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Execution Mode")
                        .font(.headline)
                    
                    Picker("Execution Mode", selection: $executionMode) {
                        ForEach(executionModes, id: \.self) { mode in
                            Text(mode)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Button("Apply Settings") {
                        applyExecutionSettings()
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Execution Settings")
                        .font(.headline)
                    
                    Toggle("Enable Parallel Execution", isOn: .constant(executionMode == "Parallel"))
                        .disabled(true)
                    
                    Toggle("Enable Fallback", isOn: .constant(executionMode == "Hybrid"))
                        .disabled(true)
                    
                    Stepper("Max Retries: 3", 
                            value: .constant(3),
                            in: 1...5)
                        .disabled(true)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    private func applyExecutionSettings() {
        logger.warning("applyExecutionSettings functionality is not implemented")
    }
}

// MARK: - Memory Tab
struct MemoryTab: View {
    @EnvironmentObject private var modelOrchestrator: ModelOrchestrator
    @State private var memoryContextSize = 5
    @State private var memoryRetentionDays = 30
    @State private var memoryQuery = ""
    @State private var memoryResults: [String] = []
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "MemoryTab")
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Memory Management")
                .font(.title)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Settings")
                        .font(.headline)
                    
                    Toggle("Enable Vector Memory", isOn: Binding<Bool>(
                        get: { modelOrchestrator.memoryContextManager.useVectorMemory },
                        set: { _ in }
                    ))
                    
                    Toggle("Enable External Knowledge Sources", isOn: Binding<Bool>(
                        get: { modelOrchestrator.memoryContextManager.useExternalSources },
                        set: { _ in }
                    ))
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Search")
                        .font(.headline)
                    
                    TextField("Search memory...", text: $memoryQuery)
                    
                    Button("Search") {
                        searchMemory()
                    }
                    
                    if !memoryResults.isEmpty {
                        ForEach(memoryResults, id: \.self) { result in
                            Text(result)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    private func searchMemory() {
        logger.warning("searchMemory functionality is not implemented")
        memoryResults = ["Sample memory 1", "Sample memory 2", "Sample memory 3"]
    }
}

// MARK: - Preview
struct OrchestratorView_Previews: PreviewProvider {
    static var previews: some View {
        OrchestratorView()
            .environmentObject(ModelOrchestrator.shared)
    }
} 