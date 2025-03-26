//
//  CodeModelTester.swift
//  Janet
//
//  Created by Michael folk on 3/5/2025.
//

import Foundation
import os

/// Tests coding models with structured test plans
public class CodeModelTester {
    // MARK: - Singleton
    
    /// Shared instance
    public static let shared = CodeModelTester()
    
    // MARK: - Private Properties
    
    /// Logger for the code model tester
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.janet.ai", category: "CodeModelTester")
    
    /// Queue for thread safety
    private let queue = DispatchQueue(label: "com.janet.ai.codeModelTester", qos: .userInitiated)
    
    /// Ollama service
    private let ollamaService = OllamaService.shared
    
    // MARK: - Initialization
    
    /// Initialize a new code model tester
    private init() {
        logger.info("Initializing CodeModelTester")
    }
    
    // MARK: - Public Methods
    
    /// Run a structured test plan for DeepSeek Coder
    /// - Returns: Test results
    public func runDeepSeekCoderTests() async -> [CodeTestResult] {
        logger.info("Running DeepSeek Coder tests")
        
        // Define test cases
        let testCases: [TestCase] = [
            TestCase(
                name: "Basic Function",
                prompt: "Write a function to calculate the factorial of a number in JavaScript",
                expectedOutput: "function factorial(n) {",
                language: "javascript",
                category: .basicFunctionality
            ),
            TestCase(
                name: "Algorithm Implementation",
                prompt: "Implement a binary search algorithm in Python",
                expectedOutput: "def binary_search(",
                language: "python",
                category: .algorithmImplementation
            ),
            TestCase(
                name: "Bug Fixing",
                prompt: "Fix this buggy code: function sum(a, b) { return a - b; }",
                expectedOutput: "function sum(a, b) { return a + b; }",
                language: "javascript",
                category: .debugging
            ),
            TestCase(
                name: "API Integration",
                prompt: "Write a function to fetch data from a REST API using fetch in JavaScript",
                expectedOutput: "fetch(",
                language: "javascript",
                category: .apiIntegration
            ),
            TestCase(
                name: "Data Structure",
                prompt: "Implement a linked list class in Python",
                expectedOutput: "class Node",
                language: "python",
                category: .dataStructures
            ),
            TestCase(
                name: "Complex Algorithm",
                prompt: "Implement a solution for the traveling salesman problem in Python",
                expectedOutput: "def traveling_salesman",
                language: "python",
                category: .complexAlgorithms
            ),
            TestCase(
                name: "Code Refactoring",
                prompt: "Refactor this code to use async/await: function getData() { return fetch('https://api.example.com/data').then(response => response.json()); }",
                expectedOutput: "async function getData",
                language: "javascript",
                category: .codeRefactoring
            ),
            TestCase(
                name: "Unit Test",
                prompt: "Write a unit test for a function that adds two numbers in JavaScript using Jest",
                expectedOutput: "test(",
                language: "javascript",
                category: .unitTesting
            ),
            TestCase(
                name: "Design Pattern",
                prompt: "Implement the observer design pattern in Python",
                expectedOutput: "class Observer",
                language: "python",
                category: .designPatterns
            ),
            TestCase(
                name: "Error Handling",
                prompt: "Write a function that demonstrates proper error handling in JavaScript",
                expectedOutput: "try {",
                language: "javascript",
                category: .errorHandling
            )
        ]
        
        // Run the tests
        var results: [CodeTestResult] = []
        
        for testCase in testCases {
            logger.info("Running test case: \(testCase.name)")
            
            // Run the test
            let result = await runTest(testCase: testCase)
            results.append(result)
            
            // Log the result
            if result.success {
                logger.info("Test passed: \(testCase.name)")
            } else {
                logger.warning("Test failed: \(testCase.name)")
            }
        }
        
        // Calculate success rate
        let successRate = Double(results.filter { $0.success }.count) / Double(results.count)
        logger.info("Test success rate: \(successRate * 100)%")
        
        return results
    }
    
    /// Run tests for code models
    /// - Returns: Test results
    public func runCodeModelTests() async -> [CodeTestResult] {
        // For now, this is just an alias to runDeepSeekCoderTests
        // In the future, this could be expanded to test multiple code models
        return await runDeepSeekCoderTests()
    }
    
    /// Run tests for the current code model
    /// - Returns: A formatted string with test results
    public func runTests() async -> String {
        logger.info("Running tests for current code model")
        
        let results = await runDeepSeekCoderTests()
        
        // Format results as a string
        var output = "# Code Model Test Results\n\n"
        
        let totalTests = results.count
        let passedTests = results.filter { $0.success }.count
        let failedTests = totalTests - passedTests
        
        output += "## Summary\n"
        output += "- Total Tests: \(totalTests)\n"
        output += "- Passed: \(passedTests) (\(Int(Double(passedTests) / Double(totalTests) * 100))%)\n"
        output += "- Failed: \(failedTests) (\(Int(Double(failedTests) / Double(totalTests) * 100))%)\n\n"
        
        output += "## Detailed Results\n\n"
        
        for result in results {
            output += "### \(result.testCase.name)\n"
            output += "- Status: \(result.success ? "✅ Passed" : "❌ Failed")\n"
            output += "- Duration: \(String(format: "%.2f", result.executionTime))s\n"
            
            if !result.success, let error = result.errorMessage {
                output += "- Error: \(error)\n"
            }
            
            output += "\n"
        }
        
        return output
    }
    
    /// Compare different code models
    /// - Returns: A formatted string with comparison results
    public func compareModels() async -> String {
        logger.info("Comparing code models")
        
        // Define models to compare
        let models = ["phi:latest", "codellama:latest", "deepseek-coder:latest", "wizardcoder:latest"]
        
        // Define test prompts
        let testPrompts = [
            TestPrompt(prompt: "Write a function to calculate the factorial of a number", language: "javascript"),
            TestPrompt(prompt: "Create a class representing a bank account with deposit and withdraw methods", language: "python"),
            TestPrompt(prompt: "Write a function to find the longest substring without repeating characters", language: "swift"),
            TestPrompt(prompt: "Create a React component for a todo list", language: "typescript"),
            TestPrompt(prompt: "Write a SQL query to find the top 5 customers by order amount", language: "sql")
        ]
        
        var results: [ModelComparisonSummary] = []
        
        for model in models {
            var totalTime: TimeInterval = 0
            var totalTokens: Int = 0
            var successfulTests = 0
            
            for testPrompt in testPrompts {
                do {
                    let startTime = Date()
                    
                    // Format the prompt
                    let formattedPrompt = formatPrompt(prompt: testPrompt.prompt, language: testPrompt.language)
                    
                    // Call the model
                    let url = URL(string: "\(ollamaService.apiURL)/generate")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    // Create the request body
                    let body: [String: Any] = [
                        "model": model,
                        "prompt": formattedPrompt,
                        "stream": false,
                        "options": [
                            "temperature": 0.1,
                            "top_p": 0.9,
                            "top_k": 40,
                            "num_predict": 1024
                        ]
                    ]
                    
                    // Serialize the body
                    guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
                        logger.error("Failed to serialize request body")
                        continue
                    }
                    
                    request.httpBody = httpBody
                    
                    // Send the request
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    // Calculate execution time
                    let executionTime = Date().timeIntervalSince(startTime)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        logger.error("Invalid response from Ollama API")
                        continue
                    }
                    
                    let success = httpResponse.statusCode == 200
                    
                    if success {
                        // Parse the response
                        if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let responseText = responseDict["response"] as? String {
                            
                            // Calculate metrics
                            totalTime += executionTime
                            totalTokens += responseText.count / 4 // Rough estimate of tokens
                            successfulTests += 1
                            
                            logger.info("Test for \(model) completed in \(executionTime) seconds")
                        }
                    } else {
                        logger.error("Failed to generate code: HTTP \(httpResponse.statusCode)")
                    }
                    
                } catch {
                    logger.error("Error testing \(model): \(error.localizedDescription)")
                }
            }
            
            // Calculate model metrics
            let averageResponseTime = successfulTests > 0 ? totalTime / Double(successfulTests) : 0
            let accuracy = Double(successfulTests) / Double(testPrompts.count)
            
            results.append(ModelComparisonSummary(
                id: UUID(),
                modelName: model,
                accuracy: accuracy,
                averageResponseTime: averageResponseTime
            ))
        }
        
        // Format results as a string
        var output = "# Code Model Comparison Results\n\n"
        
        output += "## Summary\n\n"
        output += "| Model | Accuracy | Avg. Response Time |\n"
        output += "|-------|----------|--------------------|\n"
        
        for result in results {
            output += "| \(result.modelName) | \(Int(result.accuracy * 100))% | \(String(format: "%.2f", result.averageResponseTime))s |\n"
        }
        
        output += "\n## Details\n\n"
        output += "Tests were run on the following prompts:\n"
        
        for (index, prompt) in testPrompts.enumerated() {
            output += "\(index + 1). \(prompt.prompt) (Language: \(prompt.language))\n"
        }
        
        return output
    }
    
    /// Compare different code models
    /// - Returns: Array of model comparison results
    public func compareCodeModels() async -> [ModelComparisonResult] {
        logger.info("Comparing code models for different tasks")
        
        // Define models to compare
        let models = ["phi:latest", "codellama:latest", "deepseek-coder:latest", "mistral:latest"]
        
        // Define test cases
        let testCases: [TestCase] = [
            TestCase(
                name: "Basic Function",
                prompt: "Write a function to calculate the factorial of a number in JavaScript",
                expectedOutput: "function factorial(n) {",
                language: "javascript",
                category: .basicFunctionality
            ),
            TestCase(
                name: "Data Structure",
                prompt: "Implement a linked list class in Python",
                expectedOutput: "class Node",
                language: "python",
                category: .dataStructures
            ),
            TestCase(
                name: "Algorithm",
                prompt: "Implement a binary search algorithm in Swift",
                expectedOutput: "func binarySearch",
                language: "swift",
                category: .algorithmImplementation
            )
        ]
        
        var results: [ModelComparisonResult] = []
        
        for testCase in testCases {
            var modelResults: [String: CodeTestResult] = [:]
            
            for model in models {
                // Run the test with this model
                let result = await runTestWithModel(testCase: testCase, model: model)
                modelResults[model] = result
            }
            
            // Create a comparison result
            let comparisonResult = ModelComparisonResult(
                testCase: testCase,
                modelResults: modelResults
            )
            
            results.append(comparisonResult)
        }
        
        return results
    }
    
    /// Run a test with auto-retry
    /// - Parameter testCase: The test case to run
    /// - Returns: Test result
    public func runTestWithAutoRetry(testCase: TestCase) async -> CodeTestResult {
        logger.info("Running test with auto-retry: \(testCase.name)")
        
        // Run the test
        var result = await runTest(testCase: testCase)
        
        // If the test failed, retry up to 3 times
        var retryCount = 0
        while !result.success && retryCount < 3 {
            logger.warning("Test failed, retrying: \(testCase.name)")
            
            // Modify the prompt to encourage better results
            let modifiedPrompt = "Please carefully implement the following. Make sure your solution is correct and follows best practices: \(testCase.prompt)"
            
            // Create a new test case with the modified prompt
            let modifiedTestCase = TestCase(
                name: testCase.name,
                prompt: modifiedPrompt,
                expectedOutput: testCase.expectedOutput,
                language: testCase.language,
                category: testCase.category
            )
            
            // Run the test again
            result = await runTest(testCase: modifiedTestCase)
            retryCount += 1
        }
        
        // Log the final result
        if result.success {
            logger.info("Test passed after \(retryCount) retries: \(testCase.name)")
        } else {
            logger.warning("Test failed after \(retryCount) retries: \(testCase.name)")
        }
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Run a test case
    /// - Parameter testCase: The test case to run
    /// - Returns: Test result
    private func runTest(testCase: TestCase) async -> CodeTestResult {
        return await runTestWithModel(testCase: testCase, model: "deepseek-coder:6.7b")
    }
    
    /// Run a test case with a specific model
    /// - Parameters:
    ///   - testCase: The test case to run
    ///   - model: The model to use
    /// - Returns: Test result
    private func runTestWithModel(testCase: TestCase, model: String) async -> CodeTestResult {
        logger.info("Running test case \(testCase.name) with model \(model)")
        
        // Create the request
        let url = URL(string: "\(ollamaService.apiURL)/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let body: [String: Any] = [
            "model": model,
            "prompt": testCase.prompt,
            "stream": false
        ]
        
        // Serialize the body
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            logger.error("Failed to serialize request body")
            return CodeTestResult(
                testCase: testCase,
                success: false,
                output: "",
                executionTime: 0,
                errorMessage: "Failed to serialize request body"
            )
        }
        
        request.httpBody = httpBody
        
        // Start timing
        let startTime = Date()
        
        // Send the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Calculate execution time
            let executionTime = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response from Ollama API")
                return CodeTestResult(
                    testCase: testCase,
                    success: false,
                    output: "",
                    executionTime: executionTime,
                    errorMessage: "Invalid response from Ollama API"
                )
            }
            
            let success = httpResponse.statusCode == 200
            
            if success {
                // Parse the response
                if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = responseDict["response"] as? String {
                    
                    // Check if the output contains the expected output
                    let passed = output.contains(testCase.expectedOutput)
                    
                    return CodeTestResult(
                        testCase: testCase,
                        success: passed,
                        output: output,
                        executionTime: executionTime,
                        errorMessage: nil
                    )
                } else {
                    logger.error("Failed to parse response from Ollama API")
                    return CodeTestResult(
                        testCase: testCase,
                        success: false,
                        output: "",
                        executionTime: executionTime,
                        errorMessage: "Failed to parse response from Ollama API"
                    )
                }
            } else {
                logger.error("Failed to generate code: HTTP \(httpResponse.statusCode)")
                return CodeTestResult(
                    testCase: testCase,
                    success: false,
                    output: "",
                    executionTime: executionTime,
                    errorMessage: "Failed to generate code: HTTP \(httpResponse.statusCode)"
                )
            }
        } catch {
            logger.error("Failed to generate code: \(error.localizedDescription)")
            return CodeTestResult(
                testCase: testCase,
                success: false,
                output: "",
                executionTime: Date().timeIntervalSince(startTime),
                errorMessage: "Failed to generate code: \(error.localizedDescription)"
            )
        }
    }
    
    /// Format a prompt for code generation
    /// - Parameters:
    ///   - prompt: The user's prompt
    ///   - language: The programming language
    /// - Returns: A formatted prompt
    private func formatPrompt(prompt: String, language: String) -> String {
        // Determine the appropriate comment style for the language
        let (commentStart, commentEnd) = commentStyle(for: language)
        
        // Format the prompt with language-specific instructions
        return """
        \(commentStart)
        You are an expert \(language) developer. 
        Generate clean, efficient, and well-documented code based on the following request.
        Only output code without explanations unless specifically asked.
        \(commentEnd)
        
        \(commentStart) REQUEST: \(prompt) \(commentEnd)
        
        """
    }
    
    /// Get the comment style for a given language
    /// - Parameter language: The programming language
    /// - Returns: Tuple containing comment start and end markers
    private func commentStyle(for language: String) -> (String, String) {
        switch language.lowercased() {
        case "python", "ruby", "shell", "bash", "r":
            return ("# ", "")
        case "javascript", "typescript", "java", "c", "cpp", "c++", "csharp", "c#", "swift", "kotlin", "go", "rust", "php", "scala":
            return ("// ", "")
        case "html":
            return ("<!-- ", " -->")
        case "css":
            return ("/* ", " */")
        case "sql":
            return ("-- ", "")
        case "haskell", "lua":
            return ("-- ", "")
        case "lisp", "clojure":
            return ("; ", "")
        case "matlab", "octave":
            return ("% ", "")
        case "perl":
            return ("# ", "")
        default:
            return ("// ", "")
        }
    }
}

// MARK: - Test Case

/// A test case for a coding model
public struct TestCase {
    /// Name of the test case
    public let name: String
    
    /// Prompt for the test case
    public let prompt: String
    
    /// Expected output (substring)
    public let expectedOutput: String
    
    /// Programming language
    public let language: String
    
    /// Category of the test case
    public let category: TestCategory
    
    /// Initialize a new test case
    /// - Parameters:
    ///   - name: Name of the test case
    ///   - prompt: Prompt for the test case
    ///   - expectedOutput: Expected output (substring)
    ///   - language: Programming language
    ///   - category: Category of the test case
    public init(
        name: String,
        prompt: String,
        expectedOutput: String,
        language: String,
        category: TestCategory
    ) {
        self.name = name
        self.prompt = prompt
        self.expectedOutput = expectedOutput
        self.language = language
        self.category = category
    }
}

// MARK: - Test Result

/// Result of a test case
public struct CodeTestResult {
    /// The test case
    public let testCase: TestCase
    
    /// Whether the test passed
    public let success: Bool
    
    /// Computed property for compatibility
    public var passed: Bool { success }
    
    /// Output from the model
    public let output: String
    
    /// Execution time in seconds
    public let executionTime: TimeInterval
    
    /// Error message (if any)
    public let errorMessage: String?
    
    /// Initialize a new test result
    /// - Parameters:
    ///   - testCase: The test case
    ///   - success: Whether the test passed
    ///   - output: Output from the model
    ///   - executionTime: Execution time in seconds
    ///   - errorMessage: Error message (if any)
    public init(
        testCase: TestCase,
        success: Bool,
        output: String,
        executionTime: TimeInterval,
        errorMessage: String? = nil
    ) {
        self.testCase = testCase
        self.success = success
        self.output = output
        self.executionTime = executionTime
        self.errorMessage = errorMessage
    }
}

// MARK: - Model Comparison Result

/// Result of comparing multiple models on a test case
public struct ModelComparisonResult {
    /// The test case
    public let testCase: TestCase
    
    /// Results for each model
    public let modelResults: [String: CodeTestResult]
    
    /// Initialize a new model comparison result
    /// - Parameters:
    ///   - testCase: The test case
    ///   - modelResults: Results for each model
    public init(
        testCase: TestCase,
        modelResults: [String: CodeTestResult]
    ) {
        self.testCase = testCase
        self.modelResults = modelResults
    }
    
    /// Get the best performing model
    public var bestModel: String? {
        // Filter to passed tests
        let passedModels = modelResults.filter { $0.value.success }
        
        // If no models passed, return nil
        if passedModels.isEmpty {
            return nil
        }
        
        // Return the model with the fastest execution time
        return passedModels.min { $0.value.executionTime < $1.value.executionTime }?.key
    }
}

// MARK: - Test Category

/// Categories of coding tests
public enum TestCategory {
    /// Basic functionality
    case basicFunctionality
    
    /// Algorithm implementation
    case algorithmImplementation
    
    /// Debugging
    case debugging
    
    /// API integration
    case apiIntegration
    
    /// Data structures
    case dataStructures
    
    /// Complex algorithms
    case complexAlgorithms
    
    /// Code refactoring
    case codeRefactoring
    
    /// Unit testing
    case unitTesting
    
    /// Design patterns
    case designPatterns
    
    /// Error handling
    case errorHandling
}

// MARK: - Supporting Types

/// Model comparison summary for reporting
struct ModelComparisonSummary: Identifiable {
    /// Unique identifier
    let id: UUID
    
    /// Name of the model
    let modelName: String
    
    /// Accuracy of the model (0.0 to 1.0)
    let accuracy: Double
    
    /// Average response time in seconds
    let averageResponseTime: TimeInterval
    
    /// Initialize a new model comparison summary
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - modelName: Name of the model
    ///   - accuracy: Accuracy of the model (0.0 to 1.0)
    ///   - averageResponseTime: Average response time in seconds
    init(id: UUID, modelName: String, accuracy: Double, averageResponseTime: TimeInterval) {
        self.id = id
        self.modelName = modelName
        self.accuracy = accuracy
        self.averageResponseTime = averageResponseTime
    }
}

/// Test prompt for model comparison
struct TestPrompt {
    let prompt: String
    let language: String
}

public struct TestSuiteResult {
    public let testCase: TestCase
    public let modelResults: [String: CodeTestResult]
    
    public init(
        testCase: TestCase,
        modelResults: [String: CodeTestResult]
    ) {
        self.testCase = testCase
        self.modelResults = modelResults
    }
} 