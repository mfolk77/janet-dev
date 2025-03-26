import SwiftUI

// MARK: - NavigationState
public class NavigationState: ObservableObject {
    @Published var activeView: ActiveView = .chat
    @Published var navigationSelection: Int? = nil
    
    public enum ActiveView {
        case chat
        case settings
        case memory
        case meeting
        case vectorMemory
        case speech
    }
    
    public func navigateToHome() {
        activeView = .chat
        navigationSelection = nil
    }
    
    // Helper function to navigate to meeting view
    public func navigateToMeeting() {
        activeView = .meeting
    }
    
    // Helper function to navigate to vector memory view
    public func navigateToVectorMemory() {
        activeView = .vectorMemory
    }
    
    // Helper function to navigate to speech view
    public func navigateToSpeech() {
        activeView = .speech
    }
}
