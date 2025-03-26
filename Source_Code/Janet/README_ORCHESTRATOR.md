# Janet Model Orchestrator

## Overview

The Janet Model Orchestrator is a sophisticated system designed to manage multiple AI models and intelligently route requests based on task requirements, model capabilities, and performance metrics. It provides a flexible architecture for handling complex AI workflows, enabling hybrid execution across local and cloud models, advanced reasoning capabilities, and self-diagnostic features.

## Key Components

### Core Components

- **ModelOrchestrator**: The central component that coordinates model selection, task analysis, and execution.
- **ModelRegistry**: Manages the registration and tracking of available models and their capabilities.
- **TaskAnalyzer**: Analyzes incoming requests to determine the most appropriate model(s) and execution strategy.
- **ExecutionEngine**: Handles the actual execution of models, supporting various execution modes and strategies.
- **MemoryContextManager**: Manages context for models, including conversation history and vector-based memory retrieval.

### Advanced Components

- **CloudModelExecutor**: Enables execution of cloud-based AI models (OpenAI, Anthropic, Google AI) alongside local models.
- **FinancialModelRegistry**: Specialized registry for financial models like FinGPT and BloombergGPT.
- **SelfDiagnostics**: Monitors model performance, detects issues, and provides recovery recommendations.
- **EnhancedMemoryManager**: Integrates vector-based memory retrieval and external knowledge sources.

## Integration with Janet

The orchestrator is integrated with the Janet application through the following files:

- `JanetApp.swift`: Initializes the orchestrator as a shared instance and injects it into the environment.
- `ChatView.swift`: Provides a toggle to enable/disable the orchestrator for message processing.
- `OrchestratorView.swift`: Offers a tabbed interface for managing orchestrator settings.

## Usage

### Basic Usage

1. **Toggle Orchestrator**: In the chat view, use the "Use Orchestrator" toggle to enable or disable orchestrator-based message processing.
2. **Send Messages**: When the orchestrator is enabled, messages will be processed using the most appropriate model(s) based on the task requirements.

### Advanced Usage

1. **Orchestrator Settings**: Access the orchestrator settings through the navigation menu to configure models, tasks, and execution strategies.
2. **Model Registration**: Register new models and specify their capabilities.
3. **Execution Strategies**: Choose between different execution strategies (single, chain, parallel, auto).
4. **Memory Management**: Configure memory settings, including vector-based retrieval and external knowledge sources.
5. **Financial Models**: Access specialized financial models for business intelligence and financial analysis.
6. **Self-Diagnostics**: Monitor model performance and receive recommendations for improving reliability.

## Technical Details

### Model Registration

Models can be registered with the following properties:

- **Model Type**: The type of model (e.g., GPT-4, Claude, Llama).
- **Capabilities**: The capabilities of the model, including supported tasks, reasoning ability, and context window size.
- **Priority**: The priority of the model (lower values indicate higher priority).
- **Local/Cloud**: Whether the model runs locally or in the cloud.

### Task Analysis

The task analyzer uses the following methods to determine the most appropriate model(s):

- **Keyword Analysis**: Identifies keywords in the prompt that indicate specific task requirements.
- **Pattern Matching**: Matches prompt patterns to predefined task types.
- **Context Analysis**: Analyzes conversation context to maintain consistency.

### Execution Strategies

The execution engine supports the following strategies:

- **Single Model**: Uses a single model to process the request.
- **Chain of Models**: Processes the request through a sequence of models, with each model building on the output of the previous one.
- **Parallel Execution**: Processes the request through multiple models in parallel and combines their outputs.
- **Auto Selection**: Automatically selects the most appropriate execution strategy based on the task requirements.

### Advanced Execution Features

- **Multi-Step Reasoning**: Breaks complex reasoning tasks into multiple steps for more thorough analysis.
- **Chain-of-Thought**: Implements chain-of-thought reasoning for step-by-step problem solving.
- **Tree-of-Thought**: Explores multiple reasoning paths and selects the most promising one.
- **Hybrid Execution**: Seamlessly combines local and cloud-based models in a single workflow.
- **Advanced Combination Strategies**: Uses weighted averaging, ensemble methods, debate, and confidence thresholds to combine results from multiple models.

### Memory and RAG

- **Vector-Based Memory**: Stores and retrieves memories using vector embeddings for semantic search.
- **External Knowledge Sources**: Integrates with external knowledge sources like Notion.
- **Context-Aware Prompts**: Generates prompts that include relevant context from memory and external sources.

### Financial Models

- **Specialized Models**: Includes specialized models for financial analysis, stock prediction, and risk assessment.
- **Financial Context**: Enhances prompts with financial data, statements, news, and economic indicators.
- **Task-Specific Execution**: Optimizes execution for financial tasks like market analysis and financial reporting.

### Self-Diagnostics

- **Performance Monitoring**: Tracks model performance metrics like success rate and execution time.
- **Health Assessment**: Evaluates system health based on failure patterns and overall performance.
- **Auto-Recovery**: Automatically attempts to recover from common failures.
- **Diagnostic Recommendations**: Provides recommendations for improving reliability and performance.

## Future Enhancements

- **Advanced Task Analysis**: Implement more sophisticated task analysis using NLP techniques.
- **Learning from Feedback**: Enable the orchestrator to learn from user feedback to improve model selection.
- **Custom Model Fine-Tuning**: Support for fine-tuning models based on usage patterns and feedback.
- **Distributed Execution**: Support for distributed execution across multiple devices or servers.
- **Adaptive Execution Strategies**: Dynamically adjust execution strategies based on real-time performance metrics.
- **Enhanced Security**: Implement more robust security measures for sensitive tasks and data.

## Integration with Existing Janet Features

The orchestrator seamlessly integrates with existing Janet features:

- **Vector Memory**: Leverages Janet's vector memory system for semantic search and retrieval.
- **Notion Integration**: Works with Janet's Notion integration for accessing external knowledge.
- **Conversation History**: Maintains and utilizes conversation history for context-aware responses.
- **Model Management**: Integrates with Janet's model management system for loading and unloading models.

## Self-Diagnostics and Debugging

The orchestrator includes comprehensive self-diagnostic capabilities:

- **Diagnostic Events**: Tracks events like model loading, execution success/failure, and warnings.
- **Performance Metrics**: Monitors metrics like execution time, success rate, and memory usage.
- **Health Status**: Provides overall system health status (normal, degraded, critical).
- **Recovery Actions**: Attempts to recover from common failures automatically.
- **Debugging Recommendations**: Offers specific recommendations for resolving issues.

To access diagnostics:

1. Navigate to the Orchestrator settings.
2. Select the "Diagnostics" tab.
3. View current health status, recent events, and recommendations.
4. Enable/disable auto-recovery and detailed logging as needed.

## Hybrid Execution Guide

The orchestrator supports hybrid execution across local and cloud models:

### Cloud Providers

- **OpenAI**: Access to GPT models through the OpenAI API.
- **Anthropic**: Access to Claude models through the Anthropic API.
- **Google AI**: Access to Gemini models through the Google AI API.
- **Custom**: Support for custom API endpoints.

### Configuration

1. Navigate to the Orchestrator settings.
2. Select the "Cloud Models" tab.
3. Enter API keys for desired providers.
4. Configure execution preferences (cost limits, fallback options).

### Execution Modes

- **Local First**: Attempts to use local models first, falling back to cloud models if needed.
- **Cloud First**: Prefers cloud models for better quality, using local models as fallbacks.
- **Cost Optimized**: Selects models based on cost considerations.
- **Quality Optimized**: Selects models based on quality considerations, regardless of cost.

## Financial Models Guide

The orchestrator includes specialized support for financial tasks:

### Available Models

- **FinGPT**: Specialized model for financial analysis and forecasting.
- **BloombergGPT**: Financial model trained on Bloomberg's extensive market data.
- **Local Finance Model**: Lightweight model for basic financial tasks.

### Financial Tasks

- **Market Analysis**: Analyze market trends and conditions.
- **Stock Prediction**: Predict stock price movements.
- **Financial Reporting**: Generate and analyze financial reports.
- **Sentiment Analysis**: Analyze sentiment in financial news and reports.
- **Risk Assessment**: Assess financial risks and opportunities.

### Usage

1. Navigate to the Orchestrator settings.
2. Select the "Financial Models" tab.
3. Configure desired models and data sources.
4. In chat, prefix financial queries with "Finance:" for automatic routing to financial models.

## Advanced Memory and RAG Guide

The orchestrator includes advanced memory and retrieval-augmented generation capabilities:

### Memory Types

- **Conversation Memory**: Short-term memory of recent conversations.
- **Vector Memory**: Long-term memory using vector embeddings for semantic search.
- **External Knowledge**: Integration with external sources like Notion.

### Configuration

1. Navigate to the Orchestrator settings.
2. Select the "Memory" tab.
3. Enable/disable vector memory and external sources.
4. Configure retrieval parameters (relevance threshold, result count).

### Usage

- Memory is automatically used to enhance prompts with relevant context.
- Use the "Remember this:" prefix to explicitly store important information.
- Use the "Recall:" prefix to explicitly retrieve information from memory. 