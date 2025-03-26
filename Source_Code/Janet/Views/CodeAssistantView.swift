//
//  CodeAssistantView.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import SwiftUI
import Combine

/// View for interacting with code generation models
struct CodeAssistantView: View {
    // MARK: - Environment
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    @StateObject private var manager = CodeAssistantManager.shared
    @State private var prompt: String = ""
    @State private var language: String = "Swift"
    @State private var generatedCode: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showTestResults: Bool = false
    @State private var testResults: [CodeTestResult] = []
    @State private var showComparisonResults: Bool = false
    @State private var comparisonResults: [ModelComparisonResult] = []
    @State private var selectedTab: Int = 0
    @State private var isRunningTests: Bool = false
    
    // MARK: - Constants
    
    private let languages = ["Swift", "Python", "JavaScript", "TypeScript", "Java", "C++", "Go", "Rust", "Ruby", "PHP", "HTML", "CSS"]
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Tab view
            TabView(selection: $selectedTab) {
                // Code generation tab
                codeGenerationView
                    .tag(0)
                
                // Recent generations tab
                recentGenerationsView
                    .tag(1)
                
                // Testing tab
                testingView
                    .tag(2)
                
                // Settings tab
                settingsView
                    .tag(3)
            }
            .tabViewStyle(DefaultTabViewStyle())
            
            // Tab bar
            tabBar
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
        }
        .alert(isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showTestResults) {
            testResultsSheet
        }
        .sheet(isPresented: $showComparisonResults) {
            comparisonResultsSheet
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Code Assistant")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            // Model status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(manager.isModelAvailable ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(manager.isModelAvailable ? "Model Available" : "Model Unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Generate", systemImage: "terminal", tag: 0)
            tabButton(title: "History", systemImage: "clock", tag: 1)
            tabButton(title: "Testing", systemImage: "checklist", tag: 2)
            tabButton(title: "Settings", systemImage: "gear", tag: 3)
        }
    }
    
    private func tabButton(title: String, systemImage: String, tag: Int) -> some View {
        Button(action: {
            selectedTab = tag
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selectedTab == tag ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Code Generation View
    
    private var codeGenerationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Language picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Programming Language")
                        .font(.headline)
                    
                    Picker("Language", selection: $language) {
                        ForEach(languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Prompt input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt")
                        .font(.headline)
                    
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Generate button
                Button(action: generateCode) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            
                            Text("Generating...")
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("Generate Code")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manager.isModelAvailable ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!manager.isModelAvailable || isGenerating || prompt.isEmpty)
                
                // Generated code
                if !generatedCode.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Generated Code")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: copyToClipboard) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 16))
                            }
                        }
                        
                        ScrollView {
                            Text(generatedCode)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Recent Generations View
    
    private var recentGenerationsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Generations")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    manager.clearRecentGenerations()
                }) {
                    Text("Clear")
                        .font(.subheadline)
                }
                .disabled(manager.recentGenerations.isEmpty)
            }
            .padding(.horizontal)
            .padding(.top)
            
            if manager.recentGenerations.isEmpty {
                VStack {
                    Spacer()
                    
                    Text("No recent generations")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(manager.recentGenerations) { generation in
                        generationCell(generation)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private func generationCell(_ generation: CodeGeneration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(generation.language)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                Text(generation.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(generation.prompt)
                .lineLimit(2)
                .font(.subheadline)
            
            HStack {
                Text("\(String(format: "%.2f", generation.executionTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    prompt = generation.prompt
                    language = generation.language
                    generatedCode = generation.output
                    selectedTab = 0
                }) {
                    Text("Use Again")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    // MARK: - Testing View
    
    private var testingView: some View {
        let contentView = VStack(alignment: .leading, spacing: 16) {
            // Run tests
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Testing")
                    .font(.headline)
                
                Text("Run a series of tests to evaluate the DeepSeek Coder model's performance across different coding tasks.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: runTests) {
                    HStack {
                        Image(systemName: "checklist")
                        Text("Run Tests")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manager.isModelAvailable ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!manager.isModelAvailable || isGenerating)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Compare models
            VStack(alignment: .leading, spacing: 8) {
                Text("Model Comparison")
                    .font(.headline)
                
                Text("Compare DeepSeek Coder with other models like Phi and Llama3 on a set of coding tasks.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: compareModels) {
                    HStack {
                        Image(systemName: "chart.bar")
                        Text("Compare Models")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manager.isModelAvailable ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!manager.isModelAvailable || isGenerating)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Performance metrics
            VStack(alignment: .leading, spacing: 8) {
                Text("Performance Metrics")
                    .font(.headline)
                
                HStack {
                    metricView(
                        title: "Total Requests",
                        value: "\(manager.performanceMetrics.totalRequests)"
                    )
                    
                    metricView(
                        title: "Failed Requests",
                        value: "\(manager.performanceMetrics.failedRequests)"
                    )
                }
                
                HStack {
                    metricView(
                        title: "Avg. Response Time",
                        value: String(format: "%.2f s", manager.performanceMetrics.averageExecutionTime)
                    )
                    
                    metricView(
                        title: "Tokens/Second",
                        value: manager.performanceMetrics.totalExecutionTime > 0 ? 
                            String(format: "%.1f", 1000 / manager.performanceMetrics.averageExecutionTime) : 
                            "N/A"
                    )
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        
        return ScrollView {
            contentView
                .padding()
        }
    }
    
    private func metricView(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Settings View
    
    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Model version
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Version")
                        .font(.headline)
                    
                    Picker("Model Version", selection: $manager.modelVersion) {
                        Text("DeepSeek Coder 6.7B").tag("deepseek-coder:6.7b")
                        Text("DeepSeek Coder 33B").tag("deepseek-coder:33b")
                        Text("DeepSeek Coder Instruct").tag("deepseek-coder-instruct:latest")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Pull model
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model Management")
                        .font(.headline)
                    
                    Text("Pull the selected model from Ollama's model repository.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: pullModel) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Pull Model")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isGenerating)
                }
                
                // About
                VStack(alignment: .leading, spacing: 8) {
                    Text("About DeepSeek Coder")
                        .font(.headline)
                    
                    Text("DeepSeek Coder is a code language model trained on a high-quality code corpus. It excels at code generation, understanding, and editing tasks across multiple programming languages.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Link(destination: URL(string: "https://github.com/deepseek-ai/DeepSeek-Coder")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("Visit GitHub Repository")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Test Results Sheet
    
    private var testResultsSheet: some View {
        NavigationView {
            testResultsList
            .navigationTitle("Test Results")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        showTestResults = false
                    }
                }
            }
        }
    }
    
    private var testResultsList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(testResults, id: \.testCase.name) { result in
                    testResultCell(result)
                }
            }
            .padding()
        }
    }
    
    private func testResultCell(_ result: CodeTestResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.testCase.name)
                    .font(.headline)
                Spacer()
                Text(result.success ? "Passed" : "Failed")
                    .foregroundColor(result.success ? .green : .red)
                    .fontWeight(.semibold)
            }
            
            Text("Execution Time: \(String(format: "%.2f", result.executionTime))s")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !result.success, let error = result.errorMessage {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if !result.output.isEmpty {
                Text("Output:")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(result.output)
                    .font(.caption)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Comparison Results Sheet
    
    private var comparisonResultsSheet: some View {
        NavigationView {
            List {
                ForEach(comparisonResults, id: \.testCase.name) { result in
                    comparisonResultCell(result)
                }
            }
            .navigationTitle("Model Comparison")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        showComparisonResults = false
                    }
                }
            }
        }
    }
    
    private func comparisonResultCell(_ result: ModelComparisonResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.testCase.name)
                .font(.headline)
            
            Text(result.testCase.prompt)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            if result.modelResults.isEmpty {
                Text("No model results available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(result.modelResults.keys.sorted(), id: \.self) { modelName in
                    if let modelResult = result.modelResults[modelName] {
                        HStack {
                            Text(modelName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: modelResult.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(modelResult.passed ? .green : .red)
                                
                                Text("\(String(format: "%.2f", modelResult.executionTime))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .background(modelName == result.bestModel ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(4)
                    }
                }
            }
            
            if let bestModel = result.bestModel {
                HStack {
                    Text("Best Model:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(bestModel)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateCode() {
        guard !prompt.isEmpty else { return }
        
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                let code = try await manager.generateCodeWithRetry(
                    prompt: prompt,
                    language: language
                )
                
                await MainActor.run {
                    generatedCode = code
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedCode, forType: .string)
    }
    
    private func runTests() {
        isRunningTests = true
        
        Task {
            let results = await manager.runTests()
            
            DispatchQueue.main.async {
                self.testResults = results
                self.isRunningTests = false
            }
        }
    }
    
    private func compareModels() {
        isGenerating = true
        
        Task {
            let results = await manager.compareWithOtherModels()
            
            await MainActor.run {
                comparisonResults = results
                showComparisonResults = true
                isGenerating = false
            }
        }
    }
    
    private func pullModel() {
        isGenerating = true
        
        Task {
            let success = await manager.pullModel()
            
            await MainActor.run {
                if !success {
                    errorMessage = "Failed to pull model"
                }
                isGenerating = false
            }
        }
    }
}

// MARK: - Extensions

extension TestCategory {
    var description: String {
        switch self {
        case .basicFunctionality:
            return "Basic"
        case .algorithmImplementation:
            return "Algorithm"
        case .debugging:
            return "Debug"
        case .apiIntegration:
            return "API"
        case .dataStructures:
            return "Data Structure"
        case .complexAlgorithms:
            return "Complex"
        case .codeRefactoring:
            return "Refactor"
        case .unitTesting:
            return "Testing"
        case .designPatterns:
            return "Design Pattern"
        case .errorHandling:
            return "Error Handling"
        }
    }
}

// MARK: - Preview

struct CodeAssistantView_Previews: PreviewProvider {
    static var previews: some View {
        CodeAssistantView()
    }
} 