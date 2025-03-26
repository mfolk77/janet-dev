//
//  OrchestratorSettingsView.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import SwiftUI

/// View for configuring the Orchestrator settings
struct OrchestratorSettingsView: View {
    // MARK: - Environment
    
    /// The environment object for the orchestrator
    @EnvironmentObject private var orchestrator: ModelOrchestrator
    
    // MARK: - State
    
    /// The selected execution mode
    @State private var selectedExecutionMode: ExecutionMode = .auto
    
    /// The selected model type
    @State private var selectedModelType: JanetModelType = .ollama
    
    /// Whether to show the model details sheet
    @State private var showModelDetails = false
    
    /// The selected model for details
    @State private var selectedModelForDetails: RegisteredModel?
    
    /// The models in the chain
    @State private var chainedModels: [JanetModelType] = []
    
    /// The selected models for the ensemble
    @State private var selectedModels: Set<JanetModelType> = []
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // Execution Mode Section
                Section(header: Text("Execution Mode")) {
                    Picker("Mode", selection: $selectedExecutionMode) {
                        Text("Auto").tag(ExecutionMode.auto)
                        Text("Single").tag(ExecutionMode.single)
                        Text("Chain").tag(ExecutionMode.chain)
                        Text("Parallel").tag(ExecutionMode.parallel)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedExecutionMode) { oldValue, newValue in
                        orchestrator.executionMode = newValue
                    }
                    
                    Text(executionModeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Available Models Section
                Section(header: Text("Available Models")) {
                    ForEach(orchestrator.availableModels) { model in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                    .font(.headline)
                                
                                Text(taskTypesString(for: model))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Model status indicator
                            Circle()
                                .fill(model.isLoaded ? Color.green : Color.gray)
                                .frame(width: 10, height: 10)
                            
                            // Load/Unload button
                            Button(action: {
                                toggleModelLoad(model)
                            }) {
                                Text(model.isLoaded ? "Unload" : "Load")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            
                            // Details button
                            Button(action: {
                                selectedModelForDetails = model
                                showModelDetails = true
                            }) {
                                Image(systemName: "info.circle")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Memory Context Section
                Section(header: Text("Memory Context")) {
                    Button(action: {
                        orchestrator.memoryContextManager.clearAllContexts()
                    }) {
                        Label("Clear All Contexts", systemImage: "trash")
                    }
                    
                    NavigationLink(destination: MemoryContextView()) {
                        Label("View Memory Contexts", systemImage: "brain")
                    }
                }
                
                // Advanced Settings Section
                Section(header: Text("Advanced Settings")) {
                    NavigationLink(destination: ModelChainView()) {
                        Label("Configure Model Chains", systemImage: "link")
                    }
                    
                    NavigationLink(destination: ParallelExecutionView()) {
                        Label("Configure Parallel Execution", systemImage: "square.grid.2x2")
                    }
                }
            }
            .listStyle(DefaultListStyle())
            .navigationTitle("Orchestrator Settings")
            .sheet(isPresented: $showModelDetails) {
                if let model = selectedModelForDetails {
                    ModelDetailsView(model: model)
                }
            }
        }
        .onAppear {
            // Initialize with current orchestrator settings
            selectedExecutionMode = orchestrator.executionMode
        }
    }
    
    // MARK: - Computed Properties
    
    /// Description of the selected execution mode
    private var executionModeDescription: String {
        switch selectedExecutionMode {
        case .auto:
            return "Automatically select the best execution strategy based on the task."
        case .single:
            return "Use a single model for all tasks."
        case .chain:
            return "Chain multiple models together, passing the output of one model to the next."
        case .parallel:
            return "Execute multiple models in parallel and combine their results."
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get a string representation of the task types supported by a model
    /// - Parameter model: The model
    /// - Returns: A string representation of the supported task types
    private func taskTypesString(for model: RegisteredModel) -> String {
        let taskTypes = model.capabilities.supportedTasks.map { $0.rawValue.capitalized }
        return taskTypes.joined(separator: ", ")
    }
    
    /// Toggle the load state of a model
    /// - Parameter model: The model to toggle
    private func toggleModelLoad(_ model: RegisteredModel) {
        Task {
            if model.isLoaded {
                await orchestrator.unloadModel(modelType: model.modelType)
            } else {
                do {
                    try await orchestrator.loadModel(modelType: model.modelType)
                } catch {
                    print("Error loading model: \(error)")
                }
            }
        }
    }
    
    /// Add a model to the chain
    /// - Parameter modelType: The model type to add
    private func addModelToChain(_ modelType: JanetModelType) {
        chainedModels.append(modelType)
    }
}

// MARK: - Model Details View

/// View for displaying model details
struct ModelDetailsView: View {
    // MARK: - Properties
    
    /// The model to display details for
    let model: RegisteredModel
    
    /// Whether to dismiss the view
    @Environment(\.presentationMode) private var presentationMode
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Basic Information")) {
                    LabeledContent("Name", value: model.displayName)
                    LabeledContent("Type", value: model.modelType.rawValue.capitalized)
                    LabeledContent("Status", value: model.isLoaded ? "Loaded" : "Not Loaded")
                    LabeledContent("Priority", value: "\(model.priority)")
                }
                
                Section(header: Text("Capabilities")) {
                    LabeledContent("Reasoning Ability", value: model.capabilities.reasoningAbility.rawValue.capitalized)
                    LabeledContent("Context Window", value: "\(model.capabilities.contextWindow) tokens")
                    LabeledContent("Local Only", value: model.capabilities.isLocalOnly ? "Yes" : "No")
                }
                
                Section(header: Text("Supported Tasks")) {
                    ForEach(model.capabilities.supportedTasks, id: \.self) { task in
                        Text(task.rawValue.capitalized)
                    }
                }
            }
            .navigationTitle("Model Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Memory Context View

/// View for displaying memory contexts
struct MemoryContextView: View {
    // MARK: - Environment
    
    /// The environment object for the orchestrator
    @EnvironmentObject private var orchestrator: ModelOrchestrator
    
    // MARK: - State
    
    /// The selected model type for filtering
    @State private var selectedModelType: JanetModelType?
    
    /// The search text
    @State private var searchText = ""
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            // Model filter picker
            Picker("Filter by Model", selection: $selectedModelType) {
                Text("All Models").tag(nil as JanetModelType?)
                ForEach(JanetModelType.allCases, id: \.self) { modelType in
                    Text(modelType.rawValue.capitalized).tag(modelType as JanetModelType?)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Search field
            TextField("Search interactions", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            // Interactions list
            List {
                ForEach(filteredInteractions) { interaction in
                    VStack(alignment: .leading) {
                        Text("Prompt: \(interaction.prompt)")
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text("Response: \(interaction.response)")
                            .font(.body)
                            .lineLimit(3)
                        
                        Text("Models: \(modelsString(for: interaction))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Time: \(formattedDate(interaction.timestamp))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Memory Contexts")
    }
    
    // MARK: - Computed Properties
    
    /// Filtered interactions based on the selected model type and search text
    private var filteredInteractions: [ModelInteraction] {
        let interactions = orchestrator.memoryContextManager.getAllContexts()
        
        // Filter by model type if selected
        let modelFiltered = selectedModelType == nil ? interactions : interactions.filter { interaction in
            interaction.models.contains(selectedModelType!)
        }
        
        // Filter by search text if provided
        if searchText.isEmpty {
            return modelFiltered
        } else {
            return modelFiltered.filter { interaction in
                interaction.prompt.lowercased().contains(searchText.lowercased()) ||
                interaction.response.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get a string representation of the models used in an interaction
    /// - Parameter interaction: The interaction
    /// - Returns: A string representation of the models
    private func modelsString(for interaction: ModelInteraction) -> String {
        let modelNames = interaction.models.map { $0.rawValue.capitalized }
        return modelNames.joined(separator: ", ")
    }
    
    /// Format a date for display
    /// - Parameter date: The date to format
    /// - Returns: A formatted date string
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Model Chain View

/// View for configuring model chains
struct ModelChainView: View {
    // MARK: - Environment
    
    /// The environment object for the orchestrator
    @EnvironmentObject private var orchestrator: ModelOrchestrator
    
    // MARK: - State
    
    /// The models in the chain
    @State private var chainedModels: [JanetModelType] = []
    
    /// The prompt for testing
    @State private var testPrompt = "Test the model chain with this prompt."
    
    /// The result of the test
    @State private var testResult = ""
    
    /// Whether a test is in progress
    @State private var isTestingChain = false
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            // Available models
            Section(header: Text("Available Models").font(.headline)) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(orchestrator.availableModels.filter { $0.isLoaded }) { model in
                            Button(action: {
                                addModelToChain(model.modelType)
                            }) {
                                Text(model.displayName)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            
            // Current chain
            Section(header: Text("Current Chain").font(.headline)) {
                VStack {
                    if chainedModels.isEmpty {
                        Text("No models in chain")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        HStack {
                            ForEach(chainedModels.indices, id: \.self) { index in
                                HStack {
                                    Text(chainedModels[index].rawValue.capitalized)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                    
                                    if index < chainedModels.count - 1 {
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        
                        Button(action: {
                            chainedModels.removeAll()
                        }) {
                            Text("Clear Chain")
                                .foregroundColor(.red)
                        }
                        .padding(.bottom)
                    }
                }
            }
            
            // Test section
            Section(header: Text("Test Chain").font(.headline)) {
                VStack {
                    TextField("Enter test prompt", text: $testPrompt)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: {
                        testChain()
                    }) {
                        Text("Test Chain")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(chainedModels.isEmpty || isTestingChain)
                    .padding(.bottom)
                    
                    if isTestingChain {
                        ProgressView()
                            .padding()
                    }
                    
                    if !testResult.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Result:")
                                .font(.headline)
                            
                            ScrollView {
                                Text(testResult)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .frame(height: 200)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Model Chain Configuration")
    }
    
    // MARK: - Helper Methods
    
    /// Add a model to the chain
    /// - Parameter modelType: The model type to add
    private func addModelToChain(_ modelType: JanetModelType) {
        chainedModels.append(modelType)
    }
    
    /// Test the current chain
    private func testChain() {
        guard !chainedModels.isEmpty else { return }
        
        isTestingChain = true
        testResult = ""
        
        Task {
            do {
                let result = try await orchestrator.executeModelChain(
                    prompt: testPrompt,
                    modelChain: chainedModels
                )
                
                await MainActor.run {
                    testResult = result
                    isTestingChain = false
                }
            } catch {
                await MainActor.run {
                    testResult = "Error: \(error.localizedDescription)"
                    isTestingChain = false
                }
            }
        }
    }
}

// MARK: - Parallel Execution View

/// View for configuring parallel execution
struct ParallelExecutionView: View {
    // MARK: - Environment
    
    /// The environment object for the orchestrator
    @EnvironmentObject private var orchestrator: ModelOrchestrator
    
    // MARK: - State
    
    /// The selected models for parallel execution
    @State private var selectedModels: Set<JanetModelType> = []
    
    /// The selected combination strategy
    @State private var combinationStrategy: CombinationStrategy = .best
    
    /// The prompt for testing
    @State private var testPrompt = "Test parallel execution with this prompt."
    
    /// The result of the test
    @State private var testResult = ""
    
    /// Whether a test is in progress
    @State private var isTesting = false
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            // Model selection
            Section(header: Text("Select Models").font(.headline)) {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(orchestrator.availableModels.filter { $0.isLoaded }) { model in
                            Toggle(model.displayName, isOn: Binding(
                                get: { selectedModels.contains(model.modelType) },
                                set: { newValue in
                                    if newValue {
                                        selectedModels.insert(model.modelType)
                                    } else {
                                        selectedModels.remove(model.modelType)
                                    }
                                }
                            ))
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
                .frame(height: 200)
            }
            
            // Combination strategy
            Section(header: Text("Combination Strategy").font(.headline)) {
                Picker("Strategy", selection: $combinationStrategy) {
                    Text("Best").tag(CombinationStrategy.best)
                    Text("Concatenate").tag(CombinationStrategy.concatenate)
                    Text("Summarize").tag(CombinationStrategy.summarize)
                    Text("Vote").tag(CombinationStrategy.vote)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Text(strategyDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // Test section
            Section(header: Text("Test Parallel Execution").font(.headline)) {
                VStack {
                    TextField("Enter test prompt", text: $testPrompt)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: {
                        testParallelExecution()
                    }) {
                        Text("Test Execution")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(selectedModels.count < 2 || isTesting)
                    .padding(.bottom)
                    
                    if isTesting {
                        ProgressView()
                            .padding()
                    }
                    
                    if !testResult.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Result:")
                                .font(.headline)
                            
                            ScrollView {
                                Text(testResult)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .frame(height: 200)
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("Parallel Execution Configuration")
    }
    
    // MARK: - Computed Properties
    
    /// Description of the selected combination strategy
    private var strategyDescription: String {
        switch combinationStrategy {
        case .best:
            return "Use the result from the best model (highest priority)."
        case .concatenate:
            return "Concatenate the results from all models."
        case .summarize:
            return "Summarize the results from all models into a single coherent response."
        case .vote:
            return "Use a voting mechanism to select the best result."
        }
    }
    
    // MARK: - Helper Methods
    
    /// Test parallel execution with the selected models and strategy
    private func testParallelExecution() {
        guard selectedModels.count >= 2 else { return }
        
        isTesting = true
        testResult = ""
        
        Task {
            do {
                let result = try await orchestrator.executeParallel(
                    prompt: testPrompt,
                    models: Array(selectedModels),
                    combinationStrategy: combinationStrategy
                )
                
                await MainActor.run {
                    testResult = result
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "Error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Preview

struct OrchestratorSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        OrchestratorSettingsView()
            .environmentObject(ModelOrchestrator.shared)
    }
} 