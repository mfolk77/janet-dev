import Foundation

// Function to check if Ollama is running
func checkOllamaStatus() async -> Bool {
    print("Checking Ollama status...")
    
    // Try all possible URLs in sequence
    let possibleURLs = [
        "http://localhost:11434/api",
        "http://127.0.0.1:11434/api", 
        "http://0.0.0.0:11434/api"
    ]
    
    for urlBase in possibleURLs {
        let urlString = "\(urlBase)/version"
        print("Trying Ollama at URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            continue
        }
    
        do {
            print("Making request to Ollama API...")
            // Use a more reliable configuration with timeout
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(from: url)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let isRunning = statusCode == 200
            
            print("Ollama API response status: \(statusCode)")
            
            if isRunning {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                
                print("SUCCESS: Connected to Ollama at \(urlBase)")
                return true
            }
        } catch {
            print("Failed to connect to \(urlString): \(error.localizedDescription)")
            // Continue to next URL
        }
    }
    
    // If we get here, all URLs failed
    print("ERROR: Failed to connect to Ollama on any URL")
    return false
}

// Function to load available models
func loadAvailableModels(apiURL: String) async {
    print("\nLoading available models...")
    
    guard let url = URL(string: "\(apiURL)/tags") else {
        print("Invalid URL")
        return
    }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = jsonObject["models"] as? [[String: Any]] {
            
            print("Available models:")
            for model in models {
                if let name = model["name"] as? String {
                    print("- \(name)")
                }
            }
        } else {
            print("Failed to parse models response")
        }
    } catch {
        print("Error loading available models: \(error)")
    }
}

// Function to generate a response
func generateResponse(apiURL: String, model: String, prompt: String) async {
    print("\nGenerating response...")
    
    guard let url = URL(string: "\(apiURL)/generate") else {
        print("Invalid URL")
        return
    }
    
    let parameters: [String: Any] = [
        "model": model,
        "prompt": prompt,
        "stream": false,
        "options": [
            "temperature": 0.7,
            "top_p": 0.9,
            "num_predict": 1024
        ]
    ]
    
    print("Sending query to model: \(model)")
    
    guard let requestData = try? JSONSerialization.data(withJSONObject: parameters) else {
        print("Could not create request data")
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = requestData
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        print("Sending request to \(url)")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let response = jsonObject["response"] as? String {
            print("Response: \(response)")
        } else {
            print("Failed to parse response")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }
        }
    } catch {
        print("Error generating response: \(error)")
    }
}

// Main function
@main
struct OllamaTest {
    static func main() async {
        print("Ollama API Test")
        print("===============")
        
        let isRunning = await checkOllamaStatus()
        
        if isRunning {
            let apiURL = "http://localhost:11434/api"
            await loadAvailableModels(apiURL: apiURL)
            await generateResponse(apiURL: apiURL, model: "phi:latest", prompt: "Hello, how are you?")
        } else {
            print("Ollama is not running. Please start Ollama and try again.")
        }
    }
} 