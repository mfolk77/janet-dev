//
//  SelfDiagnostics.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os
import Combine

/// Self-diagnostics module for monitoring and debugging model execution
public class SelfDiagnostics: ObservableObject {
    // MARK: - Published Properties
    
    /// Recent diagnostic events
    @Published public private(set) var diagnosticEvents: [DiagnosticEvent] = []
    
    /// Current system health status
    @Published public private(set) var systemHealth: SystemHealth = .normal
    
    /// Whether diagnostics are enabled
    @Published public var isDiagnosticsEnabled: Bool = true
    
    /// Whether auto-recovery is enabled
    @Published public var isAutoRecoveryEnabled: Bool = true
    
    /// Whether to log detailed diagnostics
    @Published public var isDetailedLoggingEnabled: Bool = false
    
    // MARK: - Private Properties
    
    /// Logger for the self-diagnostics module
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "SelfDiagnostics")
    
    /// Maximum number of diagnostic events to store
    private let maxEvents = 100
    
    /// Queue for thread safety
    private let queue = DispatchQueue(label: "com.janet.ai.selfDiagnostics", qos: .userInitiated)
    
    /// Model performance metrics
    private var modelMetrics: [JanetModelType: ModelMetrics] = [:]
    
    /// Execution failure counts
    private var failureCounts: [JanetModelType: Int] = [:]
    
    /// Recovery strategies
    private var recoveryStrategies: [ExecutionError: RecoveryStrategy] = [:]
    
    /// Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = SelfDiagnostics()
    
    // MARK: - Initialization
    
    /// Initialize a new self-diagnostics module
    private init() {
        logger.info("Initializing SelfDiagnostics")
        
        // Initialize model metrics for all model types
        for modelType in JanetModelType.allCases {
            modelMetrics[modelType] = ModelMetrics()
            failureCounts[modelType] = 0
        }
        
        // Initialize recovery strategies
        initializeRecoveryStrategies()
        
        // Set up observers
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Record a successful execution
    /// - Parameters:
    ///   - modelType: The type of model
    ///   - executionTime: The execution time in seconds
    ///   - promptLength: The length of the prompt
    ///   - responseLength: The length of the response
    public func recordSuccess(
        modelType: JanetModelType,
        executionTime: TimeInterval,
        promptLength: Int,
        responseLength: Int
    ) {
        guard isDiagnosticsEnabled else { return }
        
        logger.info("Recording successful execution for model: \(modelType.rawValue)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Update model metrics
            if var metrics = self.modelMetrics[modelType] {
                metrics.totalExecutions += 1
                metrics.successfulExecutions += 1
                metrics.totalExecutionTime += executionTime
                metrics.averageExecutionTime = metrics.totalExecutionTime / Double(metrics.successfulExecutions)
                metrics.totalPromptLength += promptLength
                metrics.totalResponseLength += responseLength
                metrics.lastExecutionTime = Date()
                
                self.modelMetrics[modelType] = metrics
            }
            
            // Reset failure count
            self.failureCounts[modelType] = 0
            
            // Add diagnostic event
            let event = DiagnosticEvent(
                timestamp: Date(),
                modelType: modelType,
                eventType: .success,
                message: "Successful execution in \(String(format: "%.2f", executionTime)) seconds",
                details: "Prompt length: \(promptLength), Response length: \(responseLength)"
            )
            
            self.addDiagnosticEvent(event)
            
            // Update system health
            self.updateSystemHealth()
        }
    }
    
    /// Record a failed execution
    /// - Parameters:
    ///   - modelType: The type of model
    ///   - error: The error that occurred
    ///   - prompt: The prompt that failed
    public func recordFailure(
        modelType: JanetModelType,
        error: Error,
        prompt: String
    ) {
        guard isDiagnosticsEnabled else { return }
        
        logger.error("Recording failed execution for model: \(modelType.rawValue), error: \(error.localizedDescription)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Update model metrics
            if var metrics = self.modelMetrics[modelType] {
                metrics.totalExecutions += 1
                metrics.failedExecutions += 1
                metrics.lastExecutionTime = Date()
                
                self.modelMetrics[modelType] = metrics
            }
            
            // Increment failure count
            self.failureCounts[modelType, default: 0] += 1
            
            // Add diagnostic event
            let event = DiagnosticEvent(
                timestamp: Date(),
                modelType: modelType,
                eventType: .failure,
                message: "Execution failed: \(error.localizedDescription)",
                details: "Prompt: \(prompt.prefix(100))..."
            )
            
            self.addDiagnosticEvent(event)
            
            // Update system health
            self.updateSystemHealth()
            
            // Attempt auto-recovery if enabled
            if self.isAutoRecoveryEnabled {
                self.attemptRecovery(modelType: modelType, error: error)
            }
        }
    }
    
    /// Record a warning
    /// - Parameters:
    ///   - modelType: The type of model
    ///   - message: The warning message
    ///   - details: Additional details
    public func recordWarning(
        modelType: JanetModelType,
        message: String,
        details: String? = nil
    ) {
        guard isDiagnosticsEnabled else { return }
        
        logger.warning("Recording warning for model: \(modelType.rawValue), message: \(message)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Add diagnostic event
            let event = DiagnosticEvent(
                timestamp: Date(),
                modelType: modelType,
                eventType: .warning,
                message: message,
                details: details
            )
            
            self.addDiagnosticEvent(event)
            
            // Update system health
            self.updateSystemHealth()
        }
    }
    
    /// Get performance metrics for a model
    /// - Parameter modelType: The type of model
    /// - Returns: The model's performance metrics
    public func getModelMetrics(modelType: JanetModelType) -> ModelMetrics {
        return queue.sync {
            return modelMetrics[modelType] ?? ModelMetrics()
        }
    }
    
    /// Get performance metrics for all models
    /// - Returns: A dictionary of model types to performance metrics
    public func getAllModelMetrics() -> [JanetModelType: ModelMetrics] {
        return queue.sync {
            return modelMetrics
        }
    }
    
    /// Get diagnostic recommendations
    /// - Returns: A list of diagnostic recommendations
    public func getDiagnosticRecommendations() -> [DiagnosticRecommendation] {
        return queue.sync {
            var recommendations: [DiagnosticRecommendation] = []
            
            // Check for models with high failure rates
            for (modelType, metrics) in modelMetrics {
                if metrics.totalExecutions > 0 {
                    let failureRate = Double(metrics.failedExecutions) / Double(metrics.totalExecutions)
                    
                    if failureRate > 0.5 && metrics.totalExecutions >= 5 {
                        // More than 50% failures and at least 5 executions
                        recommendations.append(DiagnosticRecommendation(
                            severity: .high,
                            modelType: modelType,
                            message: "High failure rate (\(String(format: "%.1f", failureRate * 100))%) for model \(modelType.rawValue)",
                            recommendation: "Consider reloading the model or switching to a different model"
                        ))
                    } else if failureRate > 0.2 && metrics.totalExecutions >= 10 {
                        // More than 20% failures and at least 10 executions
                        recommendations.append(DiagnosticRecommendation(
                            severity: .medium,
                            modelType: modelType,
                            message: "Elevated failure rate (\(String(format: "%.1f", failureRate * 100))%) for model \(modelType.rawValue)",
                            recommendation: "Monitor model performance and consider adjusting parameters"
                        ))
                    }
                }
                
                // Check for slow models
                if metrics.successfulExecutions > 0 && metrics.averageExecutionTime > 5.0 {
                    recommendations.append(DiagnosticRecommendation(
                        severity: .low,
                        modelType: modelType,
                        message: "Slow execution time (\(String(format: "%.2f", metrics.averageExecutionTime)) seconds) for model \(modelType.rawValue)",
                        recommendation: "Consider using a smaller model or optimizing prompt length"
                    ))
                }
            }
            
            // Check for system health issues
            if systemHealth == .critical {
                recommendations.append(DiagnosticRecommendation(
                    severity: .high,
                    modelType: nil,
                    message: "System health is critical",
                    recommendation: "Restart the application and check system resources"
                ))
            } else if systemHealth == .degraded {
                recommendations.append(DiagnosticRecommendation(
                    severity: .medium,
                    modelType: nil,
                    message: "System health is degraded",
                    recommendation: "Consider reloading models or freeing up system resources"
                ))
            }
            
            return recommendations
        }
    }
    
    /// Clear all diagnostic events
    public func clearDiagnosticEvents() {
        logger.info("Clearing all diagnostic events")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.diagnosticEvents = []
            }
        }
    }
    
    /// Reset all metrics
    public func resetMetrics() {
        logger.info("Resetting all metrics")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Reset model metrics
            for modelType in JanetModelType.allCases {
                self.modelMetrics[modelType] = ModelMetrics()
                self.failureCounts[modelType] = 0
            }
            
            // Reset system health
            Task { @MainActor in
                self.systemHealth = .normal
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Initialize recovery strategies
    private func initializeRecoveryStrategies() {
        logger.info("Initializing recovery strategies")
        
        // Strategy for model not loaded
        recoveryStrategies[ExecutionError.modelNotLoaded] = RecoveryStrategy(
            action: .reloadModel,
            description: "Reload the model"
        )
        
        // Strategy for model generation failed
        recoveryStrategies[ExecutionError.modelGenerationFailed] = RecoveryStrategy(
            action: .retryWithDifferentParameters,
            description: "Retry with different parameters"
        )
        
        // Strategy for no suitable model
        recoveryStrategies[ExecutionError.noSuitableModel] = RecoveryStrategy(
            action: .switchToFallbackModel,
            description: "Switch to fallback model"
        )
    }
    
    /// Set up observers
    private func setupObservers() {
        logger.info("Setting up observers")
        
        // Observe model loading notifications
        NotificationCenter.default.publisher(for: .modelLoaded)
            .sink { [weak self] notification in
                guard let self = self,
                      let modelType = notification.userInfo?["modelType"] as? JanetModelType else {
                    return
                }
                
                self.recordModelLoaded(modelType: modelType)
            }
            .store(in: &cancellables)
        
        // Observe model unloading notifications
        NotificationCenter.default.publisher(for: .modelUnloaded)
            .sink { [weak self] notification in
                guard let self = self,
                      let modelType = notification.userInfo?["modelType"] as? JanetModelType else {
                    return
                }
                
                self.recordModelUnloaded(modelType: modelType)
            }
            .store(in: &cancellables)
        
        // Observe task execution notifications
        NotificationCenter.default.publisher(for: .taskExecutionCompleted)
            .sink { [weak self] notification in
                guard let self = self,
                      let success = notification.userInfo?["success"] as? Bool,
                      let modelType = notification.userInfo?["modelType"] as? JanetModelType,
                      let executionTime = notification.userInfo?["executionTime"] as? TimeInterval else {
                    return
                }
                
                if success {
                    let promptLength = notification.userInfo?["promptLength"] as? Int ?? 0
                    let responseLength = notification.userInfo?["responseLength"] as? Int ?? 0
                    
                    self.recordSuccess(
                        modelType: modelType,
                        executionTime: executionTime,
                        promptLength: promptLength,
                        responseLength: responseLength
                    )
                } else {
                    let error = notification.userInfo?["error"] as? Error ?? NSError(domain: "com.janet.ai", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
                    let prompt = notification.userInfo?["prompt"] as? String ?? ""
                    
                    self.recordFailure(
                        modelType: modelType,
                        error: error,
                        prompt: prompt
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    /// Record a model loaded event
    /// - Parameter modelType: The type of model
    private func recordModelLoaded(modelType: JanetModelType) {
        guard isDiagnosticsEnabled else { return }
        
        logger.info("Recording model loaded event for model: \(modelType.rawValue)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Add diagnostic event
            let event = DiagnosticEvent(
                timestamp: Date(),
                modelType: modelType,
                eventType: .info,
                message: "Model loaded: \(modelType.rawValue)",
                details: nil
            )
            
            self.addDiagnosticEvent(event)
        }
    }
    
    /// Record a model unloaded event
    /// - Parameter modelType: The type of model
    private func recordModelUnloaded(modelType: JanetModelType) {
        guard isDiagnosticsEnabled else { return }
        
        logger.info("Recording model unloaded event for model: \(modelType.rawValue)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Add diagnostic event
            let event = DiagnosticEvent(
                timestamp: Date(),
                modelType: modelType,
                eventType: .info,
                message: "Model unloaded: \(modelType.rawValue)",
                details: nil
            )
            
            self.addDiagnosticEvent(event)
        }
    }
    
    /// Add a diagnostic event
    /// - Parameter event: The event to add
    private func addDiagnosticEvent(_ event: DiagnosticEvent) {
        Task { @MainActor in
            diagnosticEvents.insert(event, at: 0)
            
            // Trim if needed
            if diagnosticEvents.count > maxEvents {
                diagnosticEvents = Array(diagnosticEvents.prefix(maxEvents))
            }
        }
        
        // Log the event
        switch event.eventType {
        case .info:
            logger.info("\(event.message)")
        case .warning:
            logger.warning("\(event.message)")
        case .failure:
            logger.error("\(event.message)")
        case .success:
            logger.info("\(event.message)")
        }
        
        // Log details if detailed logging is enabled
        if isDetailedLoggingEnabled, let details = event.details {
            logger.debug("Details: \(details)")
        }
    }
    
    /// Update system health based on metrics
    private func updateSystemHealth() {
        var newHealth = SystemHealth.normal
        
        // Check for critical issues
        let criticalFailures = failureCounts.values.filter { $0 >= 3 }.count
        if criticalFailures >= 2 {
            // Multiple models with 3+ consecutive failures
            newHealth = .critical
        } else if criticalFailures >= 1 {
            // One model with 3+ consecutive failures
            newHealth = .degraded
        }
        
        // Check for degraded performance
        let totalExecutions = modelMetrics.values.reduce(0) { $0 + $1.totalExecutions }
        let totalFailures = modelMetrics.values.reduce(0) { $0 + $1.failedExecutions }
        
        if totalExecutions > 10 {
            let overallFailureRate = Double(totalFailures) / Double(totalExecutions)
            
            if overallFailureRate > 0.3 && newHealth != .critical {
                // More than 30% overall failure rate
                newHealth = .degraded
            }
        }
        
        // Update system health if changed
        if newHealth != systemHealth {
            Task { @MainActor in
                systemHealth = newHealth
            }
            
            logger.info("System health updated to: \(newHealth.rawValue)")
        }
    }
    
    /// Attempt to recover from a failure
    /// - Parameters:
    ///   - modelType: The type of model
    ///   - error: The error that occurred
    private func attemptRecovery(modelType: JanetModelType, error: Error) {
        logger.info("Attempting recovery for model: \(modelType.rawValue)")
        
        // Get the recovery strategy
        let executionError = error as? ExecutionError
        let strategy = executionError.flatMap { recoveryStrategies[$0] } ?? RecoveryStrategy(
            action: .logAndNotify,
            description: "Log the error and notify the user"
        )
        
        // Execute the recovery action
        switch strategy.action {
        case .reloadModel:
            // Attempt to reload the model
            Task {
                do {
                    try await ModelManager.shared.loadModel(type: modelType)
                    
                    // Record success
                    let event = DiagnosticEvent(
                        timestamp: Date(),
                        modelType: modelType,
                        eventType: .info,
                        message: "Recovery action: Reloaded model \(modelType.rawValue)",
                        details: nil
                    )
                    
                    self.addDiagnosticEvent(event)
                } catch {
                    // Record failure
                    let event = DiagnosticEvent(
                        timestamp: Date(),
                        modelType: modelType,
                        eventType: .failure,
                        message: "Recovery action failed: Could not reload model \(modelType.rawValue)",
                        details: "Error: \(error.localizedDescription)"
                    )
                    
                    self.addDiagnosticEvent(event)
                }
            }
            
        case .retryWithDifferentParameters:
            // Log the recovery action
            let event = DiagnosticEvent(
                timestamp: Date(),
                modelType: modelType,
                eventType: .info,
                message: "Recovery action: Suggest retrying with different parameters",
                details: "Consider reducing max tokens or adjusting temperature"
            )
            
            self.addDiagnosticEvent(event)
            
        case .switchToFallbackModel:
            // Log the recovery action
            let event = DiagnosticEvent(
                timestamp: Date(),
                modelType: modelType,
                eventType: .info,
                message: "Recovery action: Suggest switching to fallback model",
                details: "Consider using a different model type"
            )
            
            self.addDiagnosticEvent(event)
            
        case .logAndNotify:
            // Log the recovery action
            let event = DiagnosticEvent(
                timestamp: Date(),
                modelType: modelType,
                eventType: .info,
                message: "Recovery action: Logged error",
                details: "Error: \(error.localizedDescription)"
            )
            
            self.addDiagnosticEvent(event)
        }
    }
}

// MARK: - Model Metrics

/// Performance metrics for a model
public struct ModelMetrics {
    /// Total number of executions
    public var totalExecutions: Int = 0
    
    /// Number of successful executions
    public var successfulExecutions: Int = 0
    
    /// Number of failed executions
    public var failedExecutions: Int = 0
    
    /// Total execution time in seconds
    public var totalExecutionTime: TimeInterval = 0
    
    /// Average execution time in seconds
    public var averageExecutionTime: TimeInterval = 0
    
    /// Total prompt length in characters
    public var totalPromptLength: Int = 0
    
    /// Total response length in characters
    public var totalResponseLength: Int = 0
    
    /// When the model was last executed
    public var lastExecutionTime: Date?
    
    /// Initialize a new model metrics struct
    public init() {}
}

// MARK: - Diagnostic Event

/// A diagnostic event
public struct DiagnosticEvent: Identifiable {
    /// Unique identifier for the event
    public let id = UUID()
    
    /// When the event occurred
    public let timestamp: Date
    
    /// The type of model
    public let modelType: JanetModelType
    
    /// The type of event
    public let eventType: DiagnosticEventType
    
    /// The event message
    public let message: String
    
    /// Additional details
    public let details: String?
}

// MARK: - Diagnostic Event Type

/// Types of diagnostic events
public enum DiagnosticEventType {
    /// Informational event
    case info
    
    /// Warning event
    case warning
    
    /// Failure event
    case failure
    
    /// Success event
    case success
}

// MARK: - System Health

/// System health status
public enum SystemHealth: String {
    /// Normal operation
    case normal = "Normal"
    
    /// Degraded performance
    case degraded = "Degraded"
    
    /// Critical issues
    case critical = "Critical"
}

// MARK: - Diagnostic Recommendation

/// A diagnostic recommendation
public struct DiagnosticRecommendation {
    /// The severity of the recommendation
    public let severity: RecommendationSeverity
    
    /// The type of model (if applicable)
    public let modelType: JanetModelType?
    
    /// The recommendation message
    public let message: String
    
    /// The recommended action
    public let recommendation: String
}

// MARK: - Recommendation Severity

/// Severity levels for recommendations
public enum RecommendationSeverity {
    /// Low severity
    case low
    
    /// Medium severity
    case medium
    
    /// High severity
    case high
}

// MARK: - Recovery Strategy

/// A strategy for recovering from a failure
struct RecoveryStrategy {
    /// The recovery action
    let action: RecoveryAction
    
    /// A description of the strategy
    let description: String
}

// MARK: - Recovery Action

/// Actions for recovering from a failure
enum RecoveryAction {
    /// Reload the model
    case reloadModel
    
    /// Retry with different parameters
    case retryWithDifferentParameters
    
    /// Switch to a fallback model
    case switchToFallbackModel
    
    /// Log the error and notify the user
    case logAndNotify
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when a model is loaded
    static let modelLoaded = Notification.Name("com.janet.ai.modelLoaded")
    
    /// Posted when a model is unloaded
    static let modelUnloaded = Notification.Name("com.janet.ai.modelUnloaded")
    
    /// Posted when a task execution is completed
    static let taskExecutionCompleted = Notification.Name("com.janet.ai.taskExecutionCompleted")
} 