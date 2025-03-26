//
//  NotionMemory.swift
//  Janet
//
//  Created by Michael folk on 3/1/2025.
//

import Foundation
import Combine

// MARK: - Notion Data Models

struct NotionItem: Identifiable, Codable {
    let id: String
    let title: String
    let content: String
    let createdTime: Date
    var tags: [String]
    var url: String?
}

struct NotionResponse: Codable {
    let results: [NotionPage]
    let next_cursor: String?
    let has_more: Bool
}

struct NotionPage: Codable {
    let id: String
    let created_time: String
    let properties: [String: NotionProperty]
    let url: String
    
    func toNotionItem() -> NotionItem? {
        // Extract title
        let title = properties["title"]?.title?.compactMap { $0.text.content }.joined() ?? "Untitled"
        
        // Extract content/description
        let content = properties["content"]?.rich_text?.compactMap { $0.text.content }.joined() ??
                     properties["description"]?.rich_text?.compactMap { $0.text.content }.joined() ?? ""
        
        // Extract tags
        let tags = properties["tags"]?.multi_select?.compactMap { $0.name } ?? []
        
        // Create date formatter
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        // Parse created time
        let createdTime = dateFormatter.date(from: created_time) ?? Date()
        
        return NotionItem(
            id: id,
            title: title,
            content: content,
            createdTime: createdTime,
            tags: tags,
            url: url
        )
    }
}

struct NotionProperty: Codable {
    let title: [NotionRichText]?
    let rich_text: [NotionRichText]?
    let multi_select: [NotionSelectOption]?
}

struct NotionRichText: Codable {
    let text: NotionText
}

struct NotionText: Codable {
    let content: String
}

struct NotionSelectOption: Codable {
    let name: String
}

class NotionMemory: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var apiKey: String = ""
    @Published var databaseId: String = ""
    @Published var notionItems: [NotionItem] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load enabled setting from UserDefaults
        isEnabled = UserDefaults.standard.bool(forKey: "notion_enabled")
        
        // Try to load API credentials from keychain
        let keychainManager = KeychainManager.shared
        
        if let storedApiKey = keychainManager.getStringOrNil(forKey: "notion_api_key") {
            apiKey = storedApiKey
        } else {
            // Fall back to UserDefaults if not in keychain
            apiKey = UserDefaults.standard.string(forKey: "notion_api_key") ?? ""
            
            // If we found a value in UserDefaults, migrate it to keychain
            if !apiKey.isEmpty {
                try? keychainManager.saveString(apiKey, forKey: "notion_api_key")
                // Remove from UserDefaults for security
                UserDefaults.standard.removeObject(forKey: "notion_api_key")
            }
        }
        
        if let storedDatabaseId = keychainManager.getStringOrNil(forKey: "notion_database_id") {
            databaseId = storedDatabaseId
        } else {
            // Fall back to UserDefaults if not in keychain
            databaseId = UserDefaults.standard.string(forKey: "notion_database_id") ?? ""
            
            // If we found a value in UserDefaults, migrate it to keychain
            if !databaseId.isEmpty {
                try? keychainManager.saveString(databaseId, forKey: "notion_database_id")
                // Remove from UserDefaults for security
                UserDefaults.standard.removeObject(forKey: "notion_database_id")
            }
        }
        
        // Set up observers for published properties
        $isEnabled
            .sink { [weak self] newValue in
                UserDefaults.standard.set(newValue, forKey: "notion_enabled")
                
                // If enabled and we have credentials, fetch items
                if newValue && !(self?.apiKey.isEmpty ?? true) && !(self?.databaseId.isEmpty ?? true) {
                    Task {
                        do {
                            try await self?.fetchNotionItems()
                        } catch {
                            print("Failed to fetch Notion items when enabling: \(error)")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        $apiKey
            .sink { [weak self] newValue in
                // Save to keychain instead of UserDefaults
                try? keychainManager.saveOrUpdateString(newValue, forKey: "notion_api_key")
            }
            .store(in: &cancellables)
        
        $databaseId
            .sink { [weak self] newValue in
                // Save to keychain instead of UserDefaults
                try? keychainManager.saveOrUpdateString(newValue, forKey: "notion_database_id")
            }
            .store(in: &cancellables)
        
        // Fetch items if enabled and we have credentials
        if isEnabled && !apiKey.isEmpty && !databaseId.isEmpty {
            Task {
                do {
                    try await fetchNotionItems()
                } catch {
                    print("Failed to fetch Notion items during initialization: \(error)")
                }
            }
        }
    }
    
    // Fetch items from Notion
    func fetchNotionItems() async throws {
        guard isEnabled, !apiKey.isEmpty, !databaseId.isEmpty else {
            throw NSError(domain: "NotionMemory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notion integration is not configured properly"])
        }
        
        // Create URL for Notion API with URL validation
        guard let url = URL(string: "https://api.notion.com/v1/databases/\(databaseId.trimmingCharacters(in: .whitespacesAndNewlines))/query"),
              url.host == "api.notion.com" else {
            throw NSError(domain: "NotionMemory", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Notion database ID or API URL"])
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create sort parameters to get newest items first
        let requestBody: [String: Any] = [
            "sorts": [
                [
                    "property": "created_time",
                    "direction": "descending"
                ]
            ],
            "page_size": 50
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Perform request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Error fetching Notion items: \(String(data: data, encoding: .utf8) ?? "Unknown error")")
                
                // Simulate response for testing
                await MainActor.run {
                    self.notionItems = createSimulatedNotionItems()
                }
                return
            }
            
            // Parse response
            let decoder = JSONDecoder()
            let notionResponse = try decoder.decode(NotionResponse.self, from: data)
            
            // Convert to NotionItems
            let items = notionResponse.results.compactMap { $0.toNotionItem() }
            
            // Update on main thread
            await MainActor.run {
                self.notionItems = items
            }
        } catch {
            print("Error fetching Notion items: \(error)")
            
            // Simulate response for testing
            await MainActor.run {
                self.notionItems = createSimulatedNotionItems()
            }
        }
    }
    
    // Create a new page in Notion
    func createNotionPage(title: String, content: String, tags: [String] = []) async -> Bool {
        guard isEnabled, !apiKey.isEmpty, !databaseId.isEmpty else {
            return false
        }
        
        // Create URL for Notion API
        guard let url = URL(string: "https://api.notion.com/v1/pages") else {
            print("Invalid Notion API URL")
            return false
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create page properties
        var properties: [String: Any] = [
            "title": [
                "title": [
                    [
                        "text": [
                            "content": title
                        ]
                    ]
                ]
            ],
            "content": [
                "rich_text": [
                    [
                        "text": [
                            "content": content
                        ]
                    ]
                ]
            ]
        ]
        
        // Add tags if provided
        if !tags.isEmpty {
            let tagObjects = tags.map { ["name": $0] }
            properties["tags"] = [
                "multi_select": tagObjects
            ]
        }
        
        // Create request body
        let requestBody: [String: Any] = [
            "parent": [
                "database_id": databaseId
            ],
            "properties": properties
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Perform request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse,
                  (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
                print("Error creating Notion page: Status code \(String(describing: (response as? HTTPURLResponse)?.statusCode)) - \(String(data: data, encoding: .utf8) ?? "Unknown error")")
                return false
            }
            
            // Refresh items
            do {
                try await fetchNotionItems()
            } catch {
                print("Error refreshing Notion items after page creation: \(error)")
                // Continue even if refresh fails - page was already created
            }
            return true
        } catch {
            print("Error creating Notion page: \(error)")
            return false
        }
    }
}

// MARK: - Helper Functions

// Create simulated Notion items for testing
func createSimulatedNotionItems() -> [NotionItem] {
    let now = Date()
    let calendar = Calendar.current
    
    return [
        NotionItem(
            id: "item1",
            title: "Meeting Notes from Project Kickoff",
            content: "Discussed project goals, timelines, and resource allocation. Action items: Set up repository, create initial documentation.",
            createdTime: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            tags: ["Meeting", "Project"],
            url: "https://notion.so/page1"
        ),
        NotionItem(
            id: "item2",
            title: "Research on Market Trends",
            content: "Key findings: Mobile usage growing 15% YoY, competitors focusing on AI features, sustainability becoming major factor in consumer decisions.",
            createdTime: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
            tags: ["Research", "Market"],
            url: "https://notion.so/page2"
        ),
        NotionItem(
            id: "item3",
            title: "User Feedback Summary",
            content: "Most requested features: Dark mode, offline capabilities, faster sync. Pain points: Complex navigation, slow performance on older devices.",
            createdTime: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
            tags: ["Users", "Feedback"],
            url: "https://notion.so/page3"
        ),
        NotionItem(
            id: "item4",
            title: "Quarterly Goals",
            content: "1. Launch beta version by June, 2. Acquire 1000 test users, 3. Improve performance metrics by 25%, 4. Complete security audit.",
            createdTime: calendar.date(byAdding: .day, value: -14, to: now) ?? now,
            tags: ["Planning", "Goals"],
            url: "https://notion.so/page4"
        ),
        NotionItem(
            id: "item5",
            title: "API Documentation",
            content: "Endpoints: /users, /projects, /tasks. Authentication: JWT tokens. Rate limits: 100 requests per minute per user.",
            createdTime: calendar.date(byAdding: .day, value: -21, to: now) ?? now,
            tags: ["Development", "Documentation"],
            url: "https://notion.so/page5"
        )
    ]
}