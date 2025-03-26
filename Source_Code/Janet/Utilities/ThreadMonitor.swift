import Foundation
import os.log

/// A utility class for monitoring thread safety issues and detecting potential recursive locks
class ThreadMonitor {
    // Singleton instance
    static let shared = ThreadMonitor()
    
    // Logger
    private let logger = Logger(subsystem: "com.janet.threadmonitor", category: "monitoring")
    
    // Thread tracking
    private let monitorQueue = DispatchQueue(label: "com.janet.threadmonitor.queue", qos: .utility)
    private var threadEntryCount: [String: [UInt32: Int]] = [:]
    private var threadStackTraces: [String: [UInt32: String]] = [:]
    
    // Configuration
    private var isMonitoringEnabled = false
    private var alertThreshold = 2
    
    private init() {}
    
    /// Start monitoring for thread safety issues
    func startMonitoring(alertThreshold: Int = 2) {
        monitorQueue.async {
            self.isMonitoringEnabled = true
            self.alertThreshold = alertThreshold
            self.threadEntryCount.removeAll()
            self.threadStackTraces.removeAll()
            self.logger.info("Thread monitoring started with alert threshold \(alertThreshold)")
        }
    }
    
    /// Stop monitoring for thread safety issues
    func stopMonitoring() {
        monitorQueue.async {
            self.isMonitoringEnabled = false
            self.threadEntryCount.removeAll()
            self.threadStackTraces.removeAll()
            self.logger.info("Thread monitoring stopped")
        }
    }
    
    /// Track entry into a critical section
    /// - Parameters:
    ///   - name: The name of the critical section
    ///   - file: The file where the critical section is located
    ///   - line: The line number where the critical section is located
    ///   - function: The function where the critical section is located
    /// - Returns: True if it's safe to proceed, false if a potential recursive lock was detected
    func enterCriticalSection(name: String, file: String = #file, line: Int = #line, function: String = #function) -> Bool {
        guard isMonitoringEnabled else { return true }
        
        let threadID = pthread_mach_thread_np(pthread_self())
        let sectionKey = "\(name)-\(file)-\(function)"
        
        var isSafe = true
        
        monitorQueue.sync {
            // Get current entry count for this thread and section
            var count = threadEntryCount[sectionKey]?[threadID] ?? 0
            count += 1
            
            // Update entry count
            if threadEntryCount[sectionKey] == nil {
                threadEntryCount[sectionKey] = [:]
            }
            threadEntryCount[sectionKey]?[threadID] = count
            
            // Check if we've exceeded the threshold
            if count >= alertThreshold {
                isSafe = false
                
                // Capture stack trace for debugging
                let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
                
                if threadStackTraces[sectionKey] == nil {
                    threadStackTraces[sectionKey] = [:]
                }
                threadStackTraces[sectionKey]?[threadID] = stackTrace
                
                logger.error("⚠️ Potential recursive lock detected in \(name) at \(file):\(line). Entry count: \(count)")
                logger.error("Stack trace: \(stackTrace)")
            }
        }
        
        return isSafe
    }
    
    /// Track exit from a critical section
    /// - Parameters:
    ///   - name: The name of the critical section
    ///   - file: The file where the critical section is located
    ///   - function: The function where the critical section is located
    func exitCriticalSection(name: String, file: String = #file, function: String = #function) {
        guard isMonitoringEnabled else { return }
        
        let threadID = pthread_mach_thread_np(pthread_self())
        let sectionKey = "\(name)-\(file)-\(function)"
        
        monitorQueue.sync {
            // Decrement entry count
            var count = threadEntryCount[sectionKey]?[threadID] ?? 0
            if count > 0 {
                count -= 1
                threadEntryCount[sectionKey]?[threadID] = count
            }
        }
    }
    
    /// Get a report of all critical sections with potential recursive locks
    /// - Returns: A string containing the report
    func getRecursiveLockReport() -> String {
        var report = "Thread Monitor Report\n"
        report += "=====================\n\n"
        
        monitorQueue.sync {
            for (section, threads) in threadEntryCount {
                for (threadID, count) in threads {
                    if count >= alertThreshold {
                        report += "Section: \(section)\n"
                        report += "Thread ID: \(threadID)\n"
                        report += "Entry Count: \(count)\n"
                        if let stackTrace = threadStackTraces[section]?[threadID] {
                            report += "Stack Trace:\n\(stackTrace)\n"
                        }
                        report += "\n"
                    }
                }
            }
        }
        
        if report == "Thread Monitor Report\n=====================\n\n" {
            report += "No recursive locks detected."
        }
        
        return report
    }
    
    /// Check if the current thread is the main thread and log a warning if it's not
    /// - Parameters:
    ///   - message: A message describing the operation that should be on the main thread
    ///   - file: The file where the check is performed
    ///   - line: The line number where the check is performed
    ///   - function: The function where the check is performed
    /// - Returns: True if the current thread is the main thread, false otherwise
    func ensureMainThread(message: String, file: String = #file, line: Int = #line, function: String = #function) -> Bool {
        let isMainThread = Thread.isMainThread
        
        if !isMainThread && isMonitoringEnabled {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            logger.warning("⚠️ \(message) not on main thread in \(fileName):\(line) (\(function))")
        }
        
        return isMainThread
    }
    
    /// Detect if a dispatch queue is being used recursively
    /// - Parameters:
    ///   - queue: The dispatch queue to check
    ///   - label: A label for the queue (for logging)
    ///   - file: The file where the check is performed
    ///   - line: The line number where the check is performed
    ///   - function: The function where the check is performed
    /// - Returns: True if the current execution is on the specified queue, false otherwise
    func isRecursiveQueueCall(_ queue: DispatchQueue, label: String, file: String = #file, line: Int = #line, function: String = #function) -> Bool {
        // This is a simplified check and may not be 100% accurate for all cases
        // For a more robust solution, a custom dispatch queue key could be used
        
        var isCurrentQueue = false
        let semaphore = DispatchSemaphore(value: 0)
        
        // Create a unique key for this check
        let key = UUID().uuidString
        
        // Set a thread-specific value on the current thread
        Thread.current.threadDictionary[key] = true
        
        // Dispatch async to the queue and check if the value exists
        queue.async {
            isCurrentQueue = Thread.current.threadDictionary[key] != nil
            Thread.current.threadDictionary.removeObject(forKey: key)
            semaphore.signal()
        }
        
        // Wait for the check to complete
        semaphore.wait()
        
        // Remove the value from the current thread
        Thread.current.threadDictionary.removeObject(forKey: key)
        
        if isCurrentQueue && isMonitoringEnabled {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            logger.warning("⚠️ Recursive call to queue '\(label)' detected in \(fileName):\(line) (\(function))")
        }
        
        return isCurrentQueue
    }
}

/// A utility struct for automatically tracking entry and exit from critical sections
struct CriticalSection {
    private let name: String
    private let file: String
    private let line: Int
    private let function: String
    private let isSafe: Bool
    
    init(name: String, file: String = #file, line: Int = #line, function: String = #function) {
        self.name = name
        self.file = file
        self.line = line
        self.function = function
        self.isSafe = ThreadMonitor.shared.enterCriticalSection(name: name, file: file, line: line, function: function)
    }
    
    var isLockSafe: Bool {
        return isSafe
    }
    
    func exit() {
        ThreadMonitor.shared.exitCriticalSection(name: name, file: file, function: function)
    }
}

/// A utility for automatically tracking entry and exit from critical sections using Swift's defer
extension ThreadMonitor {
    /// Execute a closure within a monitored critical section
    /// - Parameters:
    ///   - name: The name of the critical section
    ///   - file: The file where the critical section is located
    ///   - line: The line number where the critical section is located
    ///   - function: The function where the critical section is located
    ///   - action: The closure to execute
    /// - Returns: The result of the closure
    func withCriticalSection<T>(name: String, file: String = #file, line: Int = #line, function: String = #function, action: () throws -> T) rethrows -> T {
        let _ = enterCriticalSection(name: name, file: file, line: line, function: function)
        defer { exitCriticalSection(name: name, file: file, function: function) }
        return try action()
    }
}

/// Extension to DispatchQueue for safer dispatching
extension DispatchQueue {
    /// Safely dispatch to the main queue, avoiding recursive calls
    /// - Parameter work: The work to perform on the main queue
    static func safeMainAsync(_ work: @escaping () -> Void) {
        // If we're already on the main thread, execute directly
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
    
    /// Safely dispatch to a queue, checking for recursive calls
    /// - Parameters:
    ///   - label: A label for the queue (for monitoring)
    ///   - work: The work to perform on the queue
    func safeAsync(label: String, _ work: @escaping () -> Void) {
        // Check if this would be a recursive call
        if ThreadMonitor.shared.isRecursiveQueueCall(self, label: label) {
            // If it would be recursive, execute directly to avoid deadlock
            work()
        } else {
            // Otherwise, dispatch normally
            self.async(execute: work)
        }
    }
} 