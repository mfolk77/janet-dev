# Janet Model Orchestration System

The Model Orchestration system is a core component of Janet that manages the selection, loading, and execution of AI models. This document provides an overview of how the orchestration system works and how to use it effectively.

## Overview

The `ModelOrchestrator` class serves as the central coordinator for all model-related operations in Janet. It manages:

- Model registration and availability
- Task analysis and model selection
- Model execution in various modes
- Memory context for conversation history
- System command execution

## Key Components

### ModelRegistry

The `ModelRegistry` maintains a list of all registered models and their capabilities. Each model is registered as a `RegisteredModel` with specific capabilities that define what tasks it can perform and how well it performs them.

### TaskAnalyzer

The `TaskAnalyzer` determines the most appropriate model(s) for a given task based on:
- The type of task (general, chat, code, summarization, etc.)
- The content of the prompt
- Available models and their capabilities

### ExecutionEngine

The `ExecutionEngine` handles the actual execution of models, supporting several execution modes:
- Single model execution
- Chain execution (sequential processing through multiple models)
- Parallel execution (running multiple models simultaneously)
- Auto-refinement (iterative improvement of responses)

### MemoryContextManager

The `MemoryContextManager` maintains conversation history and context, enhancing responses by providing relevant context from previous interactions.

## Available Models

Janet supports multiple AI models, each with different capabilities:

1. **Ollama**
   - Supports general, chat, and summarization tasks
   - Medium reasoning ability
   - 4096 token context window
   - Local only

2. **Phi**
   - Supports general, chat, reasoning, and summarization tasks
   - High reasoning ability
   - 2048 token context window
   - Local only

3. **Llama**
   - Supports general, chat, code, and reasoning tasks
   - High reasoning ability
   - 4096 token context window
   - Local only

4. **Mistral**
   - Supports general, chat, and summarization tasks
   - Medium reasoning ability
   - 8192 token context window
   - Local only

## Execution Modes

Janet supports several execution modes:

### Auto Mode

In auto mode, Janet automatically selects the best execution strategy based on the task and available models.

### Single Mode

Uses a single model to generate a response.

### Chain Mode

Processes the input through a sequence of models, with each model refining the output of the previous one.

### Parallel Mode

Executes multiple models simultaneously and combines their results using one of several strategies:
- Best: Selects the result from the highest-priority model
- Concatenate: Combines all results
- Summarize: Generates a summary of all results
- Vote: Uses a voting mechanism to select the best result

## System Command Execution

Janet can execute system commands when requested, with built-in security measures to prevent dangerous operations.

## Usage Examples

### Basic Text Generation

```swift
let result = try await ModelOrchestrator.shared.generateText(
    prompt: "Explain quantum computing",
    taskType: .general
)
```

### Model Chain Execution

```swift
let result = try await ModelOrchestrator.shared.executeModelChain(
    prompt: "Write a poem about AI",
    modelChain: [.phi, .mistral]
)
```

### Parallel Execution

```swift
let result = try await ModelOrchestrator.shared.executeParallel(
    prompt: "Summarize this article",
    models: [.llama, .mistral],
    combinationStrategy: .summarize
)
```

### Auto-Refinement

```swift
let result = try await ModelOrchestrator.shared.autoRefine(
    prompt: "Write code to solve the traveling salesman problem",
    iterations: 3,
    modelType: .phi
)
```

## Error Handling

The orchestration system defines several error types in the `OrchestratorError` enum:
- `noSuitableModel`: No suitable model was found for the task
- `modelNotRegistered`: The requested model is not registered
- `modelLoadFailed`: The model failed to load
- `modelGenerationFailed`: The model failed to generate text
- `unsupportedExecutionMode`: The execution mode is not supported
- `unsupportedCombinationStrategy`: The combination strategy is not supported
- `noModelsAvailable`: No models are available for the task

## Extending the System

To add a new model to the orchestration system:

1. Add a new case to the `JanetModelType` enum
2. Create a `RegisteredModel` instance with appropriate capabilities
3. Register the model using `modelRegistry.registerModel()`
4. Implement the model's loading and execution logic in the appropriate manager class 