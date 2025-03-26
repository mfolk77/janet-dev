import Foundation
import SwiftUI

// MARK: - NavigationState
public class NavigationState: ObservableObject {
    public enum ActiveView: String {
        case home
        case settings
        case vectorMemory
        case meeting
        case speech
        case codeAssistant
        case orchestrator
        case stressTest
        case testLoop
        case chat
        case memory
        case mcp
    }
    
    @Published public var activeView: ActiveView = .home
    @Published var navigationSelection: Int? = nil
    
    public init() {}
    
    // Navigation methods
    
    public func navigateToHome() {
        activeView = .home
    }
    
    public func navigateToSettings() {
        activeView = .settings
    }
    
    public func navigateToVectorMemory() {
        activeView = .vectorMemory
    }
    
    public func navigateToMeeting() {
        activeView = .meeting
    }
    
    public func navigateToSpeech() {
        activeView = .speech
    }
    
    public func navigateToCodeAssistant() {
        activeView = .codeAssistant
    }
    
    public func navigateToOrchestrator() {
        activeView = .orchestrator
    }
    
    public func navigateToStressTest() {
        activeView = .stressTest
    }
    
    public func navigateToTestLoop() {
        activeView = .testLoop
    }
    
    public func navigateToChat() {
        activeView = .chat
    }
    
    public func navigateToMemory() {
        activeView = .memory
    }
    
    public func navigateToMCP() {
        activeView = .mcp
    }
}