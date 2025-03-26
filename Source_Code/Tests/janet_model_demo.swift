#!/usr/bin/swift

import Foundation

// MARK: - Model Interface
class OllamaModel {
    let modelName: String
    let baseURL: URL
    var isConnected: Bool = false
    
    init(modelName: String, baseURLString: String = "http://localhost:11434") {
        self.modelName = modelName
        self.baseURL = URL(string: baseURLString)!
        print("Initialized OllamaModel with model: \(modelName)")
    }
    
    func load() -> Bool {
        print("Attempting to connect to Ollama service...")
        
        // Create a URL for the API endpoint to list available models
        let tagsURL = baseURL.appendingPathComponent("api/tags")
        
        // Create a semaphore to make the async request synchronous for this demo
        let semaphore = DispatchSemaphore(value: 0)
        var availableModels: [String] = []
        
        let task = URLSession.shared.dataTask(with: tagsURL) { [weak self] data, response, error in
            defer { semaphore.signal() }
            
            guard let self = self else { return }
            
            if let error = error {
                print("Connection error: \(error.localizedDescription)")
                self.checkOllamaProcess()
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 200, let data = data {
                print("Successfully connected to Ollama service")
                
                // Parse the JSON response to get available models
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    availableModels = models.compactMap { $0["name"] as? String }
                    
                    if availableModels.contains(self.modelName) {
                        self.isConnected = true
                        print("Model '\(self.modelName)' is available")
                    } else {
                        print("Warning: Model '\(self.modelName)' not found in available models")
                        print("Available models: \(availableModels)")
                    }
                }
            } else {
                print("Failed to connect to Ollama service. Status code: \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
        semaphore.wait()
        
        return self.isConnected
    }
    
    private func checkOllamaProcess() {
        print("Falling back to checking if Ollama is running...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["ollama"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print(output)
                self.isConnected = true
                print("Ollama process is running, but API connection failed")
            } else {
                print("Ollama process is not running")
            }
        } catch {
            print("Error checking Ollama process: \(error)")
        }
    }
    
    func generate(prompt: String) -> String {
        if !isConnected {
            return "Error: Not connected to Ollama service"
        }
        
        print("Generating response for prompt: \(prompt)")
        
        // Create a URL for the API endpoint
        let generateURL = baseURL.appendingPathComponent("api/generate")
        
        // Create the request
        var request = URLRequest(url: generateURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false
        ]
        
        // Serialize the request body to JSON
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            return "Error: Failed to serialize request"
        }
        
        request.httpBody = httpBody
        
        // Create a semaphore to make the async request synchronous for this demo
        let semaphore = DispatchSemaphore(value: 0)
        var responseText = ""
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                responseText = "Error: \(error.localizedDescription)"
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                responseText = "Error: Invalid response"
                return
            }
            
            if httpResponse.statusCode != 200 {
                responseText = "Error: HTTP status code \(httpResponse.statusCode)"
                print(responseText)
                print("Response: \(String(describing: data))")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["response"] as? String else {
                responseText = "Error: Failed to parse response"
                return
            }
            
            responseText = response
        }
        
        task.resume()
        semaphore.wait()
        
        return responseText
    }
}

// MARK: - Mock UI Components
class MockChatView {
    var messages: [MockMessage] = []
    
    func addMessage(_ message: MockMessage) {
        messages.append(message)
        print("\n[\(message.isUserMessage ? "User" : "Janet")]: \(message.content)")
    }
    
    func displayTypingIndicator() {
        print("\n[Janet is typing...]")
    }
    
    func hideTypingIndicator() {
        print("[Janet finished typing]")
    }
}

struct MockMessage {
    let content: String
    let isUserMessage: Bool
    let timestamp: Date
    
    init(content: String, isUserMessage: Bool) {
        self.content = content
        self.isUserMessage = isUserMessage
        self.timestamp = Date()
    }
}

// MARK: - Janet App Demo
class JanetAppDemo {
    let chatView = MockChatView()
    let modelInterface: OllamaModel
    
    init(modelName: String) {
        self.modelInterface = OllamaModel(modelName: modelName)
    }
    
    func start() {
        print("\n=== Janet App Demo Started ===\n")
        
        // Connect to the model
        if modelInterface.load() {
            chatView.addMessage(MockMessage(content: "Hello! I'm Janet, powered by the \(modelInterface.modelName) model. How can I help you today?", isUserMessage: false))
            
            // Start the interaction loop
            interactionLoop()
        } else {
            print("\nFailed to connect to the model. Please make sure Ollama is running and the model is available.")
        }
    }
    
    func interactionLoop() {
        print("\nType your message (or 'exit' to quit):")
        
        while let input = readLine(), input.lowercased() != "exit" {
            if !input.isEmpty {
                // Add user message to chat
                chatView.addMessage(MockMessage(content: input, isUserMessage: true))
                
                // Show typing indicator
                chatView.displayTypingIndicator()
                
                // Generate response
                let response = modelInterface.generate(prompt: input)
                
                // Hide typing indicator and add response
                chatView.hideTypingIndicator()
                chatView.addMessage(MockMessage(content: response, isUserMessage: false))
                
                print("\nType your message (or 'exit' to quit):")
            }
        }
        
        print("\n=== Janet App Demo Ended ===\n")
    }
}

// MARK: - Main
print("Starting Janet App Demo...")
print("This demo simulates the Janet app interface with the Ollama model integration.")

// Create and start the demo with the llama3 model
let demo = JanetAppDemo(modelName: "llama3:latest")
demo.start() 