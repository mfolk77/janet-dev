#!/usr/bin/swift

import Foundation

// Simple test script for ModelInterface
print("Starting ModelInterface test...")

// Define the OllamaModel class (simplified version of what's in ModelInterface.swift)
class OllamaModel {
    let modelName: String
    let baseURL: URL
    var isConnected: Bool = false
    
    init(modelName: String, baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.modelName = modelName
        self.baseURL = baseURL
        print("Initialized OllamaModel with model: \(modelName)")
    }
    
    func load() async -> Bool {
        print("Attempting to connect to Ollama service...")
        
        // Check if Ollama service is running
        let checkURL = baseURL.appendingPathComponent("api/tags")
        var request = URLRequest(url: checkURL)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Invalid response type")
                return false
            }
            
            if httpResponse.statusCode == 200 {
                print("Successfully connected to Ollama service")
                isConnected = true
                
                // Parse the response to check if our model is available
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = jsonObject["models"] as? [[String: Any]] {
                    
                    let modelExists = models.contains { model in
                        if let name = model["name"] as? String {
                            return name == modelName || name.hasPrefix("\(modelName):")
                        }
                        return false
                    }
                    
                    if modelExists {
                        print("Model '\(modelName)' is available")
                    } else {
                        print("Warning: Model '\(modelName)' not found in available models")
                        print("Available models: \(models.compactMap { $0["name"] as? String })")
                    }
                }
                
                return true
            } else {
                print("Error: HTTP status code \(httpResponse.statusCode)")
                return false
            }
        } catch {
            print("Connection error: \(error.localizedDescription)")
            print("Falling back to checking if Ollama is running...")
            
            // Try a simpler check
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["pgrep", "ollama"]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    print("Ollama process is running, but API connection failed")
                    isConnected = true
                    return true
                } else {
                    print("Ollama process is not running")
                    return false
                }
            } catch {
                print("Failed to check Ollama process: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    func generate(prompt: String) async -> String? {
        guard isConnected else {
            print("Error: Not connected to Ollama service")
            return nil
        }
        
        print("Generating response for prompt: \(prompt)")
        
        let generateURL = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: generateURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Invalid response type")
                return nil
            }
            
            if httpResponse.statusCode == 200 {
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = jsonObject["response"] as? String {
                    return response
                } else {
                    print("Error: Could not parse response")
                    return nil
                }
            } else {
                print("Error: HTTP status code \(httpResponse.statusCode)")
                return nil
            }
        } catch {
            print("Generation error: \(error.localizedDescription)")
            return nil
        }
    }
}

// Main test function
func runTest() async {
    // Test with one of the available models we found
    let model = OllamaModel(modelName: "llama3")
    
    let connected = await model.load()
    if connected {
        print("Successfully connected to Ollama service")
        
        // Test generating a response
        if let response = await model.generate(prompt: "Hello, how are you today?") {
            print("\nModel response:")
            print(response)
            print("\nTest completed successfully!")
        } else {
            print("Failed to generate response")
        }
    } else {
        print("Failed to connect to Ollama service")
    }
}

// Run the test
Task {
    await runTest()
    // Keep the script running until the async task completes
    exit(0)
}

// Keep the main thread alive
RunLoop.main.run(until: Date(timeIntervalSinceNow: 60)) 