//
//  OllamaService.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import Foundation
import Combine
import os

class OllamaService: ObservableObject {
    // Singleton instance
    static let shared = OllamaService()
    
    // Logger for this class
    private let logger = Logger(subsystem: "com.janet.ai", category: "OllamaService")
    
    /// The base URL for the Ollama API
    private var baseURL: String
    
    @Published var isRunning: Bool = false
    @Published var availableModels: [String] = ["phi:latest", "phi", "llama3:latest", "mistral:latest", "deepseek-coder:6.7b"]
    @Published var currentModel: String? = "phi:latest"
    @Published var apiURL: String = "http://localhost:11434/api"
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize the Ollama service
    public init() {
        logger.info("Initializing Ollama service")
        
        // Set the base URL for the Ollama API
        baseURL = "http://localhost:11434"
        
        // Set default values
        availableModels = []
        currentModel = nil
        
        // Check Ollama status and load models asynchronously
        Task {
            let isRunning = await checkOllamaStatus()
            logger.info("Ollama service is \(isRunning ? "running" : "not running")")
            
            if isRunning {
                await loadAvailableModels()
            }
        }
    }
    
    /// Check if the Ollama service is running
    public func checkOllamaStatus() async -> Bool {
        logger.info("Checking Ollama service status")
        
        // Create the request URL
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            logger.error("Invalid URL configuration")
            return false
        }
        
        do {
            // Create the request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Set a timeout for the request
            request.timeoutInterval = 5.0
            
            // Send the request
            let (_, response) = try await URLSession.shared.data(for: request)
            
            // Check the response status code
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response from Ollama service")
                return false
            }
            
            let isRunning = httpResponse.statusCode == 200
            logger.info("Ollama service is \(isRunning ? "running" : "not running")")
            return isRunning
        } catch {
            logger.error("Error checking Ollama status: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Load available models from the Ollama API
    public func loadAvailableModels() async {
        logger.info("Loading available models from Ollama API")
        
        // Check if Ollama is running
        let isRunning = await checkOllamaStatus()
        if !isRunning {
            logger.error("Ollama service is not running, cannot load models")
            availableModels = []
            return
        }
        
        // Create the request URL
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            logger.error("Invalid URL")
            availableModels = []
            return
        }
        
        do {
            // Create the request
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Set a timeout for the request
            request.timeoutInterval = 10.0
            
            // Send the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check the response status code
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response")
                availableModels = []
                return
            }
            
            if httpResponse.statusCode != 200 {
                logger.error("HTTP error: \(httpResponse.statusCode)")
                availableModels = []
                return
            }
            
            // Parse the response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                
                // Extract model names
                let modelNames = models.compactMap { $0["name"] as? String }
                
                // Update available models
                availableModels = modelNames
                
                // Set current model if not already set
                if currentModel == nil || currentModel!.isEmpty, let firstModel = modelNames.first {
                    currentModel = firstModel
                }
                
                logger.info("Loaded \(modelNames.count) models: \(modelNames.joined(separator: ", "))")
            } else {
                logger.error("Failed to parse models response")
                availableModels = []
            }
        } catch {
            logger.error("Error loading models: \(error.localizedDescription)")
            availableModels = []
        }
    }
    
    /// Generate a response from the Ollama API
    public func generateResponse(prompt: String) async -> String {
        logger.info("Generating response from Ollama API")
        
        // Check if Ollama is running
        let isRunning = await checkOllamaStatus()
        if !isRunning {
            logger.error("Ollama service is not running")
            return "Error: Ollama service is not running. Please start Ollama and try again."
        }
        
        // Ensure we have a model selected
        guard let currentModel = currentModel, !currentModel.isEmpty else {
            logger.error("No model selected")
            return "Error: No model selected. Please select a model in settings."
        }
        
        // Create the request URL
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            logger.error("Invalid URL")
            return "Error: Invalid URL configuration"
        }
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": currentModel,
            "prompt": prompt,
            "stream": false
        ]
        
        do {
            // Convert the request body to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Create the request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Set a timeout for the request
            request.timeoutInterval = 30.0
            
            // Send the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check the response status code
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response")
                return "Error: Invalid response from Ollama service"
            }
            
            if httpResponse.statusCode != 200 {
                logger.error("HTTP error: \(httpResponse.statusCode)")
                
                // Try to parse error message from response
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorJson["error"] as? String {
                    return "Error: \(errorMessage)"
                }
                
                return "Error: HTTP error \(httpResponse.statusCode)"
            }
            
            // Parse the response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                return response
            } else {
                logger.error("Failed to parse response")
                return "Error: Failed to parse response from Ollama"
            }
        } catch {
            logger.error("Error generating response: \(error.localizedDescription)")
            return "Error: \(error.localizedDescription)"
        }
    }
    
    // Stream response from Ollama API
    func streamResponse(prompt: String) -> AsyncStream<String> {
        return AsyncStream<String> { continuation in
            Task {
                guard let url = URL(string: "\(apiURL)/generate") else {
                    continuation.yield("Error: Invalid Ollama API URL")
                    continuation.finish()
                    return
                }
                
                let parameters: [String: Any] = [
                    "model": currentModel ?? "phi:latest",
                    "prompt": prompt,
                    "stream": true,
                    "options": [
                        "temperature": 0.7,
                        "top_p": 0.9,
                        "num_predict": 1024
                    ]
                ]
                
                guard let requestData = try? JSONSerialization.data(withJSONObject: parameters) else {
                    continuation.yield("Error: Could not create request data")
                    continuation.finish()
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = requestData
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                do {
                    let (data, _) = try await URLSession.shared.bytes(for: request)
                    var responseText = ""
                    
                    for try await line in data.lines {
                        // Parse the streaming response
                        if let data = line.data(using: .utf8),
                           let response = try? JSONDecoder().decode(OllamaStreamResponse.self, from: data) {
                            responseText += response.response
                            continuation.yield(response.response)
                            
                            if response.done {
                                break
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    logger.error("Error streaming response: \(error)")
                    continuation.yield("Error occurred while streaming response")
                    continuation.finish()
                }
            }
        }
    }
    
    // Pull DeepSeek Coder model from Ollama
    func pullDeepSeekCoder() async -> Bool {
        logger.info("Pulling DeepSeek Coder model from Ollama")
        
        // Construct the URL
        guard let url = URL(string: "\(apiURL)/pull") else {
            logger.error("Invalid URL for Ollama API")
            return false
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let body: [String: Any] = [
            "name": "deepseek-coder:6.7b",
            "stream": false
        ]
        
        // Serialize the body
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            logger.error("Failed to serialize request body")
            return false
        }
        
        request.httpBody = httpBody
        
        // Send the request
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response from Ollama API")
                return false
            }
            
            let success = httpResponse.statusCode == 200
            
            if success {
                logger.info("Successfully pulled DeepSeek Coder model")
                
                // Add the model to the available models if not already present
                await MainActor.run {
                    if !self.availableModels.contains("deepseek-coder:6.7b") {
                        self.availableModels.append("deepseek-coder:6.7b")
                    }
                }
            } else {
                logger.error("Failed to pull DeepSeek Coder model: HTTP \(httpResponse.statusCode)")
            }
            
            return success
        } catch {
            logger.error("Failed to pull DeepSeek Coder model: \(error.localizedDescription)")
            return false
        }
    }
    
    // Test DeepSeek Coder model
    func testDeepSeekCoder() async -> (success: Bool, output: String) {
        logger.info("Testing DeepSeek Coder model")
        
        // Construct the URL
        guard let url = URL(string: "\(apiURL)/generate") else {
            logger.error("Invalid URL for Ollama API")
            return (false, "Invalid URL for Ollama API")
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let body: [String: Any] = [
            "model": "deepseek-coder:6.7b",
            "prompt": "Write a function to calculate the fibonacci sequence in JavaScript",
            "stream": false
        ]
        
        // Serialize the body
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            logger.error("Failed to serialize request body")
            return (false, "Failed to serialize request body")
        }
        
        request.httpBody = httpBody
        
        // Send the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response from Ollama API")
                return (false, "Invalid response from Ollama API")
            }
            
            let success = httpResponse.statusCode == 200
            
            if success {
                // Parse the response
                if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = responseDict["response"] as? String {
                    logger.info("Successfully tested DeepSeek Coder model")
                    return (true, output)
                } else {
                    logger.error("Failed to parse response from Ollama API")
                    return (false, "Failed to parse response from Ollama API")
                }
            } else {
                logger.error("Failed to test DeepSeek Coder model: HTTP \(httpResponse.statusCode)")
                return (false, "Failed to test DeepSeek Coder model: HTTP \(httpResponse.statusCode)")
            }
        } catch {
            logger.error("Failed to test DeepSeek Coder model: \(error.localizedDescription)")
            return (false, "Failed to test DeepSeek Coder model: \(error.localizedDescription)")
        }
    }
}

// MARK: - Response Models

// Renamed from OllamaModel to OllamaModelInfo to avoid conflicts with the class in ModelInterface.swift
struct OllamaModelInfo: Codable {
    let name: String
    let model: String
    let modified_at: String
    let size: Int64
    let digest: String
    
    // Explicit Codable conformance
    enum CodingKeys: String, CodingKey {
        case name
        case model
        case modified_at
        case size
        case digest
    }
}

// Add OllamaModel struct for backward compatibility
struct OllamaModel: Codable {
    let name: String
    let modified_at: String
    let size: Int64
}

struct OllamaTagsResponse: Codable {
    let models: [OllamaModelInfo]
    
    // Explicit Codable conformance
    enum CodingKeys: String, CodingKey {
        case models
    }
}

struct OllamaGenerateResponse: Codable {
    let model: String
    let created_at: String
    let response: String
    let done: Bool
    let context: [Int]?
    let total_duration: Int64?
    let load_duration: Int64?
    let prompt_eval_count: Int?
    let prompt_eval_duration: Int64?
    let eval_count: Int?
    let eval_duration: Int64?
    
    // Explicit Codable conformance
    enum CodingKeys: String, CodingKey {
        case model
        case created_at
        case response
        case done
        case context
        case total_duration
        case load_duration
        case prompt_eval_count
        case prompt_eval_duration
        case eval_count
        case eval_duration
    }
}

struct OllamaStreamResponse: Codable {
    let model: String
    let created_at: String?
    let response: String
    let done: Bool
    
    // Explicit Codable conformance
    enum CodingKeys: String, CodingKey {
        case model
        case created_at
        case response
        case done
    }
}
