//
//  OllamaService.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import Foundation
import Combine

class OllamaService: ObservableObject {
    // Singleton instance
    static let shared = OllamaService()
    
    @Published var isRunning: Bool = false
    @Published var availableModels: [String] = ["phi", "phi:latest", "llama2", "mistral:latest"]
    @Published var currentModel: String = "phi"
    @Published var apiURL: String = "http://localhost:11434/api"
    @Published var useMockMode: Bool = false  // Online mode by default
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Use online mode by default
        useMockMode = false
        isRunning = false
        
        // Add default models that will be available in offline mode
        if self.availableModels.isEmpty {
            self.availableModels = ["phi", "phi:latest", "llama2", "mistral:latest", "gemma:7b"]
        }
        
        print("Janet initialized in ONLINE MODE by default")
    }
    
    // Check if Ollama is running
    func checkOllamaStatus() async -> Bool {
        // Skip network check if in mock mode
        if useMockMode {
            await MainActor.run {
                self.isRunning = true
                
                // Ensure models are available
                if self.availableModels.isEmpty {
                    self.availableModels = ["phi", "phi:latest", "llama2", "mistral:latest", "gemma:7b"]
                }
            }
            return true
        }
        
        // *** DEBUGGING INFORMATION *** 
        print("JANET DEBUG CONNECTION INFO:")
        print("Current API URL: \(apiURL)")
        print("Current Mock Mode: \(useMockMode)")
        print("Current Models: \(availableModels)")
        print("Try connecting to Ollama...")
        
        // Try all possible URLs in sequence
        let possibleURLs = [
            "http://localhost:11434/api",
            "http://127.0.0.1:11434/api", 
            "http://0.0.0.0:11434/api"
        ]
        
        for urlBase in possibleURLs {
            let urlString = "\(urlBase)/version"
            print("DEBUG: Trying Ollama at URL: \(urlString)")
            
            guard let url = URL(string: urlString) else {
                print("DEBUG: Invalid URL: \(urlString)")
                continue
            }
        
            do {
                print("DEBUG: Making request to Ollama API at \(urlString)...")
                // Use a more reliable configuration with timeout
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 5.0 // increased timeout
                let session = URLSession(configuration: config)
                
                let (data, response) = try await session.data(from: url)
                let httpResponse = response as? HTTPURLResponse
                let statusCode = httpResponse?.statusCode ?? 0
                let isRunning = statusCode == 200
                
                print("DEBUG: Ollama API response status: \(statusCode)")
                
                if isRunning {
                    // If this URL works, update the apiURL to this working one
                    self.apiURL = urlBase
                    print("SUCCESS: Connected to Ollama at \(urlBase)")
                    
                    // Try to parse and print models for debugging
                    do {
                        let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
                        print("DEBUG: Found \(response.models.count) models")
                    } catch {
                        print("DEBUG: Could not parse models: \(error)")
                    }
                    
                    await MainActor.run {
                        self.isRunning = true
                    }
                    
                    return true
                }
            } catch {
                print("DEBUG: Failed to connect to \(urlString): \(error.localizedDescription)")
                // Continue to next URL
            }
        }
        
        // If we get here, all URLs failed
        print("ERROR: Failed to connect to Ollama on any URL")
        await MainActor.run {
            self.isRunning = false
            
            // Keep useMockMode unchanged - user should manually toggle it if needed
            print("NOTICE: All connection attempts failed. Try enabling mock mode in settings if needed.")
            
            // Add default models only if in mock mode
            if self.useMockMode && self.availableModels.isEmpty {
                self.availableModels = ["phi", "phi:latest", "llama2", "mistral:latest"]
            }
        }
        return false
    }
    
    // Load available models from Ollama
    func loadAvailableModels() async {
        // If in mock mode, use mock models
        if useMockMode {
            await MainActor.run {
                self.availableModels = ["phi", "phi:latest", "llama2", "mistral:latest"]
                
                // Set phi as the default model
                self.currentModel = "phi"
            }
            return
        }
        
        guard let url = URL(string: "\(apiURL)/tags") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            
            let models = response.models.map { $0.name }
            
            await MainActor.run {
                self.availableModels = models
                
                // Set default model
                if !models.isEmpty {
                    // Try to find phi models first
                    if let phi = models.first(where: { $0.contains("phi") }) {
                        self.currentModel = phi
                    } else {
                        self.currentModel = models[0]
                    }
                }
            }
        } catch {
            print("Error loading available models: \(error)")
            
            // Just report the error instead of auto-switching to mock mode
            await MainActor.run {
                // Only set mock models if already in mock mode
                if self.useMockMode {
                    self.availableModels = ["phi", "phi:latest", "llama2", "mistral:latest"]
                    self.currentModel = "phi"
                }
            }
        }
    }
    
    // Generate response using Ollama API
    func generateResponse(prompt: String) async -> String {
        // Use mock if offline mode is enabled
        if useMockMode {
            return generateMockResponse(prompt: prompt)
        }
        
        // Use actual Ollama API when in online mode
        guard let url = URL(string: "\(apiURL)/generate") else {
            return "Error: Invalid Ollama API URL"
        }
        
        let parameters: [String: Any] = [
            "model": currentModel,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.7,
                "top_p": 0.9,
                "num_predict": 1024
            ]
        ]
        
        print("DEBUG: Sending query to model: \(currentModel)")
        
        guard let requestData = try? JSONSerialization.data(withJSONObject: parameters) else {
            return "Error: Could not create request data"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            print("DEBUG: Sending request to \(url)")
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
            return response.response
        } catch {
            print("Error generating response: \(error)")
            
            // Never happens in forced offline mode
            return "Error occurred"
        }
    }
    
    // Generate a simulated response in mock mode
    private func generateMockResponse(prompt: String) -> String {
        print("🔍 JANET_DEBUG: Generating mock response for prompt: \(prompt)")
        
        // Add a slight delay to simulate processing time
        // This helps prevent the blue dot placeholder issue by giving time for the UI to update
        do {
            try? Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
        }
        
        // Check for command-like inputs
        if prompt.lowercased().contains("janet run") || 
           prompt.lowercased().contains("janet execute") ||
           prompt.lowercased().contains("system command") {
            return "I understand you want to run a command, but I'm currently in offline mode. I can help you with information and casual conversations, but system commands require the full version of Janet to be running."
        }
        
        // Check for blue dot or placeholder related questions
        if prompt.lowercased().contains("blue dot") || 
           prompt.lowercased().contains("placeholder") ||
           prompt.lowercased().contains("loading") ||
           prompt.lowercased().contains("thinking") {
            return "The blue dots you're seeing are a loading indicator that appears when I'm generating a response. If you're seeing them for too long, it might indicate that I'm having trouble connecting to the language model or generating a response. This has been fixed in the latest update, where a proper 'Janet is thinking' indicator with animated dots is shown instead."
        }
        
        // Historical or factual information
        if prompt.lowercased().contains("who was") || 
           prompt.lowercased().contains("when did") ||
           prompt.lowercased().contains("what happened") {
            
            // Historical figures
            if prompt.lowercased().contains("einstein") {
                return "Albert Einstein (1879-1955) was a theoretical physicist who developed the theory of relativity. His equation E=mc² is one of the most famous equations in physics. He received the Nobel Prize in Physics in 1921 for his work on the photoelectric effect."
            }
            
            if prompt.lowercased().contains("lincoln") {
                return "Abraham Lincoln (1809-1865) was the 16th President of the United States. He led the country through the American Civil War and is known for the Emancipation Proclamation, which declared slaves in Confederate territory to be free. He was assassinated in 1865 by John Wilkes Booth."
            }
            
            if prompt.lowercased().contains("columbus") {
                return "Christopher Columbus (1451-1506) was an Italian explorer who completed four voyages across the Atlantic Ocean. While he's often credited with 'discovering' the Americas in 1492, indigenous peoples had been living there for thousands of years, and Norse explorers had reached North America centuries earlier."
            }
            
            if prompt.lowercased().contains("marie curie") {
                return "Marie Curie (1867-1934) was a physicist and chemist who conducted pioneering research on radioactivity. She was the first woman to win a Nobel Prize, the first person to win Nobel Prizes in two different scientific fields, and the first woman to become a professor at the University of Paris."
            }
        }
        
        // Science questions
        if prompt.lowercased().contains("what is") || 
           prompt.lowercased().contains("how does") ||
           prompt.lowercased().contains("explain") {
            
            if prompt.lowercased().contains("gravity") {
                return "Gravity is one of the fundamental forces of nature. According to Newton's law of universal gravitation, every mass attracts every other mass with a force proportional to the product of their masses and inversely proportional to the square of the distance between them. Einstein's theory of general relativity describes gravity as the curvature of spacetime caused by mass and energy."
            }
            
            if prompt.lowercased().contains("photosynthesis") {
                return "Photosynthesis is the process by which green plants, algae, and some bacteria convert light energy, usually from the sun, into chemical energy in the form of glucose or other sugars. This process takes in carbon dioxide and water and releases oxygen as a byproduct. The chemical equation is: 6CO₂ + 6H₂O + light energy → C₆H₁₂O₆ + 6O₂."
            }
            
            if prompt.lowercased().contains("planet") || prompt.lowercased().contains("solar system") {
                return "Our solar system consists of the Sun and everything bound to it by gravity. This includes the eight planets (Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, and Neptune), dwarf planets (like Pluto), moons, asteroids, comets, and other celestial objects. The planets orbit the Sun in elliptical paths, with the innermost four being rocky and the outer four being gas giants."
            }
            
            if prompt.lowercased().contains("atom") {
                return "An atom is the smallest unit of an element that maintains the chemical properties of that element. It consists of a nucleus containing protons (positively charged) and neutrons (neutral), surrounded by electrons (negatively charged) that move around the nucleus. Different elements have different numbers of protons, which is called the atomic number."
            }
            
            // Add response about Janet itself
            if prompt.lowercased().contains("janet") || prompt.lowercased().contains("yourself") {
                return "I'm Janet, an AI assistant developed by FolkTechAI. I'm designed to help with a variety of tasks, from answering questions to assisting with productivity tasks. I can run in both online and offline modes. In online mode, I can connect to Ollama to use various language models like Phi, Llama, or Mistral. In offline mode, I provide pre-programmed responses. I'm constantly being improved to provide better assistance and a more seamless experience."
            }
        }
        
        // Math problems
        if prompt.lowercased().contains("solve") || 
           prompt.lowercased().contains("calculate") ||
           prompt.lowercased().contains("what is") && (prompt.contains("+") || prompt.contains("-") || prompt.contains("×") || prompt.contains("*") || prompt.contains("÷") || prompt.contains("/")) {
            
            if prompt.contains("2+2") || prompt.contains("2 + 2") {
                return "The answer to 2 + 2 is 4."
            }
            
            if prompt.contains("5×6") || prompt.contains("5*6") || prompt.contains("5 × 6") || prompt.contains("5 * 6") {
                return "The answer to 5 × 6 is 30."
            }
            
            if prompt.contains("10÷2") || prompt.contains("10/2") || prompt.contains("10 ÷ 2") || prompt.contains("10 / 2") {
                return "The answer to 10 ÷ 2 is 5."
            }
            
            return "I can solve basic math problems in offline mode. For more complex calculations, I'd need to be online to use computational tools."
        }
        
        // Check for web search requests
        if prompt.lowercased().contains("search for") || 
           prompt.lowercased().contains("look up") {
            return "I understand you're looking for information about something. While I'm in offline mode, I can't perform real-time web searches, but I can try to help with general knowledge questions. Could you be more specific about what you'd like to know?"
        }
        
        // Check for specific question patterns and provide canned responses
        if prompt.lowercased().contains("weather") {
            return "I understand you're asking about the weather. In offline mode, I can't access real-time weather data, but I can tell you that weather forecasts typically include temperature, precipitation probability, wind conditions, and other atmospheric measurements."
        }
        
        if prompt.lowercased().contains("help") || prompt.lowercased().contains("can you do") {
            return "I'm Janet, your AI assistant (currently running in offline mode). I can help with:\n\n- Answering general knowledge questions\n- Having casual conversations\n- Basic math and science questions\n- Historical facts and information\n\nIn online mode, I can also execute system commands, search the web, and access various APIs for real-time information."
        }
        
        // Generic responses for different types of inputs
        let genericResponses = [
            "I'm currently running in offline mode, but I'm happy to chat with you. What would you like to talk about?",
            "While I'm in offline mode, I can still engage in conversation and provide information on many topics. How can I assist you today?",
            "That's an interesting question. Let me think about that... In offline mode, I have access to general knowledge but not real-time information.",
            "I understand what you're asking. While I'm offline, I can provide general guidance but not specific data that would require internet access.",
            "I'd like to help with that. Even though I'm in offline mode, I know quite a bit about science, history, and general knowledge topics."
        ]
        
        print("🔍 JANET_DEBUG: Returning generic mock response")
        // Return a random generic response
        return genericResponses[Int.random(in: 0..<genericResponses.count)]
    }
    
    // Stream response from Ollama API
    func streamResponse(prompt: String) -> AsyncStream<String> {
        return AsyncStream<String> { continuation in
            Task {
                // Use mock mode if enabled
                if useMockMode {
                    // Get the full mock response
                    let fullResponse = generateMockResponse(prompt: prompt)
                    
                    // Split into words and stream them with delays
                    let words = fullResponse.split(separator: " ")
                    
                    for word in words {
                        // Simulate network delay
                        try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.05...0.2) * 1_000_000_000))
                        
                        // Stream each word with a space
                        continuation.yield(String(word) + " ")
                    }
                    
                    continuation.finish()
                    return
                }
                
                // Real Ollama streaming implementation
                guard let url = URL(string: "\(apiURL)/generate") else {
                    continuation.yield("Error: Invalid Ollama API URL")
                    continuation.finish()
                    return
                }
                
                let parameters: [String: Any] = [
                    "model": currentModel,
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
                    print("Error streaming response: \(error)")
                    
                    continuation.finish()
                }
            }
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
