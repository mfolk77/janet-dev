//
//  WebhookService.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import Foundation
import Combine

class WebhookService: ObservableObject {
    @Published var webSearchEnabled: Bool = true
    @Published var weatherEnabled: Bool = true
    
    private let searchTerms = [
        "search for",
        "look up",
        "find information about",
        "search the web for",
        "what is",
        "who is",
        "when did",
        "where is",
        "how to",
        "latest news",
        "current events",
        "recent developments",
        "weather in",
        "forecast for",
        "stock price of",
        "tell me about"
    ]
    
    // Check if input requires web access
    func requiresWebAccess(_ input: String) async -> Bool {
        let lowercasedInput = input.lowercased()
        
        // Check for explicit web search requests
        if lowercasedInput.contains("search the web") || 
           lowercasedInput.contains("look online") ||
           lowercasedInput.contains("search online") {
            return true
        }
        
        // Check for search terms
        for term in searchTerms {
            if lowercasedInput.contains(term) {
                return true
            }
        }
        
        // Check for current data requests that need real-time information
        if lowercasedInput.contains("current") || 
           lowercasedInput.contains("latest") || 
           lowercasedInput.contains("recent") ||
           lowercasedInput.contains("today's") {
            return true
        }
        
        // Check for specific timely information
        if lowercasedInput.contains("weather") ||
           lowercasedInput.contains("news") ||
           lowercasedInput.contains("stock") ||
           lowercasedInput.contains("price") {
            return true
        }
        
        return false
    }
    
    // Process input that needs web access
    func processWithWebAccess(_ input: String) async -> String {
        // Extract search query
        var searchQuery = input
        
        // Try to extract the actual query by removing common prefixes
        for term in searchTerms {
            if let range = input.lowercased().range(of: term) {
                let startIndex = input.index(range.upperBound, offsetBy: 0)
                searchQuery = String(input[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Special handling for weather requests
        if input.lowercased().contains("weather") && weatherEnabled {
            return await getWeatherInfo(for: searchQuery)
        }
        
        // Default to web search
        if webSearchEnabled {
            return await performWebSearch(searchQuery)
        } else {
            return "I'm sorry, web search is currently disabled. Please enable it in Settings to use this feature."
        }
    }
    
    // Perform a web search (simulated for now, could be connected to a real API)
    private func performWebSearch(_ query: String) async -> String {
        if !webSearchEnabled {
            return "Web search is currently disabled. Please enable it in Settings."
        }
        
        // Formatted query would be used in a real implementation with an actual search API
        // We're not using it now but keeping the logic for future implementation
        
        // For now, return a simulated result - in a real implementation, this would call an actual web search API
        return "Web search results for '\(query)':\n\n" +
               "Based on web search, here's what I found about '\(query)':\n" +
               "- Top result indicates that \(query) is a widely discussed topic.\n" +
               "- Recent information suggests that \(query) has been trending in the past week.\n" +
               "- Several reliable sources have published articles about \(query) recently.\n\n" +
               "Note: This is a simulated web search result. In a production version, this would be replaced with actual web search data from Google, Bing, or another search provider."
    }
    
    // Get weather information (simulated for now)
    private func getWeatherInfo(for location: String) async -> String {
        if !weatherEnabled {
            return "Weather information is currently disabled. Please enable it in Settings."
        }
        
        // Extract the location from the query
        var weatherLocation = location
        
        if location.lowercased().contains("weather in") {
            weatherLocation = location.replacingOccurrences(of: "weather in", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if location.lowercased().contains("weather for") {
            weatherLocation = location.replacingOccurrences(of: "weather for", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if location.lowercased().contains("weather") {
            weatherLocation = location.replacingOccurrences(of: "weather", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // For now, return a simulated result - in a real implementation, this would call an actual weather API
        return "Weather information for '\(weatherLocation)':\n\n" +
               "Current conditions: Partly cloudy\n" +
               "Temperature: 65°F (18°C)\n" +
               "Humidity: 45%\n" +
               "Wind: 10 mph NW\n\n" +
               "Forecast:\n" +
               "- Today: Mostly sunny with a high of 72°F\n" +
               "- Tomorrow: Partly cloudy with a high of 68°F\n\n" +
               "Note: This is a simulated weather result. In a production version, this would be replaced with actual weather data from a weather API."
    }
}